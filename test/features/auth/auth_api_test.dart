import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/core/device/device_identity.dart';
import 'package:glow_derma/core/i18n/tr.dart';
import 'package:glow_derma/core/network/api_client.dart';
import 'package:glow_derma/core/storage/secure_store.dart';
import 'package:glow_derma/features/auth/data/auth_api.dart';
import 'package:glow_derma/features/auth/data/auth_models.dart';

import '../../core/scripted_adapter.dart';

void main() {
  late ScriptedAdapter adapter;
  late AuthApi api;
  final answers = <String, Object>{};

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    answers.clear();
    adapter = ScriptedAdapter(
      (o) => ScriptedAdapter.json(200, answers[o.path] ?? <String, Object>{}),
    );
    api = AuthApi(
      ApiClient(
        device: DeviceIdentity(
          id: 'device0001',
          platform: 'android',
          appVersion: '1.0.0',
          model: 'Pixel',
          os: 'Android 15',
        ),
        tokens: TokenStore(secureStorage),
        language: () => AppLanguage.uz,
        baseUrl: 'https://api.test/api/v1/',
        adapter: adapter,
      ),
    );
  });

  Map<String, dynamic> body() =>
      Map<String, dynamic>.from(adapter.requests.last.data as Map);

  test(
    'send-code: exactly one identifier, the ticket only when given',
    () async {
      answers['auth/send-code/'] = {
        'phone_mask': null,
        'email_mask': 'm***@mail.uz',
        'resend_in': 60,
        'length': 6,
        'expires_in': 120,
      };
      final issue = await api.sendCode(
        const AuthIdentifier.email('malika@mail.uz'),
        OtpPurpose.register,
      );
      expect(body(), {'email': 'malika@mail.uz', 'purpose': 'register'});
      expect(issue.channel, OtpChannel.email);
      expect(issue.mask, 'm***@mail.uz');

      await api.sendCode(
        const AuthIdentifier.phone('+998901234567'),
        OtpPurpose.linkSocial,
        socialTicket: 't1',
      );
      expect(body(), {
        'phone': '+998901234567',
        'purpose': 'link_social',
        'social_ticket': 't1',
      });
    },
  );

  test(
    'verify-code: customer_exists, otp_channel only when switched',
    () async {
      answers['auth/verify-code/'] = {
        'verification_token': 'v1',
        'customer_exists': true,
        'expires_in': 600,
        'purpose': 'link_social',
      };
      final v = await api.verifyCode(
        const AuthIdentifier.phone('+998901234567'),
        OtpPurpose.linkSocial,
        '123456',
      );
      expect(v.token, 'v1');
      expect(v.customerExists, isTrue);
      expect(body().containsKey('otp_channel'), isFalse);

      await api.verifyCode(
        const AuthIdentifier.phone('+998901234567'),
        OtpPurpose.loginNewDevice,
        '123456',
        otpChannel: OtpChannel.email,
      );
      expect(body()['otp_channel'], 'email');
      expect(body()['phone'], '+998901234567');
    },
  );

  test('login: a NextStep with or without channels (older backend)', () async {
    answers['auth/login/'] = {
      'next_step': 'verify_device',
      'phone_mask': '+998 90 *** ** 67',
      'otp': {'resend_in': 45, 'length': 6, 'expires_in': 120},
    };
    final old = await api.login(
      const AuthIdentifier.phone('+998901234567'),
      'pw',
    );
    expect(old, isA<LoginNeedsCode>());
    old as LoginNeedsCode;
    expect(old.channels, isEmpty);
    expect(old.issue.resendIn, 45);
    expect(old.issue.channel, OtpChannel.sms);
    expect(body().containsKey('otp_channel'), isFalse);

    answers['auth/login/'] = {
      'next_step': 'verify_device',
      'phone_mask': null,
      'email_mask': 'm***@mail.uz',
      'otp': {'resend_in': 60, 'length': 6, 'expires_in': 120},
      'channels': [
        {'channel': 'sms', 'mask': '+998 90 *** ** 67'},
        {'channel': 'email', 'mask': 'm***@mail.uz'},
        {'channel': 'pigeon', 'mask': '?'},
      ],
    };
    final moved = await api.login(
      const AuthIdentifier.phone('+998901234567'),
      'pw',
      otpChannel: OtpChannel.email,
    );
    moved as LoginNeedsCode;
    expect(body()['otp_channel'], 'email');
    expect(moved.channels.map((c) => c.channel), [
      OtpChannel.sms,
      OtpChannel.email,
    ]);
    expect(moved.issue.channel, OtpChannel.email);
  });

  test('social: nonce, tokens or the verify_phone ticket', () async {
    answers['auth/social/nonce/'] = {'nonce': 'n1', 'expires_in': 600};
    expect(await api.socialNonce(), 'n1');

    answers['auth/social/'] = {
      'next_step': 'verify_phone',
      'social_ticket': 't1',
      'provider': 'google',
      'email_mask': 'm***@gmail.com',
      'expires_in': 600,
    };
    final result = await api.social(
      provider: SocialProvider.google,
      token: 'jwt',
      tokenType: 'id_token',
      nonce: 'n1',
    );
    expect(body(), {
      'provider': 'google',
      'token': 'jwt',
      'token_type': 'id_token',
      'nonce': 'n1',
    });
    expect((result as SocialNeedsCompletion).ticket, 't1');

    answers['auth/social/'] = {'access': 'a', 'refresh': 'r', 'customer': {}};
    expect(
      await api.social(
        provider: SocialProvider.facebook,
        token: 'fb',
        tokenType: 'access_token',
      ),
      isA<SocialSignedIn>(),
    );
  });
}
