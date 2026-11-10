import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/device/device_identity.dart';
import '../core/i18n/tr.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/network/idempotency.dart';
import '../core/storage/secure_store.dart';
import '../features/auth/data/auth_api.dart';

/// Overridden in `main.dart` once the async boot work is done.
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('prefsProvider'));
final tokenStoreProvider = Provider<TokenStore>((ref) => throw UnimplementedError('tokenStoreProvider'));
final deviceProvider = Provider<DeviceIdentity>((ref) => throw UnimplementedError('deviceProvider'));

/// UI language; also sent as `Accept-Language`.
class LanguageController extends Notifier<AppLanguage> {
  static const _key = 'gd.language';

  @override
  AppLanguage build() => AppLanguage.fromCode(ref.read(prefsProvider).getString(_key));

  Future<void> set(AppLanguage language) async {
    state = language;
    await ref.read(prefsProvider).setString(_key, language.code);
  }
}

final languageProvider = NotifierProvider<LanguageController, AppLanguage>(LanguageController.new);

/// Light / dark / system, stored on the device (the API has no theme).
class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'gd.theme';

  @override
  ThemeMode build() => switch (ref.read(prefsProvider).getString(_key)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.light,
      };

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(prefsProvider).setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    device: ref.watch(deviceProvider),
    tokens: ref.watch(tokenStoreProvider),
    language: () => ref.read(languageProvider),
  );
  client.onSessionEnded = (code, message) => ref.read(sessionEventsProvider.notifier).ended(code, message);
  client.onUpdateRequired = (error) => ref.read(updateRequiredProvider.notifier).set(error);
  return client;
});

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(apiClientProvider)));

final idempotencyProvider = Provider<IdempotencyKeys>((ref) => IdempotencyKeys());

/// Set when the API answered 426 `app_update_required`.
class UpdateRequiredController extends Notifier<ApiException?> {
  @override
  ApiException? build() => null;
  void set(ApiException error) => state = error;
}

final updateRequiredProvider = NotifierProvider<UpdateRequiredController, ApiException?>(UpdateRequiredController.new);

/// The server ended the session (bridge from the HTTP client to the session).
class SessionEnd {
  const SessionEnd(this.code, this.message);
  final String code;
  final String message;
}

class SessionEventsController extends Notifier<SessionEnd?> {
  @override
  SessionEnd? build() => null;
  void ended(String code, String message) => state = SessionEnd(code, message);
  void consumed() => state = null;
}

final sessionEventsProvider = NotifierProvider<SessionEventsController, SessionEnd?>(SessionEventsController.new);
