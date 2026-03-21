import 'package:hiddify/v2et/data/v2board_api.dart';
import 'package:hiddify/v2et/data/v2et_credentials_store.dart';
import 'package:hiddify/v2et/model/v2board_credentials.dart';
import 'package:hiddify/v2et/model/v2board_session.dart';
import 'package:hiddify/v2et/model/v2board_subscription.dart';

abstract interface class V2etRepository {
  Future<void> warmup();

  Future<V2boardSubscription> loginAndFetchSubscription(
    V2boardCredentials credentials,
  );

  Future<V2boardCredentials?> readSavedCredentials();

  Future<void> logout();

  Future<V2boardSession?> restoreSession();

  V2boardSubscription? readLastSubscription();
}

class V2etRepositoryImpl implements V2etRepository {
  const V2etRepositoryImpl({
    required V2boardApi v2boardApi,
    required V2etCredentialsStore credentialsStore,
  }) : _v2boardApi = v2boardApi,
       _credentialsStore = credentialsStore;

  final V2boardApi _v2boardApi;
  final V2etCredentialsStore _credentialsStore;

  @override
  Future<void> warmup() async {
    final session = await _credentialsStore.readSession();
    if (session != null && session.hasToken) {
      final subscription = await _v2boardApi.fetchSubscription(session);
      await _credentialsStore.saveLastSubscription(subscription);
    }
  }

  @override
  Future<V2boardSubscription> loginAndFetchSubscription(
    V2boardCredentials credentials,
  ) async {
    try {
      final session = await _v2boardApi.login(credentials);
      final subscription = await _v2boardApi.fetchSubscription(session);
      await _credentialsStore.saveCredentials(credentials);
      await _credentialsStore.saveSession(session);
      await _credentialsStore.saveLastSubscription(subscription);
      return subscription;
    } catch (_) {
      await _credentialsStore.clearSessionOnly();
      rethrow;
    }
  }

  @override
  Future<V2boardCredentials?> readSavedCredentials() {
    return _credentialsStore.readCredentials();
  }

  @override
  Future<void> logout() {
    return _credentialsStore.clearSessionOnly();
  }

  @override
  Future<V2boardSession?> restoreSession() async {
    final credentials = await _credentialsStore.readCredentials();
    if (credentials == null) return null;
    final session = await _v2boardApi.login(credentials);
    await _credentialsStore.saveSession(session);
    return session;
  }

  @override
  V2boardSubscription? readLastSubscription() {
    return _credentialsStore.readLastSubscription();
  }
}

class V2etNoopRepository implements V2etRepository {
  const V2etNoopRepository();

  @override
  Future<void> warmup() async {}

  @override
  Future<V2boardSubscription> loginAndFetchSubscription(
    V2boardCredentials credentials,
  ) {
    throw StateError("V2ET adapter is disabled.");
  }

  @override
  Future<V2boardCredentials?> readSavedCredentials() async => null;

  @override
  Future<void> logout() async {}

  @override
  Future<V2boardSession?> restoreSession() async => null;

  @override
  V2boardSubscription? readLastSubscription() => null;
}
