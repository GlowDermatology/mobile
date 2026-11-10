import '../../../core/network/api_exception.dart';
import '../../settings/data/public_settings.dart';

/// The three legal texts of `settings/public/`.
enum LegalDoc {
  privacy,
  terms,
  booking;

  /// `/settings/legal/<slug>`; unknown slugs read as the terms.
  static LegalDoc fromSlug(String slug) => LegalDoc.values.firstWhere(
    (d) => d.name == slug,
    orElse: () => LegalDoc.terms,
  );

  String textOf(PublicSettings s) => switch (this) {
    LegalDoc.privacy => s.privacyPolicy,
    LegalDoc.terms => s.terms,
    LegalDoc.booking => s.bookingPolicy,
  };

  String get route => '/settings/legal/$name';
}

/// The contact tiles under the settings groups.
enum ContactKind { telegram, instagram, website, phone }

typedef ContactLink = ({ContactKind kind, Uri uri});

/// Tiles for the contacts the shop has configured, in the design's order
/// (Telegram · Instagram · Veb-sayt · Telefon); a missing value hides its tile.
List<ContactLink> contactLinks(PublicSettings s) {
  Uri? web(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final uri = Uri.tryParse(v.contains('://') ? v : 'https://$v');
    return uri == null || uri.host.isEmpty ? null : uri;
  }

  Uri? tel(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'[^\d+]'), '');
    return digits.replaceAll('+', '').isEmpty
        ? null
        : Uri(scheme: 'tel', path: digits);
  }

  final entries = <(ContactKind, Uri?)>[
    (ContactKind.telegram, web(s.telegramUrl)),
    (ContactKind.instagram, web(s.instagramUrl)),
    (ContactKind.website, web(s.websiteUrl)),
    (ContactKind.phone, tel(s.storePhone)),
  ];
  return [
    for (final (kind, uri) in entries)
      if (uri != null) (kind: kind, uri: uri),
  ];
}

/// Client-side check of the password rules (§2.1.3: at least 8 characters,
/// not digits only). The server checks the rest; null when acceptable.
enum PasswordProblem { tooShort, numeric }

PasswordProblem? checkNewPassword(String value) {
  if (value.length < 8) return PasswordProblem.tooShort;
  if (RegExp(r'^\d+$').hasMatch(value)) return PasswordProblem.numeric;
  return null;
}

/// Splits an API error into inline field messages for [fields] and the rest
/// (shown as a snack). Returns `(fieldErrors, general)`; `general` is null
/// when every problem landed on a field.
(Map<String, String>, Object?) splitFieldErrors(
  Object error,
  Set<String> fields,
) {
  if (error is! ApiException || error.fieldErrors.isEmpty) {
    return (const {}, error);
  }
  final inline = {
    for (final e in error.fieldErrors.entries)
      if (fields.contains(e.key)) e.key: e.value,
  };
  if (inline.isEmpty) return (const {}, error);
  final leftover = error.fieldErrors.keys.any((k) => !fields.contains(k));
  return (inline, leftover || error.code != 'validation_error' ? error : null);
}

/// Validates a profile name like `PATCH me/` (trimmed 2..150).
bool isValidName(String value) {
  final t = value.trim();
  return t.length >= 2 && t.length <= 150;
}
