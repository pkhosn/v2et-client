import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hiddify/v2et/data/v2board_api.dart';
import 'package:hiddify/v2et/data/v2et_credentials_store.dart';
import 'package:hiddify/v2et/data/v2et_endpoint_resolver.dart';
import 'package:hiddify/v2et/model/v2board_session.dart';
import 'package:hiddify/v2et/data/v2et_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final v2etSecureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final v2etEndpointResolverProvider = Provider<V2etEndpointResolver>((ref) {
  return V2etEndpointResolver();
});

final v2etCredentialsStoreProvider = Provider<V2etCredentialsStore>((ref) {
  return V2etCredentialsStore(
    preferences: ref.watch(sharedPreferencesProvider).requireValue,
    secureStorage: ref.watch(v2etSecureStorageProvider),
  );
});

final v2etSessionProvider = FutureProvider<V2boardSession?>((ref) async {
  return await ref.watch(v2etCredentialsStoreProvider).readSession();
});

final v2boardApiProvider = Provider<V2boardApi>((ref) {
  return V2boardApiImpl();
});

final v2etRepositoryProvider = Provider<V2etRepository>((ref) {
  final isEnabled = ref.watch(Preferences.enableV2etAdapter);
  if (!isEnabled) {
    return const V2etNoopRepository();
  }
  return V2etRepositoryImpl(
    v2boardApi: ref.watch(v2boardApiProvider),
    credentialsStore: ref.watch(v2etCredentialsStoreProvider),
  );
});

final v2etBootstrapProvider = FutureProvider<void>((ref) async {
  final isEnabled = ref.watch(Preferences.enableV2etAdapter);
  if (!isEnabled) {
    return;
  }
  await ref.watch(v2etRepositoryProvider).warmup();
});

final v2etSessionUnlockedProvider = StateProvider<bool>((ref) => false);
