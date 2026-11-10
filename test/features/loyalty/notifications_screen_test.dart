import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/core/network/api_client.dart';
import 'package:glow_derma/core/network/json.dart';
import 'package:glow_derma/core/network/page.dart';
import 'package:glow_derma/features/notifications/application/inbox_controller.dart';
import 'package:glow_derma/features/notifications/application/inbox_models.dart';
import 'package:glow_derma/features/notifications/data/unread_count.dart';
import 'package:glow_derma/features/notifications/presentation/notifications_screen.dart';

import 'harness.dart';
import 'inbox_logic_test.dart' show inboxJson;

class _NoClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeInboxApi extends InboxApi {
  FakeInboxApi(this.pages) : super(_NoClient());
  final Map<int, List<Json>> pages;
  final reads = <int>[];
  int readAlls = 0;

  int get _unread => pages.values
      .expand((p) => p)
      .where((j) => j['read_at'] == null && !reads.contains(j['id']))
      .length;

  @override
  Future<Page<InboxItem>> list({int page = 1}) async => Page.fromJson({
    'count': pages.values.expand((p) => p).length,
    'page': page,
    'page_size': 20,
    'page_count': pages.length,
    'results': pages[page] ?? const [],
    'unread_count': _unread,
  }, InboxItem.fromJson);

  @override
  Future<Json> read(int id) async {
    reads.add(id);
    return {
      'id': id,
      'read_at': '2026-10-23T17:00:00+05:00',
      'unread_count': _unread,
    };
  }

  @override
  Future<Json> readAll() async {
    readAlls++;
    return {'updated': _unread, 'unread_count': 0};
  }
}

String _todayAt(int hour) {
  final t = DateTime.now().toUtc().add(const Duration(hours: 5));
  final d =
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  return '${d}T${hour.toString().padLeft(2, '0')}:00:00+05:00';
}

void main() {
  testWidgets('groups by day, opens the order and marks it read', (
    tester,
  ) async {
    final api = FakeInboxApi({
      1: [
        inboxJson(
          901,
          _todayAt(0),
          kind: 'order_status',
          link: {
            'kind': 'order',
            'product_id': null,
            'order_id': 10248,
            'appointment_id': null,
            'url': null,
          },
        ),
        inboxJson(
          900,
          '2025-10-21T10:00:00+05:00',
          readAt: '2025-10-21T11:00:00+05:00',
        ),
      ],
    });
    final container = ProviderContainer(
      overrides: [
        ...commonOverrides(unread: 5),
        inboxApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      routerApp(const NotificationsScreen(), const [], container: container),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bildirishnomalar'), findsOneWidget);
    expect(find.text('BUGUN'), findsOneWidget);
    expect(find.text('21-OKTABR 2025'), findsOneWidget);
    expect(
      container.read(unreadCountProvider),
      1,
      reason: 'synced from the page envelope',
    );

    await tester.tap(find.text('T901'));
    await tester.pumpAndSettle();
    expect(api.reads, [901]);
    expect(find.text('page /orders/10248'), findsOneWidget);
    expect(container.read(unreadCountProvider), 0);
  });

  testWidgets('read all clears the badge', (tester) async {
    final api = FakeInboxApi({
      1: [inboxJson(1, _todayAt(1)), inboxJson(2, _todayAt(0))],
    });
    final container = ProviderContainer(
      overrides: [
        ...commonOverrides(),
        inboxApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      routerApp(const NotificationsScreen(), const [], container: container),
    );
    await tester.pumpAndSettle();
    expect(container.read(unreadCountProvider), 2);

    await tester.tap(find.text('Hammasini o‘qish'));
    await tester.pumpAndSettle();
    expect(api.readAlls, 1);
    expect(container.read(unreadCountProvider), 0);
    expect(
      container.read(inboxProvider).value!.items.every((i) => !i.unread),
      isTrue,
    );
  });

  testWidgets('url links go to the opener, not the router', (tester) async {
    final opened = <Uri>[];
    final api = FakeInboxApi({
      1: [
        inboxJson(
          5,
          _todayAt(0),
          kind: 'promo',
          link: {
            'kind': 'url',
            'product_id': null,
            'order_id': null,
            'appointment_id': null,
            'url': 'https://glowderma.uz/aksiya',
          },
        ),
      ],
    });
    await tester.pumpWidget(
      routerApp(const NotificationsScreen(), [
        ...commonOverrides(),
        inboxApiProvider.overrideWithValue(api),
        inboxUrlOpenerProvider.overrideWithValue((u) async {
          opened.add(u);
          return true;
        }),
      ]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('T5'));
    await tester.pumpAndSettle();
    expect(opened, [Uri.parse('https://glowderma.uz/aksiya')]);
    expect(find.text('T5'), findsOneWidget);
  });

  testWidgets('empty state', (tester) async {
    await tester.pumpWidget(
      routerApp(const NotificationsScreen(), [
        ...commonOverrides(),
        inboxApiProvider.overrideWithValue(FakeInboxApi({1: []})),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hozircha xabar yo‘q'), findsOneWidget);
  });

  testWidgets('loads the next page at the end of the list', (tester) async {
    final api = FakeInboxApi({
      1: [
        for (var i = 0; i < 20; i++)
          inboxJson(100 - i, _todayAt(1), readAt: _todayAt(2)),
      ],
      2: [inboxJson(50, '2025-01-05T10:00:00+05:00', readAt: _todayAt(2))],
    });
    await tester.pumpWidget(
      routerApp(const NotificationsScreen(), [
        ...commonOverrides(),
        inboxApiProvider.overrideWithValue(api),
      ]),
    );
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('T50'),
      find.byType(ListView),
      const Offset(0, -400),
    );
    expect(find.text('T50'), findsOneWidget);
  });
}
