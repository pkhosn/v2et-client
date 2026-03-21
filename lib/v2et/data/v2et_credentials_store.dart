import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hiddify/v2et/model/v2board_credentials.dart';
import 'package:hiddify/v2et/model/v2board_session.dart';
import 'package:hiddify/v2et/model/v2board_subscription.dart';
import 'package:shared_preferences/shared_preferences.dart';

class V2etCredentialsStore {
  const V2etCredentialsStore({
    required SharedPreferences preferences,
    required FlutterSecureStorage secureStorage,
  }) : _preferences = preferences,
       _secureStorage = secureStorage;

  final SharedPreferences _preferences;
  final FlutterSecureStorage _secureStorage;

  static const _baseUrlKey = 'v2et.base_url';
  static const _emailKey = 'v2et.email';
  static const _passwordKey = 'v2et.password';
  static const _tokenKey = 'v2et.token';
  static const _tokenAtKey = 'v2et.token_created_at';
  static const _planNameKey = 'v2et.plan_name';
  static const _transferEnableKey = 'v2et.transfer_enable';
  static const _expiredAtKey = 'v2et.expired_at';
  static const _nodeCountKey = 'v2et.node_count';
  static const _subUrlKey = 'v2et.subscription_url';
  static const _subFetchedAtKey = 'v2et.subscription_fetched_at';

  static const _preferenceKeys = <String>{
    _baseUrlKey,
    _emailKey,
    _passwordKey,
    _tokenKey,
    _tokenAtKey,
    _planNameKey,
    _transferEnableKey,
    _expiredAtKey,
    _nodeCountKey,
    _subUrlKey,
    _subFetchedAtKey,
  };

  Future<V2boardCredentials?> readCredentials() async {
    final baseUrlRaw = _preferences.getString(_baseUrlKey);
    final email = _preferences.getString(_emailKey);
    final password =
        await _readSecure(_passwordKey) ?? _preferences.getString(_passwordKey);
    if (baseUrlRaw == null || email == null || password == null) {
      return null;
    }
    final uri = Uri.tryParse(baseUrlRaw);
    if (uri == null || !uri.hasAuthority) {
      return null;
    }
    return V2boardCredentials(baseUrl: uri, email: email, password: password);
  }

  Future<V2boardSession?> readSession() async {
    final baseUrlRaw = _preferences.getString(_baseUrlKey);
    final baseUrl = baseUrlRaw == null ? null : Uri.tryParse(baseUrlRaw);
    final token =
        await _readSecure(_tokenKey) ?? _preferences.getString(_tokenKey);
    if (baseUrl == null || token == null || token.isEmpty) {
      return null;
    }
    final createdAtRaw = _preferences.getString(_tokenAtKey);
    final createdAt = createdAtRaw == null
        ? DateTime.now().toUtc()
        : DateTime.tryParse(createdAtRaw) ?? DateTime.now().toUtc();
    return V2boardSession(
      baseUrl: baseUrl,
      accessToken: token,
      createdAt: createdAt,
    );
  }

  Future<void> saveCredentials(V2boardCredentials credentials) async {
    await _preferences.setString(_baseUrlKey, credentials.baseUrl.toString());
    await _preferences.setString(_emailKey, credentials.email);
    await _writeSecure(_passwordKey, credentials.password);
    await _preferences.setString(_passwordKey, credentials.password);
  }

  Future<void> saveSession(V2boardSession session) async {
    await _writeSecure(_tokenKey, session.accessToken);
    await _preferences.setString(_tokenKey, session.accessToken);
    await _preferences.setString(
      _tokenAtKey,
      session.createdAt.toUtc().toIso8601String(),
    );
  }

  V2boardSubscription? readLastSubscription() {
    final subUrlRaw = _preferences.getString(_subUrlKey);
    final fetchedAtRaw = _preferences.getString(_subFetchedAtKey);
    final subUrl = subUrlRaw == null ? null : Uri.tryParse(subUrlRaw);
    final fetchedAt = fetchedAtRaw == null
        ? null
        : DateTime.tryParse(fetchedAtRaw);
    if (subUrl == null || fetchedAt == null) {
      return null;
    }

    final planName = _preferences.getString(_planNameKey);
    final transferEnable = _preferences.getInt(_transferEnableKey);
    final expiredAtRaw = _preferences.getString(_expiredAtKey);
    final expiredAt = expiredAtRaw == null
        ? null
        : DateTime.tryParse(expiredAtRaw);
    final nodeCount = _preferences.getInt(_nodeCountKey);
    return V2boardSubscription(
      subscriptionUrl: subUrl,
      fetchedAt: fetchedAt,
      planName: planName,
      transferEnableBytes: transferEnable,
      expiredAt: expiredAt,
      nodeCount: nodeCount,
    );
  }

  Future<void> saveLastSubscription(V2boardSubscription subscription) async {
    await _preferences.setString(
      _subUrlKey,
      subscription.subscriptionUrl.toString(),
    );
    await _preferences.setString(
      _subFetchedAtKey,
      subscription.fetchedAt.toUtc().toIso8601String(),
    );
    if (subscription.planName != null) {
      await _preferences.setString(_planNameKey, subscription.planName!);
    } else {
      await _preferences.remove(_planNameKey);
    }
    if (subscription.transferEnableBytes != null) {
      await _preferences.setInt(
        _transferEnableKey,
        subscription.transferEnableBytes!,
      );
    } else {
      await _preferences.remove(_transferEnableKey);
    }
    if (subscription.expiredAt != null) {
      await _preferences.setString(
        _expiredAtKey,
        subscription.expiredAt!.toUtc().toIso8601String(),
      );
    } else {
      await _preferences.remove(_expiredAtKey);
    }
    if (subscription.nodeCount != null) {
      await _preferences.setInt(_nodeCountKey, subscription.nodeCount!);
    } else {
      await _preferences.remove(_nodeCountKey);
    }
  }

  Future<void> clearAll() async {
    for (final key in _preferenceKeys) {
      await _preferences.remove(key);
    }
    await _deleteSecure(_passwordKey);
    await _deleteSecure(_tokenKey);
  }

  Future<void> clearSessionOnly() async {
    await _preferences.remove(_tokenKey);
    await _preferences.remove(_tokenAtKey);
    await _deleteSecure(_tokenKey);
    await _preferences.remove(_planNameKey);
    await _preferences.remove(_transferEnableKey);
    await _preferences.remove(_expiredAtKey);
    await _preferences.remove(_nodeCountKey);
    await _preferences.remove(_subUrlKey);
    await _preferences.remove(_subFetchedAtKey);
  }

  Future<String?> _readSecure(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeSecure(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {
      await _preferences.setString(key, value);
    }
  }

  Future<void> _deleteSecure(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {
      await _preferences.remove(key);
    }
  }
}
