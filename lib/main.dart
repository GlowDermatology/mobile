import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/config/app_config.dart';
import 'core/device/device_identity.dart';
import 'core/network/api_exception.dart';
import 'core/push/push_service.dart';
import 'core/storage/secure_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.e2e) SemanticsBinding.instance.ensureSemantics();

  final prefs = await SharedPreferences.getInstance();
  final tokens = TokenStore(secureStorage);
  await tokens.load(prefs);
  final device = await DeviceIdentity.load(tokens);
  await initPush();

  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(tokens),
        deviceProvider.overrideWithValue(device),
      ],
      // Riverpod retries failing providers; an API refusal (4xx) will not
      // change by retrying, a network error may.
      retry: (count, error) {
        if (error is ApiException && !error.isNetwork) return null;
        if (error is SessionEnded) return null;
        return count < 2 ? Duration(milliseconds: 600 * (count + 1)) : null;
      },
      child: const GlowDermaApp(),
    ),
  );
}
