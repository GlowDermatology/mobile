import 'package:flutter/foundation.dart';

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
    this.imageThumbnailUrl,
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
      imageThumbnailUrl: asStringOrNull(j['image_thumbnail_url']),
    );
  }

  final int id;
  final String? phone;
  final String? email;
  final String name;
  final String language;
  final String? imageUrl;

  /// 400 px variant (null → the original).
  final String? imageThumbnailUrl;
  String? get imageThumbUrl => imageThumbnailUrl ?? imageUrl;
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

/// Where a code goes: an SMS to a phone or a message to an e-mail address
/// (`otp_channel` of `auth/login/`).
enum OtpChannel {
  sms('sms'),
  email('email');

  const OtpChannel(this.code);
  final String code;

  static OtpChannel? fromCode(Object? code) => switch (code) {
    'sms' => OtpChannel.sms,
    'email' => OtpChannel.email,
    _ => null,
  };
}

/// Who signs in: exactly one of `phone` (E.164) or `email` (trimmed,
/// lower-cased) in every auth body (contract §2.1, hybrid identity).
@immutable
class AuthIdentifier {
  const AuthIdentifier.phone(this.value) : channel = OtpChannel.sms;
  const AuthIdentifier.email(this.value) : channel = OtpChannel.email;

  /// [OtpChannel.sms] for a phone, [OtpChannel.email] for an address.
  final OtpChannel channel;

  /// "+998901234567" or "malika@mail.uz".
  final String value;

  bool get isEmail => channel == OtpChannel.email;

  /// The body key and value: `{"phone": …}` or `{"email": …}`.
  Json get body => {isEmail ? 'email' : 'phone': value};

  @override
  bool operator ==(Object other) =>
      other is AuthIdentifier &&
      other.channel == channel &&
      other.value == value;

  @override
  int get hashCode => Object.hash(channel, value);

  @override
  String toString() => 'AuthIdentifier(${channel.code})';
}

/// `CodeIssue` (§2.1.1): a code was sent, by SMS ([phoneMask]) or by e-mail
/// ([emailMask]).
class CodeIssue {
  const CodeIssue({
    this.phoneMask,
    this.emailMask,
    required this.expiresIn,
    required this.resendIn,
    required this.length,
  });
  factory CodeIssue.fromJson(Json j) => CodeIssue(
    phoneMask: _mask(j['phone_mask']),
    emailMask: _mask(j['email_mask']),
    expiresIn: asInt(j['expires_in'], 120),
    resendIn: asInt(j['resend_in'], 60),
    length: asInt(j['length'], 6),
  );
  final String? phoneMask;
  final String? emailMask;
  final int expiresIn;
  final int resendIn;
  final int length;

  /// How the code went: e-mail when the server named an address.
  OtpChannel get channel =>
      emailMask != null ? OtpChannel.email : OtpChannel.sms;

  /// "+998 90 *** ** 67" or "m***@gmail.com".
  String get mask => emailMask ?? phoneMask ?? '';
}

String? _mask(Object? v) {
  final s = asStringOrNull(v);
  return s == null || s.isEmpty ? null : s;
}

/// One place a new-device code can be sent (`NextStep.channels`, newer
/// backends only).
@immutable
class CodeChannel {
  const CodeChannel(this.channel, this.mask);
  final OtpChannel channel;
  final String mask;
}

/// `NextStep` of `auth/login/` (`verify_device`) and `auth/social/`
/// (`verify_phone`). Unknown fields of an older or newer backend are ignored.
class NextStep {
  const NextStep({
    required this.nextStep,
    this.phoneMask,
    this.emailMask,
    this.otp,
    this.channels = const [],
    this.socialTicket,
    this.provider,
    this.expiresIn,
  });

  factory NextStep.fromJson(Json j) {
    final otp = j['otp'] is Map ? asJson(j['otp']) : null;
    return NextStep(
      nextStep: asString(j['next_step']),
      phoneMask: _mask(j['phone_mask']),
      emailMask: _mask(j['email_mask']),
      otp: otp == null
          ? null
          : CodeIssue(
              phoneMask: _mask(j['phone_mask']),
              emailMask: _mask(j['email_mask']),
              expiresIn: asInt(otp['expires_in'], 120),
              resendIn: asInt(otp['resend_in'], 60),
              length: asInt(otp['length'], 6),
            ),
      channels: [
        for (final c in asJsonList(j['channels']))
          if (OtpChannel.fromCode(c['channel']) case final channel?)
            CodeChannel(channel, asString(c['mask'])),
      ],
      socialTicket: asStringOrNull(j['social_ticket']),
      provider: asStringOrNull(j['provider']),
      expiresIn: asIntOrNull(j['expires_in']),
    );
  }

  /// `verify_device` or `verify_phone`.
  final String nextStep;
  final String? phoneMask;
  final String? emailMask;

  /// The new-device code that was sent (`verify_device`).
  final CodeIssue? otp;

  /// Where a new-device code can be sent; empty on an older backend.
  final List<CodeChannel> channels;
  final String? socialTicket;
  final String? provider;
  final int? expiresIn;

  /// The code of a `verify_device` step (defaults when the server sent none).
  CodeIssue get issue =>
      otp ??
      CodeIssue(
        phoneMask: phoneMask,
        emailMask: emailMask,
        expiresIn: 120,
        resendIn: 60,
        length: 6,
      );
}

/// Result of `auth/login/`: tokens on a known device, else the new-device step.
sealed class LoginResult {}

class LoginSignedIn extends LoginResult {
  LoginSignedIn(this.tokens);
  final Json tokens;
}

class LoginNeedsCode extends LoginResult {
  LoginNeedsCode(this.step);
  final NextStep step;
  CodeIssue get issue => step.issue;
  List<CodeChannel> get channels => step.channels;
}

/// `auth/verify-code/`: the single-use token and whether an active customer
/// already has the identifier (lets the social-link step branch).
class Verification {
  const Verification({required this.token, required this.customerExists});
  factory Verification.fromJson(Json j) => Verification(
    token: asString(j['verification_token']),
    customerExists: asBool(j['customer_exists']),
  );
  final String token;
  final bool customerExists;
}

/// Social providers the app offers (no Apple).
enum SocialProvider {
  google('google'),
  facebook('facebook');

  const SocialProvider(this.code);
  final String code;
}

/// Result of `auth/social/`: tokens for a linked identity, else the ticket
/// of the "link a phone now or later" step.
sealed class SocialResult {}

class SocialSignedIn extends SocialResult {
  SocialSignedIn(this.tokens);
  final Json tokens;
}

class SocialNeedsCompletion extends SocialResult {
  SocialNeedsCompletion(this.step);
  final NextStep step;
  String get ticket => step.socialTicket ?? '';
}

/// OTP purposes the app uses (`OtpPurpose`).
enum OtpPurpose {
  register('register'),
  loginNewDevice('login_new_device'),
  resetPassword('reset_password'),
  linkSocial('link_social');

  const OtpPurpose(this.code);
  final String code;
}
