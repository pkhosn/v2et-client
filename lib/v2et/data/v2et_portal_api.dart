import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hiddify/v2et/model/v2board_session.dart';
import 'package:hiddify/v2et/model/v2et_portal_models.dart';

class V2etPortalApi {
  V2etPortalApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<List<V2etNotice>> fetchNotices(V2boardSession session) async {
    final json = await _authGet(session, '/api/v1/user/notice/fetch');
    final rows = _readList(_readMapNullable(json['data'])?['data'] ?? json['data']);
    return rows
        .map(
          (row) => V2etNotice(title: _readString(row['title']) ?? 'Notice', content: _readString(row['content']) ?? ''),
        )
        .toList();
  }

  Future<List<V2etStoreOffer>> fetchPlans(V2boardSession session) async {
    final json = await _authGet(session, '/api/v1/user/plan/fetch');
    final rows = _readList(_readMapNullable(json['data'])?['data'] ?? json['data']);
    return rows
        .map(
          (row) => V2etStoreOffer(
            id: _readInt(row['id']),
            name: _readString(row['name']) ?? 'Plan',
            prices: _extractPrices(row),
            traffic: _extractTraffic(row),
            speed: _speedLabel(row['speed_limit']),
            deviceLimit: _extractDeviceLimit(row),
            features: _extractFeatures(row),
            raw: row,
          ),
        )
        .toList();
  }

  Future<Map<String, int>> fetchCounters(V2boardSession session) async {
    final counters = <String, int>{'orders': 0, 'tickets': 0};
    try {
      final orderJson = await _authGet(session, '/api/v1/user/order/fetch');
      final orders = _readList(_readMapNullable(orderJson['data'])?['data'] ?? orderJson['data']);
      counters['orders'] = orders.length;
    } catch (_) {}
    try {
      final ticketJson = await _authGet(session, '/api/v1/user/ticket/fetch');
      final tickets = _readList(_readMapNullable(ticketJson['data'])?['data'] ?? ticketJson['data']);
      counters['tickets'] = tickets.length;
    } catch (_) {}
    return counters;
  }

  Future<List<V2etOrderRecord>> fetchOrders(V2boardSession session) async {
    final json = await _authGet(session, '/api/v1/user/order/fetch');
    final rows = _readList(_readMapNullable(json['data'])?['data'] ?? json['data']);
    return rows
        .map(
          (row) => V2etOrderRecord(
            tradeNo: _readString(row['trade_no']) ?? '--',
            status: _readInt(row['status']) ?? 0,
            totalAmount: _readMoney(row['total_amount']) ?? 0,
            createdAt: _readDate(row['created_at']),
            planName: _readString(_readMapNullable(row['plan'])?['name']),
            period: _readString(row['period']),
          ),
        )
        .toList();
  }

  Future<List<V2etTrafficRecord>> fetchTrafficLogs(V2boardSession session) async {
    final json = await _authGet(session, '/api/v1/user/stat/getTrafficLog');
    final rows = _readList(_readMapNullable(json['data'])?['data'] ?? json['data']);
    return rows
        .map(
          (row) => V2etTrafficRecord(
            upload: _readInt(row['u']) ?? 0,
            download: _readInt(row['d']) ?? 0,
            recordAt: _readUnix(row['record_at']),
            serverRate: _readNum(row['server_rate'])?.toDouble() ?? 1.0,
          ),
        )
        .toList();
  }

  Future<V2etInviteInfo> fetchInviteInfo(V2boardSession session) async {
    final json = await _authGet(session, '/api/v1/user/invite/fetch');
    final data = _readMapNullable(json['data'])?['data'] ?? json['data'];
    final map = _readMap(data);
    final codes = _readList(map['codes']).map((e) => _readString(e['code'])).whereType<String>().toList();
    final statRaw = map['stat'];
    final stat = <int>[];
    if (statRaw is List) {
      for (final item in statRaw) {
        final v = _readInt(item) ?? 0;
        stat.add(v);
      }
    }
    while (stat.length < 5) {
      stat.add(0);
    }
    return V2etInviteInfo(codes: codes, stat: stat);
  }

  Future<void> generateInviteCode(V2boardSession session) async {
    await _authGet(session, '/api/v1/user/invite/save');
  }

  Future<bool> redeemCouponPlan({
    required V2boardSession session,
    required int planId,
    required String periodField,
    required String couponCode,
  }) async {
    await _authPost(session, '/api/v1/user/coupon/check', data: {'code': couponCode, 'plan_id': planId});

    final save = await _authPost(
      session,
      '/api/v1/user/order/save',
      data: {'plan_id': planId, 'period': periodField, 'coupon_code': couponCode},
    );
    final tradeNo = _readString(_readMapNullable(save['data'])?['data'] ?? save['data']);
    if (tradeNo == null || tradeNo.isEmpty) {
      throw StateError('Failed to create coupon order');
    }

    final checkout = await _authPost(session, '/api/v1/user/order/checkout', data: {'trade_no': tradeNo});
    final type = _readInt(_readMapNullable(checkout['data'])?['type'] ?? checkout['type']) ?? -1;
    return type == -1;
  }

  Future<List<V2etPaymentMethod>> fetchPaymentMethods(V2boardSession session) async {
    final json = await _authGet(session, '/api/v1/user/order/getPaymentMethod');
    final rows = _readList(_readMapNullable(json['data'])?['data'] ?? json['data']);
    return rows
        .map((row) => V2etPaymentMethod(id: _readInt(row['id']) ?? 0, name: _readString(row['name']) ?? 'Payment'))
        .where((m) => m.id > 0)
        .toList();
  }

  Future<String> createOrder({
    required V2boardSession session,
    required int planId,
    required String periodField,
    String? couponCode,
  }) async {
    final save = await _authPost(
      session,
      '/api/v1/user/order/save',
      data: {
        'plan_id': planId,
        'period': periodField,
        if (couponCode != null && couponCode.trim().isNotEmpty) 'coupon_code': couponCode.trim(),
      },
    );
    final tradeNo = _readString(_readMapNullable(save['data'])?['data'] ?? save['data']);
    if (tradeNo == null || tradeNo.isEmpty) {
      throw StateError('Failed to create order');
    }
    return tradeNo;
  }

  Future<V2etCheckoutResult> checkoutOrder({
    required V2boardSession session,
    required String tradeNo,
    int? paymentMethodId,
  }) async {
    final checkout = await _authPost(
      session,
      '/api/v1/user/order/checkout',
      data: {'trade_no': tradeNo, if (paymentMethodId != null) 'method': paymentMethodId},
    );
    final type = _readInt(_readMapNullable(checkout['data'])?['type'] ?? checkout['type']) ?? -1;
    final data = _readString(_readMapNullable(checkout['data'])?['data'] ?? checkout['data']) ?? '';
    return V2etCheckoutResult(type: type, data: data);
  }

  Future<int?> checkOrderStatus({required V2boardSession session, required String tradeNo}) async {
    final uri = _resolveApiUri(session.baseUrl, '/api/v1/user/order/check', queryParameters: {'trade_no': tradeNo});
    DioException? last;
    for (final auth in [session.accessToken.trim(), 'Bearer ${session.accessToken.trim()}']) {
      try {
        final response = await _dio.getUri<Object?>(
          uri,
          options: Options(headers: {'Accept': 'application/json', 'Authorization': auth}),
        );
        final json = _readMap(response.data);
        return _readInt(_readMapNullable(json['data'])?['data'] ?? json['data']);
      } on DioException catch (e) {
        last = e;
      }
    }
    throw last ?? StateError('Order check failed.');
  }

  Future<Map<String, dynamic>> _authGet(V2boardSession session, String path) async {
    final uri = _resolveApiUri(session.baseUrl, path);
    DioException? last;
    for (final auth in [session.accessToken.trim(), 'Bearer ${session.accessToken.trim()}']) {
      try {
        final response = await _dio.getUri<Object?>(
          uri,
          options: Options(headers: {'Accept': 'application/json', 'Authorization': auth}),
        );
        return _readMap(response.data);
      } on DioException catch (e) {
        last = e;
      }
    }
    throw last ?? StateError('Portal request failed.');
  }

  Future<Map<String, dynamic>> _authPost(
    V2boardSession session,
    String path, {
    required Map<String, Object?> data,
  }) async {
    final uri = _resolveApiUri(session.baseUrl, path);
    DioException? last;
    for (final auth in [session.accessToken.trim(), 'Bearer ${session.accessToken.trim()}']) {
      try {
        final response = await _dio.postUri<Object?>(
          uri,
          data: data,
          options: Options(
            headers: {
              'Accept': 'application/json',
              'Authorization': auth,
              'Content-Type': 'application/x-www-form-urlencoded',
            },
          ),
        );
        return _readMap(response.data);
      } on DioException catch (e) {
        last = e;
      }
    }
    throw last ?? StateError('Portal request failed.');
  }

  Map<String, dynamic> _readMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic>? _readMapNullable(Object? value) {
    if (value == null) return null;
    return _readMap(value);
  }

  List<Map<String, dynamic>> _readList(Object? value) {
    if (value is List) {
      return value.whereType<Object?>().map((e) => _readMap(e)).toList();
    }
    return const [];
  }

  String? _readString(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  num? _readNum(Object? value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  double? _readMoney(Object? value) {
    final n = _readNum(value);
    if (n == null) return null;
    return n.toDouble() / 100;
  }

  DateTime? _readUnix(Object? value) {
    final seconds = _readInt(value);
    if (seconds == null || seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true).toLocal();
  }

  DateTime? _readDate(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim())?.toLocal();
    }
    return null;
  }

  Map<String, double> _extractPrices(Map<String, dynamic> row) {
    final mapping = <String, String>{
      'month': 'month_price',
      'quarter': 'quarter_price',
      'half_year': 'half_year_price',
      'year': 'year_price',
      'two_year': 'two_year_price',
      'three_year': 'three_year_price',
      'onetime': 'onetime_price',
      'reset': 'reset_price',
    };
    final result = <String, double>{};
    for (final entry in mapping.entries) {
      final raw = row[entry.value];
      final parsed = _parsePrice(raw);
      if (parsed != null && parsed > 0) {
        result[entry.key] = parsed;
      }
    }
    if (result.isEmpty) {
      result['onetime'] = 0;
    }
    return result;
  }

  double? _parsePrice(Object? raw) {
    if (raw == null) return null;
    if (raw is String) {
      final value = raw.trim();
      if (value.isEmpty) return null;
      if (value.contains('.')) {
        return double.tryParse(value);
      }
      final cents = int.tryParse(value);
      if (cents == null) return null;
      return cents / 100;
    }
    if (raw is int) {
      return raw / 100;
    }
    if (raw is num) {
      if (raw % 1 != 0) return raw.toDouble();
      return raw.toDouble() / 100;
    }
    return null;
  }

  int? _extractTraffic(Map<String, dynamic> row) {
    final candidates = [row['transfer_enable'], row['traffic_limit'], row['data_limit'], row['volume_limit']];
    for (final value in candidates) {
      final parsed = _readInt(value);
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }

  int? _extractDeviceLimit(Map<String, dynamic> row) {
    final candidates = [row['device_limit'], row['ip_limit'], row['devices']];
    for (final value in candidates) {
      final parsed = _readInt(value);
      if (parsed != null) {
        if (parsed <= 0) return null;
        return parsed;
      }
    }
    return null;
  }

  List<String> _extractFeatures(Map<String, dynamic> row) {
    final candidates = <Object?>[row['content'], row['description'], row['remark'], row['features']];
    for (final raw in candidates) {
      final parsed = _parseFeaturePayload(raw);
      if (parsed.isEmpty) {
        continue;
      }
      return parsed;
    }
    return const [];
  }

  List<String> _parseFeaturePayload(Object? raw) {
    if (raw == null) return const [];

    if (raw is List) {
      final list = <String>[];
      for (final item in raw) {
        if (item is Map) {
          final map = item.map((k, v) => MapEntry(k.toString(), v));
          final text = _readString(map['feature']) ?? _readString(map['title']) ?? _readString(map['name']);
          if (text == null || text.isEmpty) continue;
          final supported = _readBool(map['support']) ?? _readBool(map['enabled']) ?? true;
          list.add(supported ? text : '- $text');
        } else if (item is String && item.trim().isNotEmpty) {
          list.add(item.trim());
        }
      }
      return list;
    }

    if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) return const [];

      if (text.startsWith('[') || text.startsWith('{')) {
        try {
          final decoded = jsonDecode(text);
          final parsed = _parseFeaturePayload(decoded);
          if (parsed.isNotEmpty) return parsed;
        } catch (_) {}
      }

      final normalized = text
          .replaceAll('<br/>', '\n')
          .replaceAll('<br>', '\n')
          .replaceAll('</li>', '\n')
          .replaceAll('<li>', '')
          .replaceAll('</p>', '\n')
          .replaceAll('<p>', '')
          .replaceAll('&nbsp;', ' ');
      final lines = normalized
          .split(RegExp(r'\r?\n'))
          .map((e) => e.replaceAll(RegExp('<[^>]*>'), '').trim())
          .where((e) => e.isNotEmpty)
          .toList();
      return lines;
    }

    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      for (final key in const ['feature', 'title', 'name']) {
        final text = _readString(map[key]);
        if (text != null && text.isNotEmpty) {
          final supported = _readBool(map['support']) ?? _readBool(map['enabled']) ?? true;
          return [supported ? text : '- $text'];
        }
      }
    }

    return const [];
  }

  String? _speedLabel(Object? raw) {
    if (raw is String) {
      final t = raw.trim();
      if (t.isEmpty) return null;
      if (t.contains(RegExp(r'[a-zA-Z]'))) return t;
      final value = int.tryParse(t);
      if (value == null || value <= 0) return null;
      return '${value}Mbps';
    }
    final speed = _readInt(raw);
    if (speed == null || speed <= 0) {
      return null;
    }
    return '${speed}Mbps';
  }

  bool? _readBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final t = value.trim().toLowerCase();
      if (t == 'true' || t == '1' || t == 'yes' || t == 'on') return true;
      if (t == 'false' || t == '0' || t == 'no' || t == 'off') return false;
    }
    return null;
  }

  Uri _resolveApiUri(Uri base, String path, {Map<String, String>? queryParameters}) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final basePath = _normalizeBasePath(base.path);
    final mergedPath = basePath.isEmpty ? normalizedPath : '$basePath$normalizedPath';
    return base.replace(path: mergedPath, queryParameters: queryParameters, fragment: null);
  }

  String _normalizeBasePath(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '/') return '';
    var value = trimmed;
    if (!value.startsWith('/')) {
      value = '/$value';
    }
    if (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }
}
