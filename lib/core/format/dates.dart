import '../i18n/tr.dart';

/// The business runs in Asia/Tashkent (UTC+5, no daylight saving). The API
/// sends ISO 8601 with `+05:00`; everything is shown in Tashkent time whatever
/// the phone's time zone is.
const tashkentOffset = Duration(hours: 5);

/// Wall-clock parts of [instant] in Tashkent (a UTC DateTime whose fields
/// read as Tashkent local time).
DateTime tashkent(DateTime instant) => instant.toUtc().add(tashkentOffset);

DateTime? parseApiDate(Object? value) => value is String ? DateTime.tryParse(value) : null;

const _monthsUz = ['yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun', 'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr'];
const _monthsRu = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
const _monthsEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// Monday-first short weekday names (DateTime.weekday 1..7).
const _weekdaysShort = {
  AppLanguage.uz: ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'],
  AppLanguage.ru: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
  AppLanguage.en: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
};

String _pad(int n) => n.toString().padLeft(2, '0');

/// "14:02"
String formatTime(DateTime instant) {
  final t = tashkent(instant);
  return '${_pad(t.hour)}:${_pad(t.minute)}';
}

/// "23-oktabr" / "23 октября" / "23 October"
String formatDayMonth(DateTime instant, AppLanguage language) {
  final t = tashkent(instant);
  return switch (language) {
    AppLanguage.uz => '${t.day}-${_monthsUz[t.month - 1]}',
    AppLanguage.ru => '${t.day} ${_monthsRu[t.month - 1]}',
    AppLanguage.en => '${t.day} ${_monthsEn[t.month - 1]}',
  };
}

/// "23-oktabr, 14:02"
String formatDateTime(DateTime instant, AppLanguage language) => '${formatDayMonth(instant, language)}, ${formatTime(instant)}';

/// "Du" for a Tashkent instant.
String weekdayShort(DateTime instant, AppLanguage language) => _weekdaysShort[language]![tashkent(instant).weekday - 1];

/// "Du, 26-oktabr · 09:00"
String formatSlot(DateTime instant, AppLanguage language) =>
    '${weekdayShort(instant, language)}, ${formatDayMonth(instant, language)} · ${formatTime(instant)}';

/// The Tashkent calendar day as an ISO date ("2026-10-26").
String isoDate(DateTime instant) {
  final t = tashkent(instant);
  return '${t.year}-${_pad(t.month)}-${_pad(t.day)}';
}

/// Same Tashkent calendar day?
bool sameDay(DateTime a, DateTime b) {
  final x = tashkent(a), y = tashkent(b);
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// Countdown "14:37" (mm:ss), never negative.
String formatCountdown(Duration remaining) {
  final total = remaining.isNegative ? 0 : remaining.inSeconds;
  return '${_pad(total ~/ 60)}:${_pad(total % 60)}';
}
