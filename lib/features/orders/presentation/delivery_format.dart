import '../../../core/format/dates.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../data/order_models.dart';
import 'orders_text.dart';

/// Presentation of the Yandex delivery window and stage (the website's
/// `delivery-format.ts`). The window is the server's (`eta_from`/`eta_to`);
/// it is only formatted here, in Tashkent time. Pure; unit-tested.

int _dayIndex(DateTime instant) {
  final t = tashkent(instant);
  return DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
}

/// "Bugun, 14:30–16:00", "23-oktabr, 14:30–16:00",
/// "23-oktabr, 18:00 – 24-oktabr, 10:00"; the day of [now] and the next one
/// (Tashkent) read "Bugun"/"Ertaga". Null when the server sent no window.
String? formatEtaWindow(
  DateTime? from,
  DateTime? to,
  AppLanguage language, {
  required DateTime now,
}) {
  final start = from ?? to;
  final end = to ?? from;
  if (start == null || end == null) return null;
  String day(DateTime instant) => switch (_dayIndex(instant) - _dayIndex(now)) {
    0 => OrdersText.today.get(language),
    1 => OrdersText.tomorrow.get(language),
    _ => formatDayMonth(instant, language),
  };
  if (_dayIndex(start) == _dayIndex(end)) {
    final a = formatTime(start), b = formatTime(end);
    return a == b ? '${day(start)}, $a' : '${day(start)}, $a–$b';
  }
  return '${day(start)}, ${formatTime(start)} – ${day(end)}, ${formatTime(end)}';
}

/// Chip tone of a shipment stage.
GdTone stageTone(String? stage) => switch (stage) {
  ShipmentStage.delivered => GdTone.success,
  ShipmentStage.returning ||
  ShipmentStage.returned ||
  ShipmentStage.failed => GdTone.warning,
  ShipmentStage.cancelled => GdTone.neutral,
  _ => GdTone.gold,
};

/// Timeline entries that tell of a delivery that went wrong (Yandex): their
/// dot is red (`delivery_failed`) or orange (`shipment_returned`).
GdTone? timelineAlertTone(String type) => switch (type) {
  'delivery_failed' => GdTone.danger,
  'shipment_returned' => GdTone.warning,
  _ => null,
};
