import '../../../core/network/json.dart';

/// `Me` (contract §2.2.1).
class Me {
  const Me({
    required this.id,
    required this.phone,
    required this.email,
    required this.name,
    required this.language,
    required this.imageUrl,
    required this.hasPassword,
    required this.pushEnabled,
    required this.termsVersion,
    required this.currentTermsVersion,
    required this.consentUpdateRequired,
    required this.registeredAt,
  });

  factory Me.fromJson(Json j) {
    final consent = asJson(j['consent']);
    return Me(
      id: asInt(j['id']),
      phone: asStringOrNull(j['phone']),
      email: asStringOrNull(j['email']),
      name: asString(j['name']),
      language: asString(j['language'], 'uz'),
      imageUrl: asStringOrNull(j['image_url']),
      hasPassword: asBool(j['has_password']),
      pushEnabled: asBool(j['push_enabled']),
      termsVersion: asStringOrNull(consent['terms_version']),
      currentTermsVersion: asStringOrNull(consent['current_version']),
      consentUpdateRequired: asBool(consent['update_required']),
      registeredAt: asDate(j['registered_at']),
    );
  }

  final int id;
  final String? phone;
  final String? email;
  final String name;
  final String language;
  final String? imageUrl;
  final bool hasPassword;
  final bool pushEnabled;
  final String? termsVersion;
  final String? currentTermsVersion;
  final bool consentUpdateRequired;
  final DateTime? registeredAt;

  /// "MK" for "Malika Karimova".
  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'GD';
    return parts.take(2).map((p) => p.substring(0, 1).toUpperCase()).join();
  }
}

/// `CodeIssue` (§2.1.1): a code was sent.
class CodeIssue {
  const CodeIssue({
    required this.phoneMask,
    required this.expiresIn,
    required this.resendIn,
    required this.length,
  });
  factory CodeIssue.fromJson(Json j) => CodeIssue(
    phoneMask: asString(j['phone_mask']),
    expiresIn: asInt(j['expires_in'], 120),
    resendIn: asInt(j['resend_in'], 60),
    length: asInt(j['length'], 6),
  );
  final String phoneMask;
  final int expiresIn;
  final int resendIn;
  final int length;
}

/// Result of `auth/login/`: tokens on a known device, else the new-device step.
sealed class LoginResult {}

class LoginSignedIn extends LoginResult {
  LoginSignedIn(this.tokens);
  final Json tokens;
}

class LoginNeedsCode extends LoginResult {
  LoginNeedsCode(this.issue);
  final CodeIssue issue;
}

/// OTP purposes the app uses (`OtpPurpose`).
enum OtpPurpose {
  register('register'),
  loginNewDevice('login_new_device'),
  resetPassword('reset_password');

  const OtpPurpose(this.code);
  final String code;
}
