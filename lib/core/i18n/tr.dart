import 'package:flutter/widgets.dart';

/// The three languages of the API (`Accept-Language`).
enum AppLanguage {
  uz('uz', 'O‘zbekcha'),
  ru('ru', 'Русский'),
  en('en', 'English');

  const AppLanguage(this.code, this.label);

  final String code;
  final String label;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) =>
      AppLanguage.values.firstWhere((l) => l.code == code, orElse: () => AppLanguage.uz);
}

/// One UI string in the three app languages, kept side by side so a
/// translation is never missing. Server-side texts (statuses, error messages,
/// product names) already arrive in the requested language and are shown as
/// they are.
///
/// Usage: `const Tr('Savat', 'Корзина', 'Cart').of(context)`.
@immutable
class Tr {
  const Tr(this.uz, this.ru, this.en);

  final String uz;
  final String ru;
  final String en;

  String get(AppLanguage language) => switch (language) {
        AppLanguage.uz => uz,
        AppLanguage.ru => ru,
        AppLanguage.en => en,
      };

  String of(BuildContext context) => get(AppLanguage.fromCode(Localizations.localeOf(context).languageCode));

  /// Replaces `{name}` placeholders.
  String fmt(BuildContext context, Map<String, Object> values) {
    var text = of(context);
    values.forEach((key, value) => text = text.replaceAll('{$key}', '$value'));
    return text;
  }
}

extension TrContext on BuildContext {
  AppLanguage get language => AppLanguage.fromCode(Localizations.localeOf(this).languageCode);
}
