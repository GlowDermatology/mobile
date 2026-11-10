import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:glow_derma/app/providers.dart';
import 'package:glow_derma/app/theme/gd_theme.dart';
import 'package:glow_derma/core/i18n/tr.dart';
import 'package:glow_derma/features/auth/application/session_controller.dart';
import 'package:glow_derma/features/notifications/data/unread_count.dart';
import 'package:go_router/go_router.dart';

class FakeLanguage extends LanguageController {
  @override
  AppLanguage build() => AppLanguage.uz;
}

class FakeSession extends SessionController {
  @override
  AuthState build() => const AuthState(signedIn: true);
}

class FakeUnread extends UnreadCountController {
  FakeUnread(this.initial);
  final int initial;
  @override
  int build() => initial;
}

List<Override> commonOverrides({int unread = 0}) => [
  languageProvider.overrideWith(FakeLanguage.new),
  sessionProvider.overrideWith(FakeSession.new),
  unreadCountProvider.overrideWith(() => FakeUnread(unread)),
];

/// [home] at `/`, plus stub pages that print their location.
Widget routerApp(
  Widget home,
  List<Override> overrides, {
  ProviderContainer? container,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      for (final p in [
        '/orders/:id',
        '/appointments/:id',
        '/product/:id',
        '/settings/phone',
      ])
        GoRoute(
          path: p,
          builder: (_, s) => Scaffold(body: Text('page ${s.uri}')),
        ),
    ],
  );
  final app = MaterialApp.router(
    routerConfig: router,
    theme: buildTheme(Brightness.light),
    locale: const Locale('uz'),
    supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
  return container != null
      ? UncontrolledProviderScope(container: container, child: app)
      : ProviderScope(overrides: overrides, child: app);
}
