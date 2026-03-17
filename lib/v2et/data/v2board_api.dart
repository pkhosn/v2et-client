import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hiddify/v2et/model/v2board_credentials.dart';
import 'package:hiddify/v2et/model/v2board_session.dart';
import 'package:hiddify/v2et/model/v2board_subscription.dart';

abstract interface class V2boardApi {
  Future<V2boardSession> login(V2boardCredentials credentials);

  Future<V2boardSubscription> fetchSubscription(V2boardSession session);
}

class V2boardApiStub implements V2boardApi {
  @override
  Future<V2boardSession> login(V2boardCredentials credentials) {
    throw UnsupportedError("V2Board API is not implemented yet.");
  }

  @override
  Future<V2boardSubscription> fetchSubscription(V2boardSession session) {
    throw UnsupportedError("V2Board API is not implemented yet.");
  }
}

class V2boardApiImpl implements V2boardApi {
  V2boardApiImpl({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  Future<V2boardSession> login(V2boardCredentials credentials) async {
    final uri = _joinApi(credentials.baseUrl, '/api/v1/passport/auth/login');
    final response = await _dio.postUri<Object?>(
      uri,
      data: {
        'email': credentials.email,
        'password': credentials.password,
      },
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      ),
    );
    final json = _readMap(response.data);
    final token = _extractToken(json);
    if (token == null || token.isEmpty) {
      throw StateError('V2Board login succeeded but token is missing.');
    }
    return V2boardSession(baseUrl: credentials.baseUrl, accessToken: token, createdAt: DateTime.now().toUtc());
  }

  @override
  Future<V2boardSubscription> fetchSubscription(V2boardSession session) async {
    final token = session.accessToken.trim();
    if (token.isEmpty) {
      throw StateError('V2Board token is missing.');
    }
    final subscribeJson = await _fetchSubscribeJson(session.baseUrl, token);
    final subscribeUrl = _extractSubscribeUrl(subscribeJson);
    if (subscribeUrl == null) {
      throw StateError('V2Board subscribe url not found in response.');
    }
    final data = _readMapNullable(subscribeJson['data']);
    final plan = _readMapNullable(data?['plan']);
    final nodeCount = await _readNodeCount(subscribeUrl);
    return V2boardSubscription(
      subscriptionUrl: subscribeUrl,
      fetchedAt: DateTime.now().toUtc(),
      planName: _readString(plan?['name']) ?? _readString(data?['plan_name']),
      transferEnableBytes: _readInt(data?['transfer_enable']),
      expiredAt: _readTimestamp(data?['expired_at']),
      nodeCount: nodeCount,
    );
  }

  Future<Map<String, dynamic>> _fetchSubscribeJson(Uri baseUrl, String token) async {
    final uri = _joinApi(baseUrl, '/api/v1/user/getSubscribe');
    for (final authHeader in [token, 'Bearer $token']) {
      final response = await _dio.getUri<Object?>(
        uri,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': authHeader,
          },
        ),
      );
      final json = _readMap(response.data);
      if (_extractSubscribeUrl(json) != null) {
        return json;
      }
    }
    throw StateError('Failed to fetch V2Board subscription with available auth headers.');
  }

  String? _extractToken(Map<String, dynamic> json) {
    final data = _readMapNullable(json['data']);
    final candidates = [
      data?['auth_data'],
      data?['token'],
      json['auth_data'],
      json['token'],
      json['access_token'],
    ];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }

  Uri? _extractSubscribeUrl(Map<String, dynamic> json) {
    final data = _readMapNullable(json['data']);
    final candidates = [
      data?['subscribe_url'],
      data?['url'],
      json['subscribe_url'],
      json['url'],
    ];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return Uri.tryParse(candidate.trim());
      }
    }
    return null;
  }

  Uri _joinApi(Uri base, String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return base.replace(path: normalizedPath);
  }

  Future<int?> _readNodeCount(Uri subscribeUrl) async {
    try {
      final response = await _dio.getUri<String>(subscribeUrl, options: Options(responseType: ResponseType.plain));
      final raw = (response.data ?? '').trim();
      if (raw.isEmpty) {
        return 0;
      }

      final directCount = _countLinks(raw);
      if (directCount != null) {
        return directCount;
      }

      final decoded = utf8.decode(base64.decode(raw), allowMalformed: true);
      return _countLinks(decoded) ?? 0;
    } catch (_) {
      return null;
    }
  }

  int? _countLinks(String content) {
    final lines = content
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return 0;
    }
    final linkCount = lines.where((line) => line.contains('://')).length;
    if (linkCount > 0) {
      return linkCount;
    }
    return null;
  }

  String? _readString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  DateTime? _readTimestamp(Object? value) {
    final seconds = _readInt(value);
    if (seconds == null || seconds <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  Map<String, dynamic> _readMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        result[entry.key.toString()] = entry.value;
      }
      return result;
    }
    throw StateError('Expected JSON object response from V2Board API.');
  }

  Map<String, dynamic>? _readMapNullable(Object? value) {
    if (value == null) {
      return null;
    }
    return _readMap(value);
  }
}
