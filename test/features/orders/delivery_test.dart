import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/app/theme/gd_theme.dart';
import 'package:glow_derma/core/i18n/tr.dart';
import 'package:glow_derma/core/network/json.dart';
import 'package:glow_derma/core/widgets/gd_widgets.dart';
import 'package:glow_derma/features/orders/application/delivery_refresh.dart';
import 'package:glow_derma/features/orders/data/order_models.dart';
import 'package:glow_derma/features/orders/presentation/delivery_format.dart';
import 'package:glow_derma/features/orders/presentation/delivery_status_card.dart';
import 'package:glow_derma/features/orders/presentation/order_detail_screen.dart';
import 'package:glow_derma/features/orders/presentation/order_widgets.dart';
import 'package:glow_derma/features/orders/presentation/orders_screen.dart';

import 'fakes.dart';

/// `delivery` of an Express order right after checkout (local backend).
const _afterCheckout = {
  'provider': 'yandex',
  'method': 'express',
  'method_label': 'Ekspress',
  'stage': null,
  'stage_label': null,
  'eta_from': '2026-11-17T20:48:31+05:00',
  'eta_to': '2026-11-17T21:48:31+05:00',
  'courier_name': null,
  'courier_vehicle': null,
  'tracking_url': null,
};

/// The same order while a courier carries it (local backend, fake Yandex).
Json _inTransit({String stage = 'in_transit', String label = 'Yo‘lda'}) => {
  ..._afterCheckout,
  'stage': stage,
  'stage_label': label,
  'courier_name': 'Fake Kuryer',
  'courier_vehicle': 'Chevrolet Cobalt oq 01A777AA',
  'tracking_url': 'https://tracking.fake-yandex.invalid/abc',
};

/// Order №10248 sent with Yandex instead of BTS.
Json _yandexOrder({
  Json delivery = const {},
  String status = 'processing',
  String statusLabel = 'Tayyorlanmoqda',
  List<Json>? timeline,
  List<Json>? progress,
}) => {
  ...orderJson(
    status: status,
    statusLabel: statusLabel,
    timeline: timeline,
    progress: progress,
  ),
  'tracking_number': null,
  'delivery': delivery.isEmpty ? _inTransit() : delivery,
  'shipment': {
    'carrier': 'Yandex',
    'tracking_number': '',
    'tracking_url': null,
  },
};

Finder _byId(String id) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.identifier == id,
);

void main() {
  group('OrderDelivery', () {
    test('parses the delivery of an order right after checkout', () {
      final d = OrderDelivery.fromJson(_afterCheckout);
      expect(d.isYandex, isTrue);
      expect(d.method, 'express');
      expect(d.methodLabel, 'Ekspress');
      expect(d.stage, isNull);
      expect(d.stageLabel, isNull);
      expect(d.etaFrom, DateTime.parse('2026-11-17T15:48:31Z'));
      expect(d.etaTo, DateTime.parse('2026-11-17T16:48:31Z'));
      expect(d.courierLine, isNull);
      expect(d.trackingUrl, isNull);
      expect(d.etaShown, isTrue);
      expect(d.isFinished, isFalse);
    });

    test('parses a parcel in transit', () {
      final d = OrderDelivery.fromJson(_inTransit());
      expect(d.stage, ShipmentStage.inTransit);
      expect(d.stageLabel, 'Yo‘lda');
      expect(d.courierLine, 'Fake Kuryer · Chevrolet Cobalt oq 01A777AA');
      expect(d.trackingUrl, 'https://tracking.fake-yandex.invalid/abc');
    });

    test('drops a tracking link that is not https', () {
      final d = OrderDelivery.fromJson({
        ..._inTransit(),
        'tracking_url': 'http://tracking.example.com/x',
      });
      expect(d.trackingUrl, isNull);
    });

    test('OrderSummary and OrderDetail carry it', () {
      final order = OrderDetail.fromJson(_yandexOrder());
      expect(order.delivery?.isYandex, isTrue);
      expect(OrderDetail.fromJson(orderJson()).delivery, isNull);
    });
  });

  test('stage tones', () {
    expect(stageTone('delivered'), GdTone.success);
    expect(stageTone('returning'), GdTone.warning);
    expect(stageTone('returned'), GdTone.warning);
    expect(stageTone('failed'), GdTone.warning);
    expect(stageTone('cancelled'), GdTone.neutral);
    expect(stageTone('in_transit'), GdTone.gold);
    expect(stageTone('courier_requested'), GdTone.gold);
    expect(stageTone(null), GdTone.gold);
  });

  test('timeline alert tones', () {
    expect(timelineAlertTone('delivery_failed'), GdTone.danger);
    expect(timelineAlertTone('shipment_returned'), GdTone.warning);
    expect(timelineAlertTone('shipment_created'), isNull);
  });

  group('formatEtaWindow', () {
    final now = DateTime.parse('2026-11-17T12:00:00+05:00');
    DateTime at(String s) => DateTime.parse(s);

    test('today, tomorrow and another day (Tashkent time)', () {
      expect(
        formatEtaWindow(
          at('2026-11-17T20:48:31+05:00'),
          at('2026-11-17T21:48:31+05:00'),
          AppLanguage.uz,
          now: now,
        ),
        'Bugun, 20:48–21:48',
      );
      expect(
        formatEtaWindow(
          at('2026-11-18T09:30:00Z'),
          at('2026-11-18T11:00:00Z'),
          AppLanguage.ru,
          now: now,
        ),
        'Завтра, 14:30–16:00',
      );
      expect(
        formatEtaWindow(
          at('2026-10-23T14:30:00+05:00'),
          at('2026-10-23T16:00:00+05:00'),
          AppLanguage.uz,
          now: now,
        ),
        '23-oktabr, 14:30–16:00',
      );
      expect(
        formatEtaWindow(
          at('2026-11-23T14:30:00+05:00'),
          at('2026-11-23T16:00:00+05:00'),
          AppLanguage.en,
          now: now,
        ),
        '23 November, 14:30–16:00',
      );
    });

    test('a window over midnight, a single instant, no window', () {
      expect(
        formatEtaWindow(
          at('2026-11-17T22:00:00+05:00'),
          at('2026-11-18T01:00:00+05:00'),
          AppLanguage.uz,
          now: now,
        ),
        'Bugun, 22:00 – Ertaga, 01:00',
      );
      expect(
        formatEtaWindow(
          at('2026-11-17T20:00:00+05:00'),
          null,
          AppLanguage.uz,
          now: now,
        ),
        'Bugun, 20:00',
      );
      expect(formatEtaWindow(null, null, AppLanguage.uz, now: now), isNull);
    });

    test('the Tashkent day, whatever the UTC day', () {
      // 19:30 UTC is 00:30 the next day in Tashkent.
      expect(
        formatEtaWindow(
          at('2026-11-17T19:30:00Z'),
          at('2026-11-17T20:00:00Z'),
          AppLanguage.uz,
          now: now,
        ),
        'Ertaga, 00:30–01:00',
      );
    });
  });

  group('shouldRefreshDelivery', () {
    OrderDetail order(Json delivery, {String status = 'processing'}) =>
        OrderDetail.fromJson(_yandexOrder(delivery: delivery, status: status));

    test('a live Yandex stage of an order on its way', () {
      expect(shouldRefreshDelivery(order(_inTransit())), isTrue);
      expect(
        shouldRefreshDelivery(order(_inTransit(), status: 'handed_to_courier')),
        isTrue,
      );
    });

    test('not before dispatch, not once finished, not for BTS', () {
      expect(shouldRefreshDelivery(order(_afterCheckout)), isFalse);
      for (final stage in ['delivered', 'cancelled', 'returned']) {
        expect(
          shouldRefreshDelivery(order(_inTransit(stage: stage))),
          isFalse,
          reason: stage,
        );
      }
      expect(
        shouldRefreshDelivery(order(_inTransit(), status: 'delivered')),
        isFalse,
      );
      expect(
        shouldRefreshDelivery(order(_inTransit(), status: 'awaiting_payment')),
        isFalse,
      );
      expect(shouldRefreshDelivery(OrderDetail.fromJson(orderJson())), isFalse);
    });
  });

  group('DeliveryRefresher', () {
    test('refreshes every 30 s and stops when the parcel is done', () {
      fakeAsync((async) {
        var calls = 0;
        final r = DeliveryRefresher(onRefresh: () => calls++);
        r.update(live: true, visible: true);
        r.update(live: true, visible: true); // no second timer
        async.elapse(const Duration(seconds: 29));
        expect(calls, 0);
        async.elapse(const Duration(seconds: 1));
        expect(calls, 1);
        async.elapse(const Duration(seconds: 60));
        expect(calls, 3);
        r.update(live: false, visible: true);
        expect(r.active, isFalse);
        async.elapse(const Duration(minutes: 5));
        expect(calls, 3);
        r.dispose();
      });
    });

    test('pauses in the background and refreshes once on resume', () {
      fakeAsync((async) {
        var calls = 0;
        final r = DeliveryRefresher(onRefresh: () => calls++);
        r.update(live: true, visible: true);
        async.elapse(const Duration(seconds: 10));
        r.update(live: true, visible: false);
        async.elapse(const Duration(minutes: 5));
        expect(calls, 0);
        r.update(live: true, visible: true);
        expect(calls, 1);
        async.elapse(const Duration(seconds: 30));
        expect(calls, 2);
        r.dispose();
        async.elapse(const Duration(minutes: 1));
        expect(calls, 2);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('never starts for an order that is not live', () {
      fakeAsync((async) {
        var calls = 0;
        final r = DeliveryRefresher(onRefresh: () => calls++);
        r.update(live: false, visible: true);
        async.elapse(const Duration(minutes: 2));
        expect(calls, 0);
        expect(async.pendingTimers, isEmpty);
      });
    });
  });

  test('orders list line for a Yandex order on its way', () {
    OrderSummary summary(Json delivery, {String status = 'processing'}) =>
        OrderSummary.fromJson(_yandexOrder(delivery: delivery, status: status));
    expect(deliveryLine(summary(_inTransit())), 'Ekspress · Yo‘lda');
    expect(deliveryLine(summary(_afterCheckout)), isNull);
    expect(deliveryLine(summary(_inTransit(), status: 'delivered')), isNull);
    expect(deliveryLine(OrderSummary.fromJson(orderJson())), isNull);
  });

  test('the BTS hint is for BTS orders only', () {
    final step = ProgressStep.fromJson({
      'step': 'delivered',
      'label': 'Yetkazildi',
      'state': 'current',
    });
    expect(openStepHint(detail(orderJson()), step), isNotNull);
    expect(openStepHint(OrderDetail.fromJson(_yandexOrder()), step), isNull);
  });

  group('DeliveryStatusCard on the order screen', () {
    testWidgets('a Yandex parcel: method, stage, eta, courier, tracking', (
      tester,
    ) async {
      final opened = <Uri>[];
      final order = OrderDetail.fromJson(
        _yandexOrder(
          delivery: {
            ..._inTransit(),
            'eta_from': DateTime.now()
                .add(const Duration(hours: 1))
                .toUtc()
                .toIso8601String(),
            'eta_to': DateTime.now()
                .add(const Duration(hours: 2))
                .toUtc()
                .toIso8601String(),
          },
        ),
      );
      final api = FakeOrdersApi(details: {10248: order});
      await pumpScreen(
        tester,
        const OrderDetailScreen(orderId: 10248),
        api,
        overrides: [
          trackingOpenerProvider.overrideWithValue((url) async {
            opened.add(url);
            return true;
          }),
        ],
      );
      await tester.pump();

      expect(_byId('order.delivery'), findsOneWidget);
      expect(find.text('Usul'), findsOneWidget);
      expect(find.text('Yandex · Ekspress'), findsOneWidget);
      expect(find.text('Holat'), findsOneWidget);
      // The chip, and the current step's subtitle.
      expect(find.text('Yo‘lda'), findsNWidgets(2));
      expect(find.text('Kutilayotgan vaqt'), findsOneWidget);
      expect(
        find.text(
          formatEtaWindow(
            order.delivery!.etaFrom,
            order.delivery!.etaTo,
            AppLanguage.uz,
            now: DateTime.now(),
          )!,
        ),
        findsOneWidget,
      );
      expect(find.text('Kuryer'), findsOneWidget);
      expect(
        find.text('Fake Kuryer · Chevrolet Cobalt oq 01A777AA'),
        findsOneWidget,
      );
      expect(find.text('Holat avtomatik yangilanadi'), findsOneWidget);
      // The BTS line is not shown for Yandex.
      expect(find.textContaining('48213907'), findsNothing);
      expect(find.text('BTS tasdiqlagach yangilanadi'), findsNothing);

      await tester.tap(_byId('order.delivery.track'));
      await tester.pump();
      expect(opened, [Uri.parse('https://tracking.fake-yandex.invalid/abc')]);
    });

    testWidgets('right after checkout: no stage row, no tracking, no live', (
      tester,
    ) async {
      final api = FakeOrdersApi(
        details: {
          10248: OrderDetail.fromJson(_yandexOrder(delivery: _afterCheckout)),
        },
      );
      await pumpScreen(tester, const OrderDetailScreen(orderId: 10248), api);
      await tester.pump();
      expect(find.text('Yandex · Ekspress'), findsOneWidget);
      expect(find.text('Holat'), findsNothing);
      expect(find.text('Kuryer'), findsNothing);
      expect(_byId('order.delivery.track'), findsNothing);
      expect(find.text('Holat avtomatik yangilanadi'), findsNothing);
    });

    testWidgets('a finished stage hides tracking and the eta', (tester) async {
      final api = FakeOrdersApi(
        details: {
          10248: OrderDetail.fromJson(
            _yandexOrder(
              status: 'delivered',
              statusLabel: 'Yetkazildi',
              delivery: _inTransit(stage: 'delivered', label: 'Yetkazildi'),
            ),
          ),
        },
      );
      await pumpScreen(tester, const OrderDetailScreen(orderId: 10248), api);
      await tester.pump();
      expect(_byId('order.delivery'), findsOneWidget);
      expect(_byId('order.delivery.track'), findsNothing);
      expect(find.text('Kutilayotgan vaqt'), findsNothing);
      expect(find.text('Holat avtomatik yangilanadi'), findsNothing);
    });

    testWidgets('a BTS order keeps the tracking line', (tester) async {
      final api = FakeOrdersApi(details: {10248: detail(orderJson())});
      await pumpScreen(tester, const OrderDetailScreen(orderId: 10248), api);
      await tester.pump();
      expect(find.text('BTS · 48213907'), findsOneWidget);
      expect(_byId('order.delivery'), findsNothing);
    });

    testWidgets('Yandex: the shipment_created entry stays in History', (
      tester,
    ) async {
      final api = FakeOrdersApi(
        details: {
          10248: OrderDetail.fromJson(
            _yandexOrder(
              delivery: _inTransit(
                stage: 'failed',
                label: 'Kuryer qayta chaqiriladi',
              ),
              progress: [
                {
                  'step': 'placed',
                  'label': 'Buyurtma berildi',
                  'state': 'done',
                },
                {
                  'step': 'paid',
                  'label': 'To‘lov qabul qilindi',
                  'state': 'done',
                },
                {
                  'step': 'with_courier',
                  'label': 'Kuryerda',
                  'state': 'current',
                },
                {
                  'step': 'delivered',
                  'label': 'Yetkazildi',
                  'state': 'upcoming',
                },
              ],
              timeline: [
                {
                  'type': 'delivery_failed',
                  'at': '2026-10-23T15:00:00+05:00',
                  'title': 'Yetkazib bo‘lmadi',
                  'subtitle': 'Buyurtma do‘konga qaytariladi, biz siz bilan bog‘lanamiz',
                },
                {
                  'type': 'shipment_created',
                  'at': '2026-10-23T14:06:00+05:00',
                  'title': 'Yetkazib berish rasmiylashtirildi',
                  'subtitle': 'Yandex Dostavka',
                },
                {
                  'type': 'payment_confirmed',
                  'at': '2026-10-23T14:05:00+05:00',
                  'title': 'To‘lov qabul qilindi',
                },
              ],
            ),
          ),
        },
      );
      await pumpScreen(
        tester,
        const OrderDetailScreen(orderId: 10248),
        api,
        height: 2400,
      );
      await tester.pump();
      expect(find.text('Yetkazib berish rasmiylashtirildi'), findsOneWidget);
      expect(find.text('BTS tasdiqlagach yangilanadi'), findsNothing);
      // The current courier step reads the stage (chip + step subtitle).
      expect(find.text('Kuryer qayta chaqiriladi'), findsNWidgets(2));
      final failedDot = tester.widget<Container>(
        find.byKey(const ValueKey('timeline.dot.delivery_failed')),
      );
      final created = tester.widget<Container>(
        find.byKey(const ValueKey('timeline.dot.shipment_created')),
      );
      expect(
        (failedDot.decoration! as BoxDecoration).color,
        isNot((created.decoration! as BoxDecoration).color),
      );
    });

    testWidgets('re-reads the order every 30 s until the parcel is done', (
      tester,
    ) async {
      final api = FakeOrdersApi(
        details: {10248: OrderDetail.fromJson(_yandexOrder())},
      );
      await pumpScreen(tester, const OrderDetailScreen(orderId: 10248), api);
      await tester.pump();
      expect(api.detailCalls, hasLength(1));

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(api.detailCalls, hasLength(2));
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(api.detailCalls, hasLength(3));

      api.details[10248] = OrderDetail.fromJson(
        _yandexOrder(
          status: 'delivered',
          statusLabel: 'Yetkazildi',
          delivery: _inTransit(stage: 'delivered', label: 'Yetkazildi'),
        ),
      );
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(api.detailCalls, hasLength(4));
      expect(find.text('Holat avtomatik yangilanadi'), findsNothing);

      await tester.pump(const Duration(minutes: 3));
      expect(api.detailCalls, hasLength(4));
    });

    testWidgets('pauses in the background, refreshes once on resume', (
      tester,
    ) async {
      final api = FakeOrdersApi(
        details: {10248: OrderDetail.fromJson(_yandexOrder())},
      );
      await pumpScreen(tester, const OrderDetailScreen(orderId: 10248), api);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 2));
      expect(api.detailCalls, hasLength(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(api.detailCalls, hasLength(2));
    });
  });

  testWidgets('orders list shows the courier stage', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: OrderCard(
            order: OrderSummary.fromJson(_yandexOrder()),
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.text('Ekspress · Yo‘lda'), findsOneWidget);
    expect(find.byIcon(Icons.local_shipping_outlined), findsOneWidget);
  });
}
