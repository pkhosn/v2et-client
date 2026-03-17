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
        .map((row) => V2etNotice(title: _readString(row['title']) ?? 'Notice', content: _readString(row['content']) ?? ''))
        .toList();
  }

  Future<List<V2etStoreOffer>> fetchPlans(V2boardSession session) async {
    final json = await _authGet(session, '/api/v1/user/plan/fetch');
    final rows = _readList(_readMapNullable(json['data'])?['data'] ?? json['data']);
    return rows
        .map((row) => V2etStoreOffer(
              name: _readString(row['name']) ?? 'Plan',
              price: _pickPrice(row),
              cycleLabel: _pickCycle(row),
              traffic: _readInt(row['transfer_enable']),
              speed: _speedLabel(row['speed_limit']),
              deviceLimit: _readInt(row['device_limit']),
            ))
        .toList();
  }

  Future<Map<String, int>> fetchCounters(V2boardSession session) async {
    final counters = <String, int>{
      'orders': 0,
      'tickets': 0,
    };
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

  Future<Map<String, dynamic>> _authGet(V2boardSession session, String path) async {
    final uri = session.baseUrl.replace(path: path, query: null, fragment: null);
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

  double _pickPrice(Map<String, dynamic> row) {
    final monthly = _readInt(row['month_price']) ?? _readInt(row['onetime_price']) ?? 0;
    return monthly / 100;
  }

  String _pickCycle(Map<String, dynamic> row) {
    if (_readInt(row['month_price']) != null) return '/month';
    if (_readInt(row['onetime_price']) != null) return '/one-time';
    return '/period';
  }

  String? _speedLabel(Object? raw) {
    final speed = _readInt(raw);
    if (speed == null || speed <= 0) {
      return null;
    }
    return '${speed}Mbps';
  }
}
