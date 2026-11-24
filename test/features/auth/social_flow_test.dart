import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/features/auth/data/auth_models.dart';
import 'package:glow_derma/features/auth/data/social_auth.dart';

import 'fakes.dart';

const _google = SocialCredential(
  provider: SocialProvider.google,
  token: 'g-id-token',
  tokenType: 'id_token',
  nonce: 'n1',
);

SocialNeedsCompletion _ticket() => SocialNeedsCompletion(
  NextStep.fromJson({
    'next_step': 'verify_phone',
    'social_ticket': 't1',
    'provider': 'google',
    'email_mask': 'm***@gmail.com',
    'expires_in': 600,
  }),
);

/// Google sign-in up to the "Hisobingizni yakunlang" step.
Future<AuthHarness> _toCompletion(WidgetTester tester) async {
  final social = FakeSocialAuth()..answers.add(_google);
  final h = AuthHarness(social: social);
  h.api
    ..answer('socialNonce', 'n1')
    ..answer('social', _ticket());
  await h.pump(tester, '/auth');
  await tapId(tester, 'auth.social.google');
  expect(find.text('Hisobingizni yakunlang'), findsOneWidget);
  return h;
}

void main() {
  testWidgets('Google: nonce first, the ID token with it, then tokens', (
    tester,
  ) async {
    final social = FakeSocialAuth()..answers.add(_google);
    final h = AuthHarness(social: social);
    h.api
      ..answer('socialNonce', 'n1')
      ..answer('social', SocialSignedIn(tokens()));
    await h.pump(tester, '/auth');

    expect(find.text('YOKI'), findsOneWidget);
    expect(find.text('Google bilan davom etish'), findsOneWidget);
    expect(find.text('Facebook bilan davom etish'), findsOneWidget);
    await tapId(tester, 'auth.social.google');
    expect(social.calls, ['google nonce=n1']);
    expect(h.api.calls, [
      'socialNonce',
      'social google g-id-token id_token nonce=n1',
    ]);
    expect(h.session.signedInWith, isNotNull);
  });

  testWidgets('Google, verify_phone: continue for now with name and terms', (
    tester,
  ) async {
    final h = await _toCompletion(tester);
    h.api.answer('socialComplete', tokens());

    await tapId(tester, 'auth.social.skip');
    expect(
      find.text('Davom etish uchun shartlarni qabul qiling.'),
      findsOneWidget,
    );
    await typeInto(tester, 'auth.name', 'Malika');
    await tapId(tester, 'auth.consent');
    await tapId(tester, 'auth.social.skip');
    expect(
      h.api.calls.last,
      'socialComplete t1 token=null password=null name=Malika terms=2026-10',
    );
    expect(h.session.signedInWith, isNotNull);
  });

  testWidgets('link a new phone (customer_exists=false): name and terms', (
    tester,
  ) async {
    final h = await _toCompletion(tester);
    h.api
      ..answer('sendCode', phoneIssue)
      ..answer(
        'verifyCode',
        const Verification(token: 'l1', customerExists: false),
      )
      ..answer('socialComplete', tokens());

    await tapId(tester, 'auth.social.link');
    await typeInto(tester, 'auth.phone', '901234567');
    await tapId(tester, 'auth.getCode');
    expect(
      h.api.calls.last,
      'sendCode phone:+998901234567 link_social ticket=t1',
    );
    await typeInto(tester, 'auth.otp', '123456');
    expect(
      h.api.calls.last,
      'verifyCode phone:+998901234567 link_social 123456',
    );

    expect(find.text('Hisobingizni yakunlang'), findsOneWidget);
    await typeInto(tester, 'auth.name', 'Malika');
    await tapId(tester, 'auth.consent');
    await tapId(tester, 'auth.register');
    expect(
      h.api.calls.last,
      'socialComplete t1 token=l1 password=null name=Malika terms=2026-10',
    );
    expect(h.session.signedInWith, isNotNull);
  });

  testWidgets('link an existing account without a password: linked at once', (
    tester,
  ) async {
    final h = await _toCompletion(tester);
    h.api
      ..answer('sendCode', emailIssue)
      ..answer(
        'verifyCode',
        const Verification(token: 'l2', customerExists: true),
      )
      ..answer('socialComplete', tokens());

    await tapId(tester, 'auth.social.link');
    await tapId(tester, 'auth.channel.email');
    await typeInto(tester, 'auth.email', 'malika@mail.uz');
    await tapId(tester, 'auth.getCode');
    await typeInto(tester, 'auth.otp', '123456');
    expect(
      h.api.calls.last,
      'socialComplete t1 token=l2 password=null name=null terms=null',
    );
    expect(h.session.signedInWith, isNotNull);
  });

  testWidgets('link an existing account with a password: asked, then retried', (
    tester,
  ) async {
    final h = await _toCompletion(tester);
    h.api
      ..answer('sendCode', phoneIssue)
      ..answer(
        'verifyCode',
        const Verification(token: 'l3', customerExists: true),
      )
      ..answer(
        'socialComplete',
        validation(
          {'password': 'Maydonni to‘ldiring.'},
          {'password': 'required'},
        ),
      )
      ..answer(
        'socialComplete',
        validation(
          {'password': 'Parol noto‘g‘ri.'},
          {'password': 'password_incorrect'},
        ),
      )
      ..answer('socialComplete', tokens());

    await tapId(tester, 'auth.social.link');
    await typeInto(tester, 'auth.phone', '901234567');
    await tapId(tester, 'auth.getCode');
    await typeInto(tester, 'auth.otp', '123456');

    expect(
      find.text(
        'Bu raqam bilan hisob bor. Bog‘lash uchun uning parolini kiriting.',
      ),
      findsOneWidget,
    );
    expect(h.session.signedInWith, isNull);
    await typeInto(tester, 'auth.password', 'wrong-one');
    await tapId(tester, 'auth.confirm');
    expect(find.text('Parol noto‘g‘ri.'), findsOneWidget);

    await typeInto(tester, 'auth.password', 'Glowderma-2026');
    await tapId(tester, 'auth.confirm');
    expect(
      h.api.calls.last,
      'socialComplete t1 token=l3 password=Glowderma-2026 name=null terms=null',
    );
    expect(h.session.signedInWith, isNotNull);
  });

  testWidgets('Facebook cancelled: nothing is said, nothing is sent', (
    tester,
  ) async {
    final social = FakeSocialAuth()..answers.add(const SocialCancelled());
    final h = AuthHarness(social: social);
    h.api.answer('socialNonce', 'n2');
    await h.pump(tester, '/auth');
    await tapId(tester, 'auth.social.facebook');
    expect(social.calls, ['facebook nonce=n2']);
    expect(h.api.calls, ['socialNonce']);
    expect(bySemantics('auth.message'), findsNothing);
    expect(find.text('Facebook bilan davom etish'), findsOneWidget);
  });

  testWidgets('a provider SDK failure shows the generic message', (
    tester,
  ) async {
    final social = _ThrowingSocialAuth();
    final h = AuthHarness(social: social);
    h.api.answer('socialNonce', 'n3');
    await h.pump(tester, '/auth');
    await tapId(tester, 'auth.social.google');
    expect(
      find.text('Kirish amalga oshmadi. Qayta urinib ko‘ring.'),
      findsOneWidget,
    );
  });

  testWidgets('404 from auth/social/: the provider is hidden', (tester) async {
    final social = FakeSocialAuth()..answers.add(_google);
    final h = AuthHarness(social: social);
    h.api
      ..answer('socialNonce', 'n1')
      ..answer('social', apiError(404, 'not_found', 'Topilmadi.'));
    await h.pump(tester, '/auth');
    await tapId(tester, 'auth.social.google');
    expect(find.text('Google bilan davom etish'), findsNothing);
    expect(find.text('Facebook bilan davom etish'), findsOneWidget);
  });

  testWidgets('no ids in the build: no social buttons', (tester) async {
    final h = AuthHarness(social: null);
    await h.pump(tester, '/auth');
    expect(find.text('Google bilan davom etish'), findsNothing);
    expect(find.text('YOKI'), findsNothing);
    // The real service without defines offers nothing either.
    expect(const PluginSocialAuth().configured, isEmpty);
  });

  testWidgets('sign-up and reset modes never show the consent; only details', (
    tester,
  ) async {
    final h = AuthHarness();
    await h.pump(tester, '/auth?mode=signup');
    expect(bySemantics('auth.consent'), findsNothing);
    await tapId(tester, 'auth.mode.signin');
    expect(bySemantics('auth.consent'), findsNothing);
    await tapId(tester, 'auth.forgot');
    expect(bySemantics('auth.consent'), findsNothing);
  });
}

class _ThrowingSocialAuth extends FakeSocialAuth {
  @override
  Future<SocialAuthResult> signIn(
    SocialProvider provider, {
    required String nonce,
  }) async => throw const SocialAuthException('google: developer error');
}
