/// Uzbek mobile numbers: E.164 `^\+998\d{9}$` (customer contract §1.4).
final phonePattern = RegExp(r'^\+998\d{9}$');

/// The nine national digits of whatever was typed or pasted.
String nationalDigits(String input) {
  final trimmed = input.trim();
  var digits = trimmed.replaceAll(RegExp(r'\D'), '');
  // "+998 90 1…" always carries the country code; without "+" a leading 998
  // is the country code only when more than nine digits were given.
  if (digits.startsWith('998') &&
      (trimmed.startsWith('+') || digits.length > 9)) {
    digits = digits.substring(3);
  }
  return digits.length > 9 ? digits.substring(0, 9) : digits;
}

/// "901234567" → "90 123 45 67" (the field shows "+998" as a fixed prefix).
String maskNational(String digits) {
  final d = nationalDigits(digits);
  final parts = <String>[
    if (d.isNotEmpty) d.substring(0, d.length.clamp(0, 2)),
    if (d.length > 2) d.substring(2, d.length.clamp(2, 5)),
    if (d.length > 5) d.substring(5, d.length.clamp(5, 7)),
    if (d.length > 7) d.substring(7, d.length.clamp(7, 9)),
  ];
  return parts.join(' ');
}

/// Nine national digits → "+998901234567", or null when incomplete.
String? toE164(String nationalInput) {
  final d = nationalDigits(nationalInput);
  return d.length == 9 ? '+998$d' : null;
}

/// "+998901234567" → "+998 90 123 45 67".
String formatPhone(String? e164) {
  if (e164 == null) return '';
  final d = e164.replaceAll(RegExp(r'\D'), '');
  if (d.length != 12 || !d.startsWith('998')) return e164;
  return '+998 ${d.substring(3, 5)} ${d.substring(5, 8)} ${d.substring(8, 10)} ${d.substring(10, 12)}';
}
