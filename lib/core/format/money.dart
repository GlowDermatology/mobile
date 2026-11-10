import '../i18n/tr.dart';

const _nbsp = ' ';
const _minus = '−';

/// 1128000 → "1 128 000" (non-breaking spaces), like the website.
String formatNumber(num value, {AppLanguage language = AppLanguage.uz}) {
  final sign = value < 0 ? _minus : '';
  final digits = value.abs().truncate().toString();
  final separator = language == AppLanguage.en ? ',' : _nbsp;
  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => separator,
  );
  return '$sign$grouped';
}

/// 784400 → "784 400 so‘m" / "784 400 сум" / "784,400 UZS".
String formatMoney(num value, {AppLanguage language = AppLanguage.uz}) {
  final unit = switch (language) {
    AppLanguage.uz => 'so‘m',
    AppLanguage.ru => 'сум',
    AppLanguage.en => 'UZS',
  };
  return '${formatNumber(value, language: language)}$_nbsp$unit';
}

/// Ledger-style amount with an explicit sign: "+5 680", "−48 600".
String formatSigned(num value, {AppLanguage language = AppLanguage.uz}) {
  if (value == 0) return '0';
  return value > 0
      ? '+${formatNumber(value, language: language)}'
      : formatNumber(value, language: language);
}

/// Cashback a purchase of [price] earns at [percent] ("1.00"), in whole so‘m.
int cashbackFor(int price, String? percent) {
  final p = double.tryParse(percent ?? '');
  if (p == null || p <= 0) return 0;
  return (price * p / 100).floor();
}
