import '../../../core/i18n/tr.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import 'auth_models.dart';

/// `auth/*` endpoints (contract §2.1) and `me/` (§2.2).
class AuthApi {
  AuthApi(this._api);
  final ApiClient _api;

  /// `auth/send-code/` for `register`, `reset_password` or `link_social`
  /// (with the [socialTicket]); the code goes by SMS or e-mail, following the
  /// identifier.
  Future<CodeIssue> sendCode(
    AuthIdentifier identifier,
    OtpPurpose purpose, {
    String? socialTicket,
  }) async => CodeIssue.fromJson(
    asJson(
      await _api.post(
        'auth/send-code/',
        body: {
          ...identifier.body,
          'purpose': purpose.code,
          'social_ticket': ?socialTicket,
        },
      ),
    ),
  );

  /// `auth/verify-code/`. [otpChannel] names where a new-device code was
  /// re-sent ("Kodni e-mailga yuborish"); the identifier stays the one typed.
  Future<Verification> verifyCode(
    AuthIdentifier identifier,
    OtpPurpose purpose,
    String code, {
    OtpChannel? otpChannel,
  }) async => Verification.fromJson(
    asJson(
      await _api.post(
        'auth/verify-code/',
        body: {
          ...identifier.body,
          'purpose': purpose.code,
          'code': code,
          'otp_channel': ?otpChannel?.code,
        },
      ),
    ),
  );

  Future<Json> register({
    required String verificationToken,
    required String name,
    required String password,
    required String termsVersion,
    required AppLanguage language,
  }) async => asJson(
    await _api.post(
      'auth/set-password/',
      body: {
        'verification_token': verificationToken,
        'name': name,
        'password': password,
        'terms_version': termsVersion,
        'language': language.code,
      },
    ),
  );

  /// `auth/login/`. Without a token on a new device the server sends a code
  /// ([LoginNeedsCode]); [otpChannel] asks for it on the account's other
  /// verified identifier (newer backends).
  Future<LoginResult> login(
    AuthIdentifier identifier,
    String password, {
    String? verificationToken,
    OtpChannel? otpChannel,
  }) async {
    final j = asJson(
      await _api.post(
        'auth/login/',
        body: {
          ...identifier.body,
          'password': password,
          'verification_token': verificationToken,
          'otp_channel': ?otpChannel?.code,
        },
      ),
    );
    if (j['next_step'] == 'verify_device') {
      return LoginNeedsCode(NextStep.fromJson(j));
    }
    return LoginSignedIn(j);
  }

  Future<Json> resetPassword(String verificationToken, String password) async =>
      asJson(
        await _api.post(
          'auth/reset-password/',
          body: {'verification_token': verificationToken, 'password': password},
        ),
      );

  /// `GET auth/social/nonce/`: single use, fetched before every attempt.
  Future<String> socialNonce() async =>
      asString(asJson(await _api.get('auth/social/nonce/'))['nonce']);

  /// `POST auth/social/` with the provider SDK's token.
  Future<SocialResult> social({
    required SocialProvider provider,
    required String token,
    required String tokenType,
    String? nonce,
  }) async {
    final j = asJson(
      await _api.post(
        'auth/social/',
        body: {
          'provider': provider.code,
          'token': token,
          'token_type': tokenType,
          'nonce': nonce,
        },
      ),
    );
    if (j['next_step'] == 'verify_phone') {
      return SocialNeedsCompletion(NextStep.fromJson(j));
    }
    return SocialSignedIn(j);
  }

  /// `POST auth/social/complete/`: without [verificationToken] a new account
  /// without a phone (needs [name] and [termsVersion]); with one, the linked
  /// account (its [password] when it has one).
  Future<Json> socialComplete({
    required String socialTicket,
    String? verificationToken,
    String? password,
    String? name,
    String? termsVersion,
    required AppLanguage language,
  }) async => asJson(
    await _api.post(
      'auth/social/complete/',
      body: {
        'social_ticket': socialTicket,
        'verification_token': verificationToken,
        'password': password,
        'name': name,
        'terms_version': termsVersion,
        'language': language.code,
      },
    ),
  );

  Future<Me> me() async => Me.fromJson(asJson(await _api.get('me/')));

  Future<Me> updateMe({
    String? name,
    AppLanguage? language,
    bool? pushEnabled,
  }) async => Me.fromJson(
    asJson(
      await _api.patch(
        'me/',
        body: {
          'name': ?name,
          'language': ?language?.code,
          'push_enabled': ?pushEnabled,
        },
      ),
    ),
  );

  Future<Me> acceptTerms(String version) async => Me.fromJson(
    asJson(await _api.post('me/consent/', body: {'terms_version': version})),
  );

  Future<void> registerDevice({
    String? fcmToken,
    required bool pushEnabled,
    required String model,
    required String os,
    required String locale,
  }) => _api.put(
    'me/device/',
    body: {
      'fcm_token': fcmToken,
      'push_enabled': pushEnabled,
      'model': model,
      'os': os,
      'locale': locale,
    },
  );

  Future<void> deleteAccount({String? password}) => _api.delete(
    'me/',
    body: {'password': password, 'verification_token': null},
  );

  Future<Me> changePassword({
    required String current,
    required String password,
    required String idempotencyKey,
  }) async => Me.fromJson(
    asJson(
      await _api.post(
        'me/password/',
        body: {
          'current_password': current,
          'verification_token': null,
          'password': password,
        },
        idempotencyKey: idempotencyKey,
      ),
    ),
  );

  Future<CodeIssue> sendAttachPhoneCode(String phone) async =>
      CodeIssue.fromJson(
        asJson(await _api.post('me/phone/code/', body: {'phone': phone})),
      );

  Future<Me> attachPhone({
    required String phone,
    required String code,
    String? password,
  }) async => Me.fromJson(
    asJson(
      await _api.post(
        'me/phone/',
        body: {
          'phone': phone,
          'code': code,
          'password': password,
          'verification_token': null,
        },
      ),
    ),
  );
}
