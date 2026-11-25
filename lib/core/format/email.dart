/// E-mail addresses as the API takes them (contract §2.1, hybrid identity):
/// trimmed and lower-cased, one `@`, a dotted domain, no spaces, at most 254
/// characters — the website's rule (`features/shop/auth/identifier.ts`).
final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// The longest address the API accepts.
const emailMaxLength = 254;

/// "  Malika@Mail.UZ " → "malika@mail.uz".
String normalizeEmail(String input) => input.trim().toLowerCase();

/// The normalised address, or null when it is not a valid one.
String? toEmail(String input) {
  final email = normalizeEmail(input);
  return email.length <= emailMaxLength && emailPattern.hasMatch(email)
      ? email
      : null;
}
