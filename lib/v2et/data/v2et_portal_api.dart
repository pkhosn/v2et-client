import 'package:dio/dio.dart';
import 'package:hiddify/v2et/model/v2board_session.dart';
import 'package:hiddify/v2et/model/v2et_portal_models.dart';

class V2etPortalApi {
  V2etPortalApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<List<V2etNotice>> fetchNotices(V2boardSession session) async {
    final json = await _authGet(session, '/api/v1/user/notice/fetch');
    final rows = _readList(
      _readMapNullable(json['data'])?['data'] ?? json['data'],
    );
    return rows
        .map(
          (row) => V2etNotice(
            title: _readString(row['title']) ?? 'Notice',
            content: _readString(row['content']) ?? '',
          ),
        )
        .toList();
  }

  Future<List<V2etStoreOffer>> fetchPlans(V2boardSession session) async {
    final json = await _authGet(session, '/api/v1/user/plan/fetch');
    final rows = _readList(
      _readMapNullable(json['data'])?['data'] ?? json['data'],
    );
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
      final orders = _readList(
        _readMapNullable(orderJson['data'])?['data'] ?? orderJson['data'],
      );
      counters['orders'] = orders.length;
    } catch (_) {}
    try {
      final ticketJson = await _authGet(session, '/api/v1/user/ticket/fetch');
      final tickets = _readList(
        _readMapNullable(ticketJson['data'])?['data'] ?? ticketJson['data'],
      );
      counters['tickets'] = tickets.length;
    } catch (_) {}
    return counters;
  }

  Future<Map<String, dynamic>> _authGet(
    V2boardSession session,
    String path,
  ) async {
    final uri = session.baseUrl.replace(
      path: path,
      query: null,
      fragment: null,
    );
    DioException? last;
    for (final auth in [
      session.accessToken.trim(),
      'Bearer ${session.accessToken.trim()}',
    ]) {
      try {
        final response = await _dio.getUri<Object?>(
          uri,
          options: Options(
            headers: {'Accept': 'application/json', 'Authorization': auth},
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
    final candidates = [
      row['transfer_enable'],
      row['traffic_limit'],
      row['data_limit'],
      row['volume_limit'],
    ];
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
    final candidates = <String?>[
      _readString(row['content']),
      _readString(row['description']),
      _readString(row['remark']),
    ];
    for (final text in candidates) {
      if (text == null || text.trim().isEmpty) {
        continue;
      }
      final normalized = text
          .replaceAll('<br/>', '\n')
          .replaceAll('<br>', '\n')
          .replaceAll('</p>', '\n')
          .replaceAll('<p>', '')
          .replaceAll('&nbsp;', ' ');
      final lines = normalized
          .split(RegExp(r'\r?\n'))
          .map((e) => e.replaceAll(RegExp('<[^>]*>'), '').trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (lines.isNotEmpty) {
        return lines;
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
}
