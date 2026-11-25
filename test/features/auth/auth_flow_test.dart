import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/features/auth/data/auth_models.dart';

import 'fakes.dart';

void main() {
  group('sign-up', () {
    testWidgets('by phone: code, details with the consent, set-password', (
      tester,
    ) async {
      final h = AuthHarness();
      h.api
        ..answer('sendCode', phoneIssue)
        ..answer(
          'verifyCode',
          const Verification(token: 'v1', customerExists: false),
        )
        ..answer('register', tokens());
      await h.pump(tester, '/auth?mode=signup');

      expect(find.text('Hisob yaratish'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing); // no consent on the entry
      await typeInto(tester, 'auth.phone', '901234567');
      await tapId(tester, 'auth.getCode');
      expect(h.api.calls, ['sendCode phone:+998901234567 register']);
      expect(
        find.text(
          'SMS orqali +998 90 *** ** 67 raqamiga 6 xonali kod yubordik.',
        ),
        findsOneWidget,
      );

      await typeInto(tester, 'auth.otp', '123456');
      expect(
        h.api.calls.last,
        'verifyCode phone:+998901234567 register 123456',
      );
      expect(find.text('Hisob ma’lumotlari'), findsOneWidget);

      await typeInto(tester, 'auth.name', 'Malika');
      await typeInto(tester, 'auth.newPassword', 'Glowderma-2026');
      await tapId(tester, 'auth.register');
      expect(
        find.text('Davom etish uchun shartlarni qabul qiling.'),
        findsOneWidget,
      );
      expect(h.api.calls.where((c) => c.startsWith('register')), isEmpty);

      await tapId(tester, 'auth.consent');
      await tapId(tester, 'auth.register');
      expect(h.api.calls.last, 'register v1 Malika Glowderma-2026 2026-10');
      expect(h.session.signedInWith, isNotNull);
    });

    testWidgets('by e-mail: trimmed, lower-cased, e-mail code text', (
      tester,
    ) async {
      final h = AuthHarness();
      h.api
        ..answer('sendCode', emailIssue)
        ..answer(
          'verifyCode',
          const Verification(token: 'v2', customerExists: false),
        )
        ..answer('register', tokens());
      await h.pump(tester, '/auth');

      await tapId(tester, 'auth.mode.signup');
      await tapId(tester, 'auth.channel.email');
      await typeInto(tester, 'auth.email', 'Malika@Mail.UZ');
      await tapId(tester, 'auth.getCode');
      expect(h.api.calls, ['sendCode email:malika@mail.uz register']);
      expect(
        find.textContaining('m***@mail.uz e-mail manziliga 6 xonali kod'),
        findsOneWidget,
      );
      expect(find.text('E-mailni o‘zgartirish'), findsOneWidget);

      await typeInto(tester, 'auth.otp', '654321');
      await typeInto(tester, 'auth.name', 'Malika');
      await typeInto(tester, 'auth.newPassword', 'Glowderma-2026');
      await tapId(tester, 'auth.consent');
      await tapId(tester, 'auth.register');
      expect(h.api.calls, [
        'sendCode email:malika@mail.uz register',
        'verifyCode email:malika@mail.uz register 654321',
        'register v2 Malika Glowderma-2026 2026-10',
      ]);
      expect(h.session.signedInWith, isNotNull);
    });

    testWidgets('an invalid e-mail never reaches the server', (tester) async {
      final h = AuthHarness();
      await h.pump(tester, '/auth?mode=signup');
      await tapId(tester, 'auth.channel.email');
      await typeInto(tester, 'auth.email', 'malika@mail');
      await tapId(tester, 'auth.getCode');
      expect(find.text('E-mail manzilini to‘g‘ri kiriting.'), findsOneWidget);
      expect(h.api.calls, isEmpty);
    });

    testWidgets('409 phone_registered offers sign-in, the number is kept', (
      tester,
    ) async {
      final h = AuthHarness();
      h.api.answer(
        'sendCode',
        apiError(
          409,
          'phone_registered',
          'Bu raqam ro‘yxatdan o‘tgan. Hisobingizga kiring.',
        ),
      );
      await h.pump(tester, '/auth?mode=signup');
      await typeInto(tester, 'auth.phone', '901234567');
      await tapId(tester, 'auth.getCode');

      expect(
        find.text('Bu raqam ro‘yxatdan o‘tgan. Hisobingizga kiring.'),
        findsOneWidget,
      );
      await tapId(tester, 'auth.message.action');
      expect(bySemantics('auth.password'), findsOneWidget);
      expect(find.text('Xush kelibsiz'), findsOneWidget);
      expect(fieldText(tester, 'auth.phone'), '90 123 45 67');
    });

    testWidgets('409 email_registered keeps the address too', (tester) async {
      final h = AuthHarness();
      h.api.answer(
        'sendCode',
        apiError(
          409,
          'email_registered',
          'Bu email ro‘yxatdan o‘tgan. Hisobingizga kiring.',
        ),
      );
      await h.pump(tester, '/auth?mode=signup');
      await tapId(tester, 'auth.channel.email');
      await typeInto(tester, 'auth.email', 'malika@mail.uz');
      await tapId(tester, 'auth.getCode');
      await tapId(tester, 'auth.message.action');
      expect(bySemantics('auth.password'), findsOneWidget);
      expect(fieldText(tester, 'auth.email'), 'malika@mail.uz');
    });
  });

  group('sign-in', () {
    testWidgets('by e-mail on a known device: tokens at once', (tester) async {
      final h = AuthHarness();
      h.api.answer('login', LoginSignedIn(tokens()));
      await h.pump(tester, '/auth');
      expect(find.byType(Checkbox), findsNothing); // no consent to sign in

      await tapId(tester, 'auth.channel.email');
      await typeInto(tester, 'auth.email', 'malika@mail.uz');
      await typeInto(tester, 'auth.password', 'Glowderma-2026');
      await tapId(tester, 'auth.signIn');
      expect(h.api.calls, ['login email:malika@mail.uz Glowderma-2026']);
      expect(h.session.signedInWith, isNotNull);
    });

    testWidgets('invalid_credentials stays inline', (tester) async {
      final h = AuthHarness();
      h.api.answer(
        'login',
        apiError(
          401,
          'invalid_credentials',
          'Telefon raqami, email yoki parol noto‘g‘ri.',
        ),
      );
      await h.pump(tester, '/auth');
      await typeInto(tester, 'auth.phone', '901234567');
      await typeInto(tester, 'auth.password', 'wrong-one');
      await tapId(tester, 'auth.signIn');
      expect(
        find.text('Telefon raqami, email yoki parol noto‘g‘ri.'),
        findsOneWidget,
      );
      expect(h.session.signedInWith, isNull);
    });

    testWidgets('by phone on a new device: code, then login with the token; no '
        'channel switch without channels', (tester) async {
      final h = AuthHarness();
      h.api
        ..answer(
          'login',
          LoginNeedsCode(
            NextStep.fromJson({
              'next_step': 'verify_device',
              'phone_mask': '+998 90 *** ** 67',
              'otp': {'resend_in': 60, 'length': 6, 'expires_in': 120},
            }),
          ),
        )
        ..answer(
          'verifyCode',
          const Verification(token: 'd1', customerExists: true),
        )
        ..answer('login', LoginSignedIn(tokens()));
      await h.pump(tester, '/auth');
      await typeInto(tester, 'auth.phone', '901234567');
      await typeInto(tester, 'auth.password', 'Glowderma-2026');
      await tapId(tester, 'auth.signIn');

      expect(find.text('Yangi qurilmadan kirish'), findsOneWidget);
      expect(bySemantics('auth.otp.otherChannel'), findsNothing);
      await typeInto(tester, 'auth.otp', '111222');
      expect(h.api.calls, [
        'login phone:+998901234567 Glowderma-2026',
        'verifyCode phone:+998901234567 login_new_device 111222',
        'login phone:+998901234567 Glowderma-2026 token=d1',
      ]);
      expect(h.session.signedInWith, isNotNull);
    });

    testWidgets('two channels: the code moves to the e-mail (otp_channel)', (
      tester,
    ) async {
      final h = AuthHarness();
      final channels = [
        {'channel': 'sms', 'mask': '+998 90 *** ** 67'},
        {'channel': 'email', 'mask': 'm***@mail.uz'},
      ];
      h.api
        ..answer(
          'login',
          LoginNeedsCode(
            NextStep.fromJson({
              'next_step': 'verify_device',
              'phone_mask': '+998 90 *** ** 67',
              'email_mask': null,
              'otp': {'resend_in': 60, 'length': 6, 'expires_in': 120},
              'channels': channels,
            }),
          ),
        )
        ..answer(
          'login',
          LoginNeedsCode(
            NextStep.fromJson({
              'next_step': 'verify_device',
              'phone_mask': null,
              'email_mask': 'm***@mail.uz',
              'otp': {'resend_in': 60, 'length': 6, 'expires_in': 120},
              'channels': channels,
            }),
          ),
        )
        ..answer(
          'verifyCode',
          const Verification(token: 'd2', customerExists: true),
        )
        ..answer('login', LoginSignedIn(tokens()));
      await h.pump(tester, '/auth');
      await typeInto(tester, 'auth.phone', '901234567');
      await typeInto(tester, 'auth.password', 'Glowderma-2026');
      await tapId(tester, 'auth.signIn');

      expect(
        find.textContaining('SMS orqali +998 90 *** ** 67'),
        findsOneWidget,
      );
      expect(find.text('Kodni e-mailga yuborish'), findsOneWidget);
      await tapId(tester, 'auth.otp.otherChannel');
      expect(
        h.api.calls.last,
        'login phone:+998901234567 Glowderma-2026 channel=email',
      );
      expect(
        find.textContaining('m***@mail.uz e-mail manziliga'),
        findsOneWidget,
      );
      expect(find.text('SMS orqali yuborish'), findsOneWidget);

      await typeInto(tester, 'auth.otp', '333444');
      expect(h.api.calls.sublist(2), [
        'verifyCode phone:+998901234567 login_new_device 333444 channel=email',
        'login phone:+998901234567 Glowderma-2026 token=d2 channel=email',
      ]);
      expect(h.session.signedInWith, isNotNull);
    });

    testWidgets('otp_invalid shows the attempts left', (tester) async {
      final h = AuthHarness();
      h.api
        ..answer('sendCode', phoneIssue)
        ..answer(
          'verifyCode',
          apiError(
            400,
            'otp_invalid',
            'Kod noto‘g‘ri. Yana 2 marta urinishingiz mumkin.',
            details: {'attempts_left': 2},
          ),
        );
      await h.pump(tester, '/auth?mode=signup');
      await typeInto(tester, 'auth.phone', '901234567');
      await tapId(tester, 'auth.getCode');
      await typeInto(tester, 'auth.otp', '000000');
      expect(
        find.text('Kod noto‘g‘ri. Yana 2 marta urinishingiz mumkin.'),
        findsOneWidget,
      );
      expect(find.text('Qolgan urinishlar: 2'), findsOneWidget);
    });
  });

  group('forgot password', () {
    testWidgets('by e-mail: the address is kept, code, new password', (
      tester,
    ) async {
      final h = AuthHarness();
      h.api
        ..answer('sendCode', emailIssue)
        ..answer(
          'verifyCode',
          const Verification(token: 'r1', customerExists: true),
        )
        ..answer('resetPassword', tokens());
      await h.pump(tester, '/auth');
      await tapId(tester, 'auth.channel.email');
      await typeInto(tester, 'auth.email', 'malika@mail.uz');
      await tapId(tester, 'auth.forgot');

      expect(find.text('Parolni tiklash'), findsOneWidget);
      expect(fieldText(tester, 'auth.email'), 'malika@mail.uz');
      expect(bySemantics('auth.password'), findsNothing);
      await tapId(tester, 'auth.getCode');
      expect(h.api.calls, ['sendCode email:malika@mail.uz reset_password']);

      await typeInto(tester, 'auth.otp', '777888');
      expect(find.text('Yangi parol'), findsWidgets);
      await typeInto(tester, 'auth.newPassword', 'Glowderma-2027');
      await typeInto(tester, 'auth.newPasswordRepeat', 'Glowderma-2028');
      await tapId(tester, 'auth.savePassword');
      expect(find.text('Parollar mos kelmadi.'), findsOneWidget);
      expect(h.api.calls.where((c) => c.startsWith('reset')), isEmpty);

      await typeInto(tester, 'auth.newPasswordRepeat', 'Glowderma-2027');
      await tapId(tester, 'auth.savePassword');
      expect(h.api.calls.last, 'resetPassword r1 Glowderma-2027');
      expect(h.session.signedInWith, isNotNull);
    });

    testWidgets('password_unchanged stays on the field', (tester) async {
      final h = AuthHarness();
      h.api
        ..answer('sendCode', phoneIssue)
        ..answer(
          'verifyCode',
          const Verification(token: 'r2', customerExists: true),
        )
        ..answer(
          'resetPassword',
          validation(
            {'password': 'Yangi parol eskisidan farq qilsin.'},
            {'password': 'password_unchanged'},
          ),
        );
      await h.pump(tester, '/auth?mode=reset');
      await typeInto(tester, 'auth.phone', '901234567');
      await tapId(tester, 'auth.getCode');
      await typeInto(tester, 'auth.otp', '777888');
      await typeInto(tester, 'auth.newPassword', 'Glowderma-2026');
      await typeInto(tester, 'auth.newPasswordRepeat', 'Glowderma-2026');
      await tapId(tester, 'auth.savePassword');
      expect(find.text('Yangi parol eskisidan farq qilsin.'), findsOneWidget);
      expect(h.session.signedInWith, isNull);
    });

    testWidgets('409 email_not_registered offers sign-up', (tester) async {
      final h = AuthHarness();
      h.api.answer(
        'sendCode',
        apiError(
          409,
          'email_not_registered',
          'Bu email bilan hisob topilmadi. Ro‘yxatdan o‘ting.',
        ),
      );
      await h.pump(tester, '/auth?mode=reset');
      await tapId(tester, 'auth.channel.email');
      await typeInto(tester, 'auth.email', 'new@mail.uz');
      await tapId(tester, 'auth.getCode');
      expect(
        find.text('Bu email bilan hisob topilmadi. Ro‘yxatdan o‘ting.'),
        findsOneWidget,
      );
      await tapId(tester, 'auth.message.action');
      expect(find.text('Hisob yaratish'), findsOneWidget);
      expect(fieldText(tester, 'auth.email'), 'new@mail.uz');
    });
  });

  group('details step', () {
    Future<void> toDetails(WidgetTester tester, AuthHarness h) async {
      h.api
        ..answer('sendCode', phoneIssue)
        ..answer(
          'verifyCode',
          const Verification(token: 'v1', customerExists: false),
        );
      await h.pump(tester, '/auth?mode=signup');
      await typeInto(tester, 'auth.phone', '901234567');
      await tapId(tester, 'auth.getCode');
      await typeInto(tester, 'auth.otp', '123456');
      await typeInto(tester, 'auth.name', 'M');
      await typeInto(tester, 'auth.newPassword', '12345678');
      await tapId(tester, 'auth.consent');
    }

    testWidgets('every field error is shown, unknown fields included', (
      tester,
    ) async {
      final h = AuthHarness();
      await toDetails(tester, h);
      h.api.answer(
        'register',
        validation({
          'name': 'Ismingizni kiriting (kamida 2 belgi).',
          'password': 'Parol faqat raqamlardan iborat bo‘lmasin.',
          'language': 'Noto‘g‘ri qiymat.',
        }),
      );
      await tapId(tester, 'auth.register');
      expect(
        find.text('Ismingizni kiriting (kamida 2 belgi).'),
        findsOneWidget,
      );
      expect(
        find.text('Parol faqat raqamlardan iborat bo‘lmasin.'),
        findsOneWidget,
      );
      expect(find.text('Noto‘g‘ri qiymat.'), findsOneWidget);
    });

    testWidgets('a non-field error is shown as a message', (tester) async {
      final h = AuthHarness();
      await toDetails(tester, h);
      h.api.answer(
        'register',
        apiError(
          503,
          'terms_not_published',
          'Ro‘yxatdan o‘tish vaqtincha mavjud emas.',
        ),
      );
      await tapId(tester, 'auth.register');
      expect(
        find.text('Ro‘yxatdan o‘tish vaqtincha mavjud emas.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'terms_outdated: shown on the consent, settings re-read, the next tap '
      'sends the new version',
      (tester) async {
        final settings = FakeSettings(['2026-10', '2026-11']);
        final h = AuthHarness(settings: settings);
        await toDetails(tester, h);
        h.api
          ..answer(
            'register',
            validation(
              {
                'terms_version':
                    'Foydalanish shartlarining yangi tahririni qabul qiling.',
              },
              {'terms_version': 'terms_outdated'},
            ),
          )
          ..answer('register', tokens());
        final before = settings.reads;
        await tapId(tester, 'auth.register');

        expect(h.api.calls.last, 'register v1 M 12345678 2026-10');
        expect(
          find.textContaining(
            'Foydalanish shartlarining yangi tahririni qabul qiling.',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Shartlar yangilandi. Ularni qabul qilib'),
          findsOneWidget,
        );
        // Read before set-password and again after the refusal.
        expect(settings.reads, before + 2);
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);

        await tapId(tester, 'auth.consent');
        await tapId(tester, 'auth.register');
        expect(h.api.calls.last, 'register v1 M 12345678 2026-11');
        expect(h.session.signedInWith, isNotNull);
      },
    );
  });
}
