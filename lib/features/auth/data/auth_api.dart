import '../../../core/i18n/tr.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import 'auth_models.dart';

/// `auth/*` endpoints (contract §2.1) and `me/` (§2.2).
class AuthApi {
  AuthApi(this._api);
  final ApiClient _api;

  Future<CodeIssue> sendCode(String phone, OtpPurpose purpose) async =>
      CodeIssue.fromJson(asJson(await _api.post('auth/send-code/', body: {'phone': phone, 'purpose': purpose.code})));

  /// Returns the single-use `verification_token`.
  Future<String> verifyCode(String phone, OtpPurpose purpose, String code) async {
    final j = asJson(await _api.post('auth/verify-code/', body: {'phone': phone, 'purpose': purpose.code, 'code': code}));
    return asString(j['verification_token']);
  }

  Future<Json> register({
    required String verificationToken,
    required String name,
    required String password,
    required String termsVersion,
    required AppLanguage language,
  }) async =>
      asJson(await _api.post('auth/set-password/', body: {
        'verification_token': verificationToken,
        'name': name,
        'password': password,
        'terms_version': termsVersion,
        'language': language.code,
      }));

  Future<LoginResult> login(String phone, String password, {String? verificationToken}) async {
    final j = asJson(await _api.post('auth/login/', body: {
      'phone': phone,
      'password': password,
      'verification_token': verificationToken,
    }));
    if (j['next_step'] == 'verify_device') {
      final otp = asJson(j['otp']);
      return LoginNeedsCode(CodeIssue(
        phoneMask: asString(j['phone_mask']),
        expiresIn: asInt(otp['expires_in'], 120),
        resendIn: asInt(otp['resend_in'], 60),
        length: asInt(otp['length'], 6),
      ));
    }
    return LoginSignedIn(j);
  }

  Future<Json> resetPassword(String verificationToken, String password) async =>
      asJson(await _api.post('auth/reset-password/', body: {'verification_token': verificationToken, 'password': password}));

  Future<Me> me() async => Me.fromJson(asJson(await _api.get('me/')));

  Future<Me> updateMe({String? name, AppLanguage? language, bool? pushEnabled}) async => Me.fromJson(asJson(await _api.patch('me/', body: {
        'name': ?name,
        'language': ?language?.code,
        'push_enabled': ?pushEnabled,
      })));

  Future<Me> acceptTerms(String version) async => Me.fromJson(asJson(await _api.post('me/consent/', body: {'terms_version': version})));

  Future<void> registerDevice({String? fcmToken, required bool pushEnabled, required String model, required String os, required String locale}) =>
      _api.put('me/device/', body: {'fcm_token': fcmToken, 'push_enabled': pushEnabled, 'model': model, 'os': os, 'locale': locale});

  Future<void> deleteAccount({String? password}) => _api.delete('me/', body: {'password': password, 'verification_token': null});

  Future<Me> changePassword({required String current, required String password, required String idempotencyKey}) async =>
      Me.fromJson(asJson(await _api.post('me/password/',
          body: {'current_password': current, 'verification_token': null, 'password': password}, idempotencyKey: idempotencyKey)));

  Future<CodeIssue> sendAttachPhoneCode(String phone) async => CodeIssue.fromJson(asJson(await _api.post('me/phone/code/', body: {'phone': phone})));

  Future<Me> attachPhone({required String phone, required String code, String? password}) async =>
      Me.fromJson(asJson(await _api.post('me/phone/', body: {'phone': phone, 'code': code, 'password': password, 'verification_token': null})));
}
