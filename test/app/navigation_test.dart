import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/app/providers.dart';
import 'package:glow_derma/app/router.dart';
import 'package:glow_derma/app/theme/gd_theme.dart';
import 'package:glow_derma/core/device/device_identity.dart';
import 'package:glow_derma/core/i18n/tr.dart';
import 'package:glow_derma/core/network/api_client.dart';
import 'package:glow_derma/core/storage/secure_store.dart';
import 'package:glow_derma/features/auth/application/session_controller.dart';
import 'package:glow_derma/features/catalog/data/catalog_api.dart';
import 'package:glow_derma/features/settings/data/public_settings.dart';
import 'package:go_router/go_router.dart';

import '../core/scripted_adapter.dart';
import '../features/auth/fakes.dart';
import '../features/catalog/fakes.dart' show FakeCatalogApi;

final _device = DeviceIdentity(
  id: 'device0001',
  platform: 'android',
  appVersion: '1.0.0',
  model: 'Pixel',
  os: 'Android 15',
);

class _FakeTheme extends ThemeModeController {
  @override
  ThemeMode build() => ThemeMode.light;
}

/// The real router, shell and tab screens for a guest; every HTTP request
/// is recorded (none should need a session).
class _GuestApp {
  final adapter = ScriptedAdapter((o) => ScriptedAdapter.json(200, {}));
  late final container = ProviderContainer(
    overrides: [
      languageProvider.overrideWith(FakeLanguage.new),
      themeModeProvider.overrideWith(_FakeTheme.new),
      sessionProvider.overrideWith(FakeSession.new),
      deviceProvider.overrideWithValue(_device),
      tokenStoreProvider.overrideWithValue(TokenStore(secureStorage)),
      apiClientProvider.overrideWithValue(
        ApiClient(
          device: _device,
          tokens: TokenStore(secureStorage),
          language: () => AppLanguage.uz,
          baseUrl: 'https://api.test/api/v1/',
          adapter: adapter,
        ),
      ),
      catalogApiProvider.overrideWithValue(FakeCatalogApi()),
      publicSettingsProvider.overrideWith(
        (ref) async => const PublicSettings({'terms_version': '2026-10'}),
      ),
    ],
  );

  GoRouter get router => container.read(routerProvider);

  /// The location on top, pushed pages included.
  Uri get top {
    final config = router.routerDelegate.currentConfiguration;
    final last = config.matches.last;
    return last is ImperativeRouteMatch ? last.matches.uri : config.uri;
  }

  String get path => top.path;

  Future<void> pump(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: buildTheme(Brightness.light),
          locale: const Locale('uz'),
          supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.go(location);
    await tester.pumpAndSettle();
  }

  /// Requests that would need a session.
  List<String> get privateRequests => [
    for (final r in adapter.requests)
      if (r.path.startsWith('me/') || r.path.startsWith('cart')) r.path,
  ];
}

/// The system back button (Android), as the engine sends it.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

/// Records `SystemNavigator.pop()` (the app leaving).
List<String> recordExits(WidgetTester tester) {
  final exits = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'SystemNavigator.pop') exits.add(call.method);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return exits;
}

void main() {
  test('the QR and cart tabs are public, their sub-pages are not', () {
    expect(isPublicLocation('/qr'), isTrue);
    expect(isPublicLocation('/cart'), isTrue);
    expect(isPublicLocation('/checkout'), isFalse);
    expect(isPublicLocation('/orders'), isFalse);
  });

  for (final (tab, signIn) in [
    ('/cart', 'cart.signIn'),
    ('/qr', 'qr.signIn'),
  ]) {
    testWidgets('a guest on $tab keeps the shell; "Kirish" pushes /auth', (
      tester,
    ) async {
      final app = _GuestApp();
      await app.pump(tester, tab);

      expect(app.path, tab);
      expect(bySemantics('tab.catalog'), findsOneWidget);
      await tapId(tester, signIn);
      expect(app.path, '/auth');
      expect(app.top.queryParameters['next'], tab);
      expect(find.text('Xush kelibsiz'), findsOneWidget);
      expect(bySemantics('tab.catalog'), findsNothing);

      // Closing returns to the tab, which is still there under it.
      await tapId(tester, 'auth.close');
      expect(app.path, tab);
      expect(bySemantics('tab.catalog'), findsOneWidget);
      expect(app.privateRequests, isEmpty);
    });
  }

  testWidgets('auth close goes to the catalog when nothing is under it', (
    tester,
  ) async {
    final app = _GuestApp();
    await app.pump(tester, '/auth');
    expect(find.text('Xush kelibsiz'), findsOneWidget);
    await tapId(tester, 'auth.close');
    expect(app.path, '/catalog');
    expect(bySemantics('home.search_open'), findsOneWidget);
  });

  testWidgets('the auth wordmark goes to the catalog', (tester) async {
    final app = _GuestApp();
    await app.pump(tester, '/auth?next=%2Fcart');
    await tapId(tester, 'wordmark');
    expect(app.path, '/catalog');
    expect(bySemantics('home.search_open'), findsOneWidget);
  });

  testWidgets('the home wordmark is a link to the catalog', (tester) async {
    final app = _GuestApp();
    await app.pump(tester, '/catalog');
    expect(bySemantics('wordmark'), findsOneWidget);
    await tapId(tester, 'wordmark');
    expect(app.path, '/catalog');
  });

  for (final tab in ['/qr', '/cart', '/settings']) {
    testWidgets('Android back on the $tab root opens the catalog tab', (
      tester,
    ) async {
      final app = _GuestApp();
      await app.pump(tester, tab);
      expect(app.path, tab);
      final exits = recordExits(tester);
      await systemBack(tester);
      expect(exits, isEmpty);
      expect(app.path, '/catalog');
      expect(bySemantics('home.search_open'), findsOneWidget);
    });
  }

  testWidgets('Android back on the catalog root leaves the app', (
    tester,
  ) async {
    final app = _GuestApp();
    await app.pump(tester, '/catalog');
    final exits = recordExits(tester);
    await systemBack(tester);
    expect(exits, ['SystemNavigator.pop']);
  });
}
