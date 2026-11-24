import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/app/providers.dart';
import 'package:glow_derma/app/theme/gd_theme.dart';
import 'package:glow_derma/core/i18n/tr.dart';
import 'package:glow_derma/core/network/api_exception.dart';
import 'package:glow_derma/core/network/json.dart';
import 'package:glow_derma/features/auth/application/session_controller.dart';
import 'package:glow_derma/features/auth/data/auth_api.dart';
import 'package:glow_derma/features/auth/data/auth_models.dart';
import 'package:glow_derma/features/auth/data/social_auth.dart';
import 'package:glow_derma/features/auth/presentation/auth_screens.dart';
import 'package:glow_derma/features/settings/data/public_settings.dart';
import 'package:go_router/go_router.dart';

/// `AuthTokens` of a successful sign-in.
Json tokens([String name = 'Malika']) => {
  'access': 'a',
  'refresh': 'r',
  'customer': {
    'id': 5,
    'name': name,
    'language': 'uz',
    'consent': {'update_required': false},
  },
};

const phoneIssue = CodeIssue(
  phoneMask: '+998 90 *** ** 67',
  expiresIn: 120,
  resendIn: 60,
  length: 6,
);

const emailIssue = CodeIssue(
  emailMask: 'm***@mail.uz',
  expiresIn: 120,
  resendIn: 60,
  length: 6,
);

ApiException validation(
  Map<String, String> fields, [
  Map<String, String>? codes,
]) => ApiException(
  status: 400,
  code: 'validation_error',
  message: 'Maydonlarni tekshiring.',
  fieldErrors: fields,
  fieldCodes: codes ?? {for (final k in fields.keys) k: 'invalid'},
);

ApiException apiError(
  int status,
  String code,
  String message, {
  Json? details,
}) => ApiException(
  status: status,
  code: code,
  message: message,
  details: details ?? const {},
);

/// Scripted [AuthApi]: every method answers from its queue (a value, or an
/// exception to throw) and logs a readable line in [calls].
class FakeAuthApi implements AuthApi {
  final calls = <String>[];
  final _queues = <String, List<Object>>{};

  /// Queues the next answer of [method].
  void answer(String method, Object result) =>
      (_queues[method] ??= []).add(result);

  T _next<T>(String method) {
    final queue = _queues[method];
    if (queue == null || queue.isEmpty) {
      throw StateError('FakeAuthApi: no answer for $method');
    }
    final result = queue.removeAt(0);
    if (result is Exception) throw result;
    if (result is Error) throw result;
    return result as T;
  }

  static String _id(AuthIdentifier id) =>
      '${id.isEmail ? 'email' : 'phone'}:${id.value}';

  @override
  Future<CodeIssue> sendCode(
    AuthIdentifier identifier,
    OtpPurpose purpose, {
    String? socialTicket,
  }) async {
    calls.add(
      'sendCode ${_id(identifier)} ${purpose.code}'
      '${socialTicket == null ? '' : ' ticket=$socialTicket'}',
    );
    return _next('sendCode');
  }

  @override
  Future<Verification> verifyCode(
    AuthIdentifier identifier,
    OtpPurpose purpose,
    String code, {
    OtpChannel? otpChannel,
  }) async {
    calls.add(
      'verifyCode ${_id(identifier)} ${purpose.code} $code'
      '${otpChannel == null ? '' : ' channel=${otpChannel.code}'}',
    );
    return _next('verifyCode');
  }

  @override
  Future<Json> register({
    required String verificationToken,
    required String name,
    required String password,
    required String termsVersion,
    required AppLanguage language,
  }) async {
    calls.add('register $verificationToken $name $password $termsVersion');
    return _next('register');
  }

  @override
  Future<LoginResult> login(
    AuthIdentifier identifier,
    String password, {
    String? verificationToken,
    OtpChannel? otpChannel,
  }) async {
    calls.add(
      'login ${_id(identifier)} $password'
      '${verificationToken == null ? '' : ' token=$verificationToken'}'
      '${otpChannel == null ? '' : ' channel=${otpChannel.code}'}',
    );
    return _next('login');
  }

  @override
  Future<Json> resetPassword(String verificationToken, String password) async {
    calls.add('resetPassword $verificationToken $password');
    return _next('resetPassword');
  }

  @override
  Future<String> socialNonce() async {
    calls.add('socialNonce');
    return _next('socialNonce');
  }

  @override
  Future<SocialResult> social({
    required SocialProvider provider,
    required String token,
    required String tokenType,
    String? nonce,
  }) async {
    calls.add('social ${provider.code} $token $tokenType nonce=$nonce');
    return _next('social');
  }

  @override
  Future<Json> socialComplete({
    required String socialTicket,
    String? verificationToken,
    String? password,
    String? name,
    String? termsVersion,
    required AppLanguage language,
  }) async {
    calls.add(
      'socialComplete $socialTicket token=$verificationToken '
      'password=$password name=$name terms=$termsVersion',
    );
    return _next('socialComplete');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// [SocialAuth] without SDKs: [configured] providers, scripted answers.
class FakeSocialAuth implements SocialAuth {
  FakeSocialAuth({
    this.configured = const {SocialProvider.google, SocialProvider.facebook},
  });

  @override
  final Set<SocialProvider> configured;
  final calls = <String>[];
  final answers = <SocialAuthResult>[];

  @override
  Future<SocialAuthResult> signIn(
    SocialProvider provider, {
    required String nonce,
  }) async {
    calls.add('${provider.code} nonce=$nonce');
    return answers.removeAt(0);
  }
}

class FakeLanguage extends LanguageController {
  @override
  AppLanguage build() => AppLanguage.uz;
}

/// Records the tokens the flow ends with.
class FakeSession extends SessionController {
  Json? signedInWith;

  @override
  AuthState build() => const AuthState(signedIn: false);

  @override
  Future<void> signedIn(Json tokens) async {
    signedInWith = tokens;
    state = const AuthState(signedIn: true);
  }
}

/// `GET settings/public/` answers: [versions] in turn (the last one repeats).
class FakeSettings {
  FakeSettings([this.versions = const ['2026-10']]);
  final List<String?> versions;
  int reads = 0;

  Future<PublicSettings> read() async {
    final v = versions[reads.clamp(0, versions.length - 1)];
    reads++;
    return PublicSettings({'terms_version': v});
  }
}

class AuthHarness {
  AuthHarness({FakeSocialAuth? social, FakeSettings? settings})
    : social = social ?? FakeSocialAuth(configured: const {}),
      settings = settings ?? FakeSettings();
  final api = FakeAuthApi();
  final FakeSocialAuth social;
  final FakeSettings settings;
  final session = FakeSession();

  List<Override> get overrides => [
    languageProvider.overrideWith(FakeLanguage.new),
    sessionProvider.overrideWith(() => session),
    authApiProvider.overrideWithValue(api),
    socialAuthProvider.overrideWithValue(social),
    publicSettingsProvider.overrideWith((ref) => settings.read()),
  ];

  /// The real auth routes from [location], with stub pages for the rest.
  Widget app(String location) {
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/auth',
          builder: (_, s) => AuthScreen(
            next: s.uri.queryParameters['next'],
            mode: AuthMode.fromQuery(s.uri.queryParameters['mode']),
          ),
        ),
        GoRoute(
          path: '/auth/otp',
          builder: (_, s) => OtpScreen(args: s.extra as OtpArgs?),
        ),
        GoRoute(
          path: '/auth/register',
          builder: (_, s) => RegisterScreen(args: s.extra as RegisterArgs?),
        ),
        GoRoute(
          path: '/auth/reset',
          builder: (_, s) =>
              ResetPasswordScreen(args: s.extra as RegisterArgs?),
        ),
        GoRoute(
          path: '/auth/social',
          builder: (_, s) => SocialCompleteScreen(args: s.extra as SocialArgs?),
        ),
        for (final p in ['/catalog', '/settings/legal/:doc'])
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
        theme: buildTheme(Brightness.light),
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

  Future<void> pump(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(location));
    await tester.pumpAndSettle();
  }
}

/// The widget carrying a semantics identifier (`Semantics(identifier: …)`).
Finder bySemantics(String id) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.identifier == id,
);

/// Types into the field wrapped by the semantics identifier [id].
Future<void> typeInto(WidgetTester tester, String id, String text) async {
  await tester.enterText(
    find.descendant(of: bySemantics(id), matching: find.byType(TextField)),
    text,
  );
  await tester.pumpAndSettle();
}

Future<void> tapId(WidgetTester tester, String id) async {
  final target = bySemantics(id);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// The text of the field wrapped by the semantics identifier [id].
String fieldText(WidgetTester tester, String id) => tester
    .widget<TextField>(
      find.descendant(of: bySemantics(id), matching: find.byType(TextField)),
    )
    .controller!
    .text;
