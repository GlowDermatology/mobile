import '../../../core/format/dates.dart';
import '../../../core/i18n/tr.dart';
import 'inbox_models.dart';

/// One Tashkent day of the inbox ("BUGUN", "KECHA", "21-OKTABR").
class InboxDay {
  const InboxDay({required this.day, required this.items});

  /// Tashkent calendar day ("2026-10-23"); empty for items without a date.
  final String day;
  final List<InboxItem> items;

  DateTime? get instant => items.first.createdAt;
}

/// Groups the newest-first feed by Tashkent calendar day, keeping the order.
List<InboxDay> groupByDay(List<InboxItem> items) {
  final groups = <InboxDay>[];
  for (final item in items) {
    final day = item.createdAt == null ? '' : isoDate(item.createdAt!);
    if (groups.isNotEmpty && groups.last.day == day) {
      groups.last.items.add(item);
    } else {
      groups.add(InboxDay(day: day, items: [item]));
    }
  }
  return groups;
}

const _today = Tr('Bugun', 'Сегодня', 'Today');
const _yesterday = Tr('Kecha', 'Вчера', 'Yesterday');

/// Section label of a day, uppercase like the design: "BUGUN", "KECHA",
/// "21-OKTABR" (Tashkent days, whatever the phone's time zone).
String dayLabel(DateTime? instant, DateTime now, AppLanguage language) {
  if (instant == null) return '';
  final String label;
  if (sameDay(instant, now)) {
    label = _today.get(language);
  } else if (sameDay(instant, now.subtract(const Duration(days: 1)))) {
    label = _yesterday.get(language);
  } else {
    final sameYear = tashkent(instant).year == tashkent(now).year;
    label = sameYear
        ? formatDayMonth(instant, language)
        : '${formatDayMonth(instant, language)} ${tashkent(instant).year}';
  }
  return label.toUpperCase();
}

/// Where tapping an item leads: an in-app [route] or an external https [url].
class InboxTarget {
  const InboxTarget.route(String this.route) : url = null;
  const InboxTarget.external(Uri this.url) : route = null;

  final String? route;
  final Uri? url;
}

/// The destination of [link], or null when the item only gets marked read.
InboxTarget? targetFor(InboxLink link) {
  switch (link.kind) {
    case 'order' when link.orderId != null:
      return InboxTarget.route('/orders/${link.orderId}');
    case 'appointment' when link.appointmentId != null:
      return InboxTarget.route('/appointments/${link.appointmentId}');
    case 'product' when link.productId != null:
      return InboxTarget.route('/product/${link.productId}');
    case 'url':
      final uri = Uri.tryParse(link.url ?? '');
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
      return InboxTarget.external(uri);
  }
  return null;
}
