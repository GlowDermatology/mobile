import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/app/providers.dart';
import 'package:glow_derma/app/theme/gd_theme.dart';
import 'package:glow_derma/core/i18n/tr.dart';
import 'package:glow_derma/features/auth/application/session_controller.dart';
import 'package:glow_derma/features/auth/data/auth_models.dart';
import 'package:glow_derma/features/profile/application/profile_providers.dart';
import 'package:glow_derma/features/profile/data/addresses_api.dart';
import 'package:glow_derma/features/profile/presentation/addresses_screen.dart';
import 'package:glow_derma/features/profile/presentation/legal_screen.dart';
import 'package:glow_derma/features/profile/presentation/sessions_screen.dart';
import 'package:glow_derma/features/profile/presentation/settings_screen.dart';
import 'package:glow_derma/features/settings/data/public_settings.dart';
import 'package:go_router/go_router.dart';

final malika = Me.fromJson({
  'id': 5,
  'phone': '+998901234567',
  'name': 'Malika Karimova',
  'language': 'uz',
  'has_password': true,
  'consent': {'update_required': false},
});

class FakeLanguage extends LanguageController {
  @override
  AppLanguage build() => AppLanguage.uz;
}

class FakeTheme extends ThemeModeController {
  @override
  ThemeMode build() => ThemeMode.light;
  @override
  Future<void> set(ThemeMode mode) async => state = mode;
}

class FakeSession extends SessionController {
  FakeSession(this.initial);
  final AuthState initial;
  @override
  AuthState build() => initial;
}

const settingsJson = {
  'telegram_url': 'https://t.me/glowderma',
  'instagram_url': null,
  'website_url': 'https://glowderma.uz',
  'store_phone': '+998712000001',
  'privacy_policy': 'Maxfiylik matni',
  'terms': '',
  'booking_policy': 'Qoidalar',
};

List<Override> overrides({required bool signedIn}) => [
  languageProvider.overrideWith(FakeLanguage.new),
  themeModeProvider.overrideWith(FakeTheme.new),
  sessionProvider.overrideWith(
    () => FakeSession(
      AuthState(signedIn: signedIn, me: signedIn ? malika : null),
    ),
  ),
  publicSettingsProvider.overrideWith(
    (ref) async => const PublicSettings(settingsJson),
  ),
  appVersionProvider.overrideWithValue('1.0.0'),
  ordersCountProvider.overrideWith((ref) async => signedIn ? 12 : null),
  upcomingAppointmentsCountProvider.overrideWith(
    (ref) async => signedIn ? 1 : null,
  ),
];

Widget app(
  Widget home,
  List<Override> overrides, {
  Brightness brightness = Brightness.light,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      GoRoute(
        path: '/auth',
        builder: (_, s) => Scaffold(body: Text('page ${s.uri}')),
      ),
      for (final p in [
        '/orders',
        '/appointments',
        '/specialists',
        '/settings/addresses',
        '/settings/legal/:doc',
        '/settings/sessions',
        '/settings/password',
        '/settings/delete',
        '/catalog',
        '/checkout/address',
      ])
        GoRoute(
          path: p,
          builder: (_, s) => Scaffold(body: Text('page ${s.uri}')),
        ),
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: router,
      theme: buildTheme(brightness),
      locale: const Locale('uz'),
      supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('signed in: profile card, counts and account rows', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(
      app(const SettingsScreen(), overrides(signedIn: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sozlamalar'), findsOneWidget);
    expect(find.text('MK'), findsOneWidget);
    expect(find.text('Malika Karimova'), findsOneWidget);
    expect(find.text('+998 90 123 45 67'), findsOneWidget);
    expect(find.text('Buyurtmalar tarixi'), findsOneWidget);
    expect(find.text('12 ta'), findsOneWidget);
    expect(find.text('Mening qabullarim'), findsOneWidget);
    expect(find.text('1 ta'), findsOneWidget);
    expect(find.text('Manzillarim'), findsOneWidget);
    expect(find.text('Mutaxassislar'), findsOneWidget);
    expect(find.text('O‘zbekcha'), findsOneWidget);
    expect(find.text('Faol seanslar'), findsOneWidget);
    expect(find.text('Parolni o‘zgartirish'), findsOneWidget);
    expect(find.text('Hisobni o‘chirish'), findsOneWidget);
    expect(find.text('Chiqish'), findsOneWidget);
    expect(find.text('Kirish yoki ro‘yxatdan o‘tish'), findsNothing);
    // Instagram is not configured: its tile is hidden.
    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('Instagram'), findsNothing);
    expect(find.text('Veb-sayt'), findsOneWidget);
    expect(find.text('Telefon'), findsOneWidget);
    expect(find.text('Glow Derma · 1.0.0'), findsOneWidget);

    await tester.tap(find.text('Buyurtmalar tarixi'));
    await tester.pumpAndSettle();
    expect(find.text('page /orders'), findsOneWidget);
  });

  testWidgets('guest: sign-in card, only public rows', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      app(const SettingsScreen(), overrides(signedIn: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kirish yoki ro‘yxatdan o‘tish'), findsOneWidget);
    expect(find.text('Mutaxassislar'), findsOneWidget);
    expect(find.text('Til'), findsOneWidget);
    expect(find.text('Maxfiylik siyosati'), findsOneWidget);
    expect(find.text('Qabul qoidalari'), findsOneWidget);
    for (final hidden in [
      'Buyurtmalar tarixi',
      'Mening qabullarim',
      'Manzillarim',
      'Faol seanslar',
      'Parolni o‘zgartirish',
      'Hisobni o‘chirish',
      'Chiqish',
    ]) {
      expect(find.text(hidden), findsNothing, reason: hidden);
    }

    await tester.tap(find.text('Kirish yoki ro‘yxatdan o‘tish'));
    await tester.pumpAndSettle();
    expect(find.text('page /auth?next=%2Fsettings'), findsOneWidget);
  });

  testWidgets('theme segment switches the theme mode', (tester) async {
    tall(tester);
    final container = ProviderContainer(overrides: overrides(signedIn: false));
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: app(const SettingsScreen(), const []),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), ThemeMode.light);
    await tester.tap(find.text('Qorong‘i'));
    await tester.pump();
    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  testWidgets('renders in the dark theme', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      app(
        const SettingsScreen(),
        overrides(signedIn: true),
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Malika Karimova'), findsOneWidget);
  });

  testWidgets('legal screen shows the text, or an empty state', (tester) async {
    await tester.pumpWidget(
      app(const LegalScreen(doc: 'privacy'), overrides(signedIn: false)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Maxfiylik siyosati'), findsOneWidget);
    expect(find.text('Maxfiylik matni'), findsOneWidget);

    await tester.pumpWidget(
      app(const LegalScreen(doc: 'terms'), overrides(signedIn: false)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Foydalanish shartlari'), findsOneWidget);
    expect(find.text('Matn hali qo‘shilmagan'), findsOneWidget);
  });

  testWidgets('sessions: current badge and revoke-others button', (
    tester,
  ) async {
    CustomerSession s(String id, String device, bool current) =>
        CustomerSession.fromJson({
          'id': id,
          'device': device,
          'platform': current ? 'android' : 'web',
          'location': current ? '—' : 'Tashkent, Tashkent, UZ',
          'created_at': '2026-10-27T10:12:00+05:00',
          'updated_at': '2026-10-27T18:40:00+05:00',
          'current': current,
        });
    await tester.pumpWidget(
      app(const SessionsScreen(), [
        ...overrides(signedIn: true),
        customerSessionsProvider.overrideWith(
          (ref) async => [
            s('a', 'Glow Derma Android', true),
            s('b', 'Chrome (Windows)', false),
          ],
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Glow Derma Android'), findsOneWidget);
    expect(find.text('Chrome (Windows)'), findsOneWidget);
    expect(find.text('Joriy'), findsOneWidget);
    expect(find.text('Tashkent, Tashkent, UZ'), findsOneWidget);
    expect(find.text('Yangilangan: 27-oktabr, 18:40'), findsNWidgets(2));
    expect(find.text('Boshqa qurilmalardan chiqish'), findsOneWidget);
  });

  testWidgets('addresses: default badge and menu actions', (tester) async {
    Address a(int id, String label, bool isDefault) => Address.fromJson({
      'id': id,
      'label': label,
      'text': 'Chilonzor 12',
      'region_code': '',
      'city_code': '',
      'comment': '',
      'is_default': isDefault,
    });
    await tester.pumpWidget(
      app(const AddressesScreen(), [
        ...overrides(signedIn: true),
        addressesProvider.overrideWith(
          (ref) async => [a(1, 'Ish', false), a(2, 'Uy', true)],
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Asosiy'), findsOneWidget);
    expect(find.text('Uy'), findsOneWidget);
    expect(find.text('Yangi manzil'), findsOneWidget);
    // The default address is listed first.
    expect(
      tester.getTopLeft(find.text('Uy')).dy,
      lessThan(tester.getTopLeft(find.text('Ish')).dy),
    );

    await tester.tap(find.byIcon(Icons.more_vert_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('Asosiy manzil qilish'), findsOneWidget);
    expect(find.text('O‘chirish'), findsOneWidget);
  });
}
