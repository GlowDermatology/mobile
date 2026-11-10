import '../../../core/format/dates.dart';
import '../../../core/i18n/tr.dart';
import '../data/appointment_models.dart';

/// Pure booking logic (no Flutter, no network), kept apart for tests.
///
/// A calendar "day" is a UTC midnight `DateTime` whose y/m/d read as the
/// Tashkent date: the dates.dart formatters (which add +05:00) keep it on the
/// same day.

/// The Tashkent calendar day of [instant].
DateTime tashkentDay(DateTime instant) {
  final t = tashkent(instant);
  return DateTime.utc(t.year, t.month, t.day);
}

/// How many day chips the booking strip shows (the API allows today … +30).
const bookingStripDays = 30;

/// How far ahead the specialists list looks for the next free time.
const nextSlotSearchDays = 7;

/// Days from today: the booking date strip.
List<DateTime> dateStrip(DateTime now, {int days = bookingStripDays}) {
  final today = tashkentDay(now);
  return [
    for (var i = 0; i < days; i++)
      DateTime.utc(today.year, today.month, today.day + i),
  ];
}

/// One chip of the "Bo‘sh vaqt" grid.
class TimeChip {
  const TimeChip({required this.minutes, this.slot});

  /// Minutes after midnight (Tashkent).
  final int minutes;

  /// The free slot at this time; null when taken (shown struck through).
  final Slot? slot;

  bool get enabled => slot != null;
  String get label => clockLabel(minutes);

  @override
  String toString() => '$label${enabled ? '' : 'x'}';
}

/// Builds the time grid of a day: every start time of the working hours on
/// the specialist's step whose service still ends within the hours; the times
/// listed in `slots` are enabled, the others are taken. A slot outside the
/// grid (should not happen) is still shown so it can be booked.
List<TimeChip> buildTimeGrid(SlotsDay day) {
  final free = <int, Slot>{};
  for (final s in day.slots) {
    final m = s.startMinutes;
    if (m != null) free.putIfAbsent(m, () => s);
  }
  final times = <int>{};
  final start = day.workStart, end = day.workEnd;
  if (start != null && end != null) {
    final step = day.slotStepMin > 0 ? day.slotStepMin : 30;
    final duration = day.durationMin > 0 ? day.durationMin : step;
    for (var t = start; t + duration <= end; t += step) {
      times.add(t);
    }
  }
  times.addAll(free.keys);
  final sorted = times.toList()..sort();
  return [for (final t in sorted) TimeChip(minutes: t, slot: free[t])];
}

/// Scans [days] days from [today], one at a time, and answers the first free
/// start time, or null when there is none. Stops at the first hit.
Future<DateTime?> findNextSlot({
  required DateTime now,
  required Future<SlotsDay> Function(String date) fetch,
  int days = nextSlotSearchDays,
}) async {
  for (final day in dateStrip(now, days: days)) {
    final answer = await fetch(isoDate(day));
    for (final slot in answer.slots) {
      if (slot.startAt != null) return slot.startAt;
    }
  }
  return null;
}

const _today = Tr('Bugun', 'Сегодня', 'Today');
const _tomorrow = Tr('Ertaga', 'Завтра', 'Tomorrow');

/// "Bugun, 17:00" / "Ertaga, 09:00" / "Du, 26-oktabr · 09:00".
String nextSlotLabel(DateTime slot, DateTime now, AppLanguage language) {
  final diff = tashkentDay(slot).difference(tashkentDay(now)).inDays;
  if (diff == 0) return '${_today.get(language)}, ${formatTime(slot)}';
  if (diff == 1) return '${_tomorrow.get(language)}, ${formatTime(slot)}';
  return formatSlot(slot, language);
}

/// Specialists filter of the list screen.
enum SpecialistFilter { all, dermatologist, cosmetologist }

List<Specialist> filterSpecialists(
  List<Specialist> all,
  SpecialistFilter filter,
) => switch (filter) {
  SpecialistFilter.all => all,
  SpecialistFilter.dermatologist =>
    all.where((s) => s.role == 'dermatologist').toList(),
  SpecialistFilter.cosmetologist =>
    all.where((s) => s.role == 'cosmetologist').toList(),
};

/// The specialist's first services, for the card subtitle ("Akne, pigmentatsiya").
String servicesSummary(Specialist s, {int max = 2}) =>
    s.services.take(max).map((e) => e.displayShortName).join(', ');
