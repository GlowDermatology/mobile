import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/core/i18n/tr.dart';
import 'package:glow_derma/features/orders/data/order_models.dart';
import 'package:glow_derma/features/orders/presentation/order_widgets.dart';

import 'fakes.dart';

void main() {
  group('OrderDetail.fromJson', () {
    test('parses the contract example', () {
      final o = detail(orderJson());
      expect(o.id, 10248);
      expect(o.status, OrderStatus.handedToCourier);
      expect(o.statusLabel, 'Kuryerga topshirildi');
      expect(o.previewImages, [
        'https://example.com/a.webp',
      ], reason: 'nulls are skipped');
      expect(o.items, hasLength(3));
      expect(o.items.last.promo, isTrue);
      expect(o.items[1].quantity, 2);
      expect(o.itemsSubtotal, 808000);
      expect(o.deliveryFee, 25000);
      expect(o.cashbackUsed, 48600);
      expect(o.payment.provider, 'click');
      expect(o.payment.isPaid, isTrue);
      expect(o.payment.confirmedAt, DateTime.utc(2026, 10, 23, 9, 5));
      expect(o.shipment!.display, 'BTS · 48213907');
      expect(o.cashback.earned, 5680);
      expect(o.cashback.showEarned, isTrue);
      expect(o.progress.map((s) => s.state), [
        ProgressState.done,
        ProgressState.done,
        ProgressState.done,
        ProgressState.current,
      ]);
      expect(o.timeline.first.type, 'handed_to_courier');
      expect(o.actions.reorder, isTrue);
      expect(o.actions.pay, isFalse);
      expect(o.isPaid, isTrue);
      expect(o.payable, 784400);
    });

    test('tolerates nulls and missing objects', () {
      final o = OrderDetail.fromJson(const {
        'id': 1,
        'status': 'cancelled',
        'cancellation': {
          'reason': 'reservation_expired',
          'label': 'To‘lov muddati tugadi',
        },
      });
      expect(o.payment.status, '');
      expect(o.shipment, isNull);
      expect(o.refund, isNull);
      expect(o.cashback.showEarned, isFalse);
      expect(o.actions.pay, isFalse);
      expect(o.isCancelled, isTrue);
      expect(o.cancellation!.expired, isTrue);
    });

    test('earned_state none hides the earned cashback', () {
      expect(
        detail(orderJson(earned: 100, earnedState: 'none')).cashback.showEarned,
        isFalse,
      );
      expect(
        detail(orderJson(earned: 100, earnedState: 'reversed'))
            .cashback
            .reversed,
        isTrue,
      );
    });
  });

  test('providerName', () {
    expect(providerName('click'), 'Click');
    expect(providerName('payme'), 'Payme');
    expect(providerName(null), '');
    expect(providerName('uzum'), 'Uzum');
  });

  group('list card route', () {
    final now = DateTime.now();
    test('awaiting payment with time left opens the pay screen', () {
      final o = OrderSummary.fromJson(awaitingJson());
      expect(o.routeAt(now), '/pay/10248');
    });
    test('expired or paid orders open the detail', () {
      final expired = OrderSummary.fromJson(
        awaitingJson(left: const Duration(minutes: -1)),
      );
      expect(expired.routeAt(now), '/orders/10248');
      expect(OrderSummary.fromJson(orderJson()).routeAt(now), '/orders/10248');
    });
  });

  group('timeline', () {
    final o = detail(orderJson());
    test('each step finds its entry', () {
      expect(timelineFor(o.progress[0], o.timeline)!.type, 'order_created');
      expect(timelineFor(o.progress[1], o.timeline)!.type, 'payment_confirmed');
      expect(timelineFor(o.progress[2], o.timeline)!.type, 'handed_to_courier');
      expect(timelineFor(o.progress[3], o.timeline), isNull);
    });

    test('entries no step tells are kept for the history', () {
      expect(extraTimeline(o.progress, o.timeline).map((e) => e.type), [
        'shipment_created',
      ]);
    });

    test('step subtitle joins the Tashkent time and the entry subtitle', () {
      expect(
        stepSubtitle(o.progress[1], o.timeline, AppLanguage.uz),
        '23-oktabr, 14:05 · Click orqali · cashback +5 680 so‘m',
      );
      expect(
        stepSubtitle(o.progress[2], o.timeline, AppLanguage.uz),
        '23-oktabr, 16:40 · BTS',
      );
      expect(stepSubtitle(o.progress[3], o.timeline, AppLanguage.uz), '');
    });
  });
}
