import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hiddify/v2et/model/v2board_credentials.dart';
import 'package:hiddify/v2et/model/v2board_session.dart';
import 'package:hiddify/v2et/model/v2board_subscription.dart';

abstract interface class V2boardApi {
  Future<V2boardSession> login(V2boardCredentials credentials);

  Future<V2boardSubscription> fetchSubscription(V2boardSession session);

  Future<V2boardAuthConfig> fetchAuthConfig(Uri baseUrl);

  Future<void> sendEmailVerifyCode({required Uri baseUrl, required String email});

  Future<void> register({
    required Uri baseUrl,
    required String email,
    required String password,
    String? emailCode,
    String? inviteCode,
  });

  Future<void> resetPassword({
    required Uri baseUrl,
    required String email,
    required String password,
    required String emailCode,
  });
}

class V2boardAuthConfig {
  const V2boardAuthConfig({
    required this.requireEmailVerify,
    required this.requireInviteCode,
    required this.emailWhitelistSuffixes,
  });

  final bool requireEmailVerify;
  final bool requireInviteCode;
  final List<String> emailWhitelistSuffixes;
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

  @override
  Future<V2boardAuthConfig> fetchAuthConfig(Uri baseUrl) {
    throw UnsupportedError("V2Board API is not implemented yet.");
  }

  @override
  Future<void> sendEmailVerifyCode({required Uri baseUrl, required String email}) {
    throw UnsupportedError("V2Board API is not implemented yet.");
  }

  @override
  Future<void> register({
    required Uri baseUrl,
    required String email,
    required String password,
    String? emailCode,
    String? inviteCode,
  }) {
    throw UnsupportedError("V2Board API is not implemented yet.");
  }

  @override
  Future<void> resetPassword({
    required Uri baseUrl,
    required String email,
    required String password,
    required String emailCode,
  }) {
    throw UnsupportedError("V2Board API is not implemented yet.");
  }
}

class V2boardApiImpl implements V2boardApi {
  V2boardApiImpl({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  Future<V2boardSession> login(V2boardCredentials credentials) async {
    late final Response<Object?> response;
    try {
      response = await _postGuestForm(
        baseUrl: credentials.baseUrl,
        path: '/api/v1/passport/auth/login',
        data: {'email': credentials.email, 'password': credentials.password},
      );
    } on DioException catch (error) {
      final message =
          _extractApiMessage(error.response?.data) ?? _readString(error.message) ?? 'V2Board login request failed.';
      throw StateError(message);
    }
    final json = _readMap(response.data);
    final token = _extractToken(json);
    if (token == null || token.isEmpty) {
      throw StateError('V2Board login succeeded but token is missing.');
    }
    return V2boardSession(baseUrl: credentials.baseUrl, accessToken: token, createdAt: DateTime.now().toUtc());
  }

  String? _extractApiMessage(Object? responseData) {
    try {
      final json = _readMapNullable(responseData);
      if (json == null) return null;
      final candidates = [
        json['message'],
        json['msg'],
        json['error'],
        _readMapNullable(json['data'])?['message'],
        _readMapNullable(json['data'])?['msg'],
        _readMapNullable(json['data'])?['error'],
      ];
      for (final candidate in candidates) {
        final text = _readString(candidate);
        if (text != null) return text;
      }

      final errors = _readMapNullable(json['errors']) ?? _readMapNullable(_readMapNullable(json['data'])?['errors']);
      if (errors != null) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) {
            final first = _readString(value.first);
            if (first != null) return first;
          }
          final text = _readString(value);
          if (text != null) return text;
        }
      }
    } catch (_) {
      return _readString(responseData);
    }
    return null;
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

  @override
  Future<V2boardAuthConfig> fetchAuthConfig(Uri baseUrl) async {
    final uri = _joinApi(baseUrl, '/api/v1/guest/comm/config');
    final response = await _dio.getUri<Object?>(uri, options: Options(headers: {'Accept': 'application/json'}));
    final json = _readMap(response.data);
    final data = _readMapNullable(json['data']) ?? json;
    return V2boardAuthConfig(
      requireEmailVerify: _readBool(data['is_email_verify']) ?? false,
      requireInviteCode: _readBool(data['is_invite_force']) ?? false,
      emailWhitelistSuffixes: _readStringList(
        data['email_whitelist_suffix'] ??
            data['email_whitelist_suffixes'] ??
            data['email_suffix_whitelist'] ??
            data['email_suffixes'],
      ),
    );
  }

  @override
  Future<void> sendEmailVerifyCode({required Uri baseUrl, required String email}) async {
    try {
      await _postGuestForm(baseUrl: baseUrl, path: '/api/v1/passport/comm/sendEmailVerify', data: {'email': email});
    } on DioException catch (error) {
      final message =
          _extractApiMessage(error.response?.data) ?? _readString(error.message) ?? 'V2Board send email code failed.';
      throw StateError(message);
    }
  }

  @override
  Future<void> register({
    required Uri baseUrl,
    required String email,
    required String password,
    String? emailCode,
    String? inviteCode,
  }) async {
    final payload = <String, Object>{'email': email, 'password': password, 'password_confirmation': password};
    if (emailCode != null && emailCode.trim().isNotEmpty) {
      payload['email_code'] = emailCode.trim();
    }
    if (inviteCode != null && inviteCode.trim().isNotEmpty) {
      payload['invite_code'] = inviteCode.trim();
    }
    try {
      await _postGuestForm(baseUrl: baseUrl, path: '/api/v1/passport/auth/register', data: payload);
    } on DioException catch (error) {
      final message =
          _extractApiMessage(error.response?.data) ?? _readString(error.message) ?? 'V2Board register request failed.';
      throw StateError(message);
    }
  }

  @override
  Future<void> resetPassword({
    required Uri baseUrl,
    required String email,
    required String password,
    required String emailCode,
  }) async {
    try {
      await _postGuestForm(
        baseUrl: baseUrl,
        path: '/api/v1/passport/auth/forget',
        data: {'email': email, 'email_code': emailCode, 'password': password, 'password_confirmation': password},
      );
    } on DioException catch (error) {
      final message =
          _extractApiMessage(error.response?.data) ??
          _readString(error.message) ??
          'V2Board reset password request failed.';
      throw StateError(message);
    }
  }

  Future<Response<Object?>> _postGuestForm({
    required Uri baseUrl,
    required String path,
    required Map<String, Object?> data,
  }) async {
    final uri = _joinApi(baseUrl, path);
    final referer = baseUrl.replace(path: '/').toString();
    final origin = '${baseUrl.scheme}://${baseUrl.host}';
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded',
      'X-Requested-With': 'XMLHttpRequest',
      'Referer': referer,
      'Origin': origin,
    };

    try {
      return await _dio.postUri<Object?>(
        uri,
        data: FormData.fromMap(data),
        options: Options(headers: headers),
      );
    } on DioException {
      return _dio.postUri<Object?>(
        uri,
        data: data,
        options: Options(headers: headers),
      );
    }
  }

  Future<Map<String, dynamic>> _fetchSubscribeJson(Uri baseUrl, String token) async {
    final uri = _joinApi(baseUrl, '/api/v1/user/getSubscribe');
    for (final authHeader in [token, 'Bearer $token']) {
      final response = await _dio.getUri<Object?>(
        uri,
        options: Options(headers: {'Accept': 'application/json', 'Authorization': authHeader}),
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
    final candidates = [data?['auth_data'], data?['token'], json['auth_data'], json['token'], json['access_token']];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }

  Uri? _extractSubscribeUrl(Map<String, dynamic> json) {
    final data = _readMapNullable(json['data']);
    final candidates = [data?['subscribe_url'], data?['url'], json['subscribe_url'], json['url']];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return Uri.tryParse(candidate.trim());
      }
    }
    return null;
  }

  Uri _joinApi(Uri base, String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final basePath = _normalizeBasePath(base.path);
    final mergedPath = basePath.isEmpty ? normalizedPath : '$basePath$normalizedPath';
    return base.replace(path: mergedPath, query: null, fragment: null);
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
    final lines = content.split(RegExp(r'\r?\n')).map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
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

  List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value.map((item) => _readString(item) ?? '').where((item) => item.isNotEmpty).toSet().toList();
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
