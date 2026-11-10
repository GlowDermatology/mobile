import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/core/i18n/tr.dart';
import 'package:glow_derma/features/notifications/application/inbox_logic.dart';
import 'package:glow_derma/features/notifications/application/inbox_models.dart';

Map<String, dynamic> inboxJson(
  int id,
  String createdAt, {
  String kind = 'general',
  Map<String, dynamic>? link,
  String? readAt,
}) => {
  'id': id,
  'kind': kind,
  'title': 'T$id',
  'body': 'B$id',
  'image_url': null,
  'link':
      link ??
      {
        'kind': 'none',
        'product_id': null,
        'order_id': null,
        'appointment_id': null,
        'url': null,
      },
  'created_at': createdAt,
  'read_at': readAt,
};

InboxItem item(int id, String createdAt) =>
    InboxItem.fromJson(inboxJson(id, createdAt));

InboxLink link(
  String kind, {
  int? product,
  int? order,
  int? appointment,
  String? url,
}) => InboxLink.fromJson({
  'kind': kind,
  'product_id': product,
  'order_id': order,
  'appointment_id': appointment,
  'url': url,
});

void main() {
  group('InboxItem.fromJson', () {
    test('parses the contract example', () {
      final i = InboxItem.fromJson(
        inboxJson(
          901,
          '2026-10-23T16:40:00+05:00',
          kind: 'order_status',
          link: {
            'kind': 'order',
            'product_id': null,
            'order_id': 10248,
            'appointment_id': null,
            'url': null,
          },
        ),
      );
      expect(i.id, 901);
      expect(i.kind, 'order_status');
      expect(i.unread, isTrue);
      expect(i.link.kind, 'order');
      expect(i.link.orderId, 10248);
      expect(i.markRead(DateTime.utc(2026)).unread, isFalse);
    });

    test('missing link means none', () {
      final i = InboxItem.fromJson({
        'id': 1,
        'kind': 'promo',
        'title': 'x',
        'created_at': null,
      });
      expect(i.link.kind, 'none');
      expect(targetFor(i.link), isNull);
    });
  });

  group('groupByDay (Tashkent days)', () {
    test('splits on the Tashkent date, not UTC', () {
      final items = [
        item(1, '2026-10-23T16:40:00+05:00'),
        item(
          2,
          '2026-10-23T00:30:00+05:00',
        ), // 2026-10-22 19:30 UTC — still the 23rd in Tashkent
        item(3, '2026-10-22T23:59:00+05:00'),
        item(4, '2026-10-21T10:00:00+05:00'),
      ];
      final groups = groupByDay(items);
      expect(groups.map((g) => g.day), [
        '2026-10-23',
        '2026-10-22',
        '2026-10-21',
      ]);
      expect(groups.first.items.map((i) => i.id), [1, 2]);
      expect(groups[1].items.map((i) => i.id), [3]);
    });

    test('empty list', () => expect(groupByDay(const []), isEmpty));
  });

  group('dayLabel', () {
    // 2026-10-23 16:50 in Tashkent.
    final now = DateTime.parse('2026-10-23T16:50:00+05:00');

    test('today, yesterday, older (uz)', () {
      expect(
        dayLabel(
          DateTime.parse('2026-10-23T00:10:00+05:00'),
          now,
          AppLanguage.uz,
        ),
        'BUGUN',
      );
      expect(
        dayLabel(
          DateTime.parse('2026-10-22T18:12:00+05:00'),
          now,
          AppLanguage.uz,
        ),
        'KECHA',
      );
      expect(
        dayLabel(
          DateTime.parse('2026-10-21T10:00:00+05:00'),
          now,
          AppLanguage.uz,
        ),
        '21-OKTABR',
      );
    });

    test('uses Tashkent midnight even near the UTC day boundary', () {
      // 00:30 Tashkent on the 24th is still the 23rd in UTC.
      final lateNow = DateTime.parse('2026-10-24T00:30:00+05:00');
      expect(
        dayLabel(
          DateTime.parse('2026-10-23T23:50:00+05:00'),
          lateNow,
          AppLanguage.uz,
        ),
        'KECHA',
      );
      expect(
        dayLabel(
          DateTime.parse('2026-10-24T00:05:00+05:00'),
          lateNow,
          AppLanguage.uz,
        ),
        'BUGUN',
      );
    });

    test('other languages and other years', () {
      expect(
        dayLabel(
          DateTime.parse('2026-10-23T10:00:00+05:00'),
          now,
          AppLanguage.ru,
        ),
        'СЕГОДНЯ',
      );
      expect(
        dayLabel(
          DateTime.parse('2026-10-22T10:00:00+05:00'),
          now,
          AppLanguage.en,
        ),
        'YESTERDAY',
      );
      expect(
        dayLabel(
          DateTime.parse('2026-10-21T10:00:00+05:00'),
          now,
          AppLanguage.ru,
        ),
        '21 ОКТЯБРЯ',
      );
      expect(
        dayLabel(
          DateTime.parse('2025-12-31T10:00:00+05:00'),
          now,
          AppLanguage.uz,
        ),
        '31-DEKABR 2025',
      );
    });
  });

  group('targetFor', () {
    test('in-app routes', () {
      expect(targetFor(link('order', order: 10248))?.route, '/orders/10248');
      expect(
        targetFor(link('appointment', appointment: 77))?.route,
        '/appointments/77',
      );
      expect(targetFor(link('product', product: 5))?.route, '/product/5');
    });

    test('https links open outside', () {
      final t = targetFor(link('url', url: 'https://glowderma.uz/aksiya'));
      expect(t?.route, isNull);
      expect(t?.url, Uri.parse('https://glowderma.uz/aksiya'));
    });

    test('nothing to open', () {
      expect(targetFor(link('none')), isNull);
      expect(targetFor(link('order')), isNull);
      expect(targetFor(link('url', url: 'http://insecure.example')), isNull);
      expect(targetFor(link('url', url: 'javascript:alert(1)')), isNull);
      expect(targetFor(link('something_new', order: 1)), isNull);
    });
  });
}
