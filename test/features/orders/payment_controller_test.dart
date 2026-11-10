import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/core/network/json.dart';
import 'package:glow_derma/features/orders/application/payment_controller.dart';
import 'package:glow_derma/features/orders/data/order_models.dart';

import 'fakes.dart';

final _start = DateTime.utc(2026, 10, 23, 9, 2);

/// An order awaiting payment until [payBy] (fake clock).
OrderDetail _awaiting({
  required DateTime payBy,
  bool pay = true,
  bool inProgress = false,
}) {
  final j = orderJson(
    status: 'awaiting_payment',
    statusLabel: 'To‘lov kutilmoqda',
    paymentStatus: 'pending',
    inProgress: inProgress,
    inProgressLabel: inProgress ? 'To‘lov tekshirilmoqda' : null,
    payBy: payBy.toIso8601String(),
    pay: pay,
    cancel: true,
    reorder: false,
  );
  return detail(j);
}

OrderDetail _paid() =>
    detail(orderJson(status: 'processing', statusLabel: 'Tayyorlanmoqda'));

/// Answers the queued orders in turn, repeating the last one.
class _Server {
  _Server(this.answers);
  final List<Object> answers;
  int calls = 0;

  Future<OrderDetail> fetch() async {
    final a = answers[calls < answers.length ? calls : answers.length - 1];
    calls++;
    if (a is OrderDetail) return a;
    throw a;
  }
}

void main() {
  group('phaseOf', () {
    final payBy = _start.add(const Duration(minutes: 15));
    test('payable before pay_by', () {
      expect(phaseOf(_awaiting(payBy: payBy), _start), PaymentPhase.payable);
    });
    test('expired at pay_by or when the server says it cannot be paid', () {
      expect(phaseOf(_awaiting(payBy: payBy), payBy), PaymentPhase.expired);
      expect(
        phaseOf(_awaiting(payBy: payBy, pay: false), _start),
        PaymentPhase.expired,
      );
    });
    test('a transaction in flight is never expired', () {
      expect(
        phaseOf(
          _awaiting(payBy: payBy, pay: false, inProgress: true),
          payBy.add(const Duration(minutes: 2)),
        ),
        PaymentPhase.payable,
      );
    });
    test('paid and cancelled', () {
      expect(phaseOf(_paid(), _start), PaymentPhase.paid);
      expect(
        phaseOf(
          detail(orderJson(status: 'cancelled', paymentStatus: 'failed')),
          _start,
        ),
        PaymentPhase.cancelled,
      );
      expect(
        phaseOf(
          detail(
            orderJson(
              status: 'awaiting_payment',
              paymentStatus: 'paid',
              payBy: payBy.toIso8601String(),
            ),
          ),
          _start,
        ),
        PaymentPhase.paid,
        reason: 'payment.status paid wins',
      );
    });
  });

  group('PaymentController', () {
    test('loads, counts down and stops polling once paid', () {
      fakeAsync((async) {
        final payBy = clock.now().add(const Duration(minutes: 14, seconds: 37));
        final server = _Server([
          _awaiting(payBy: payBy),
          _awaiting(payBy: payBy),
          _awaiting(payBy: payBy),
          _paid(),
        ]);
        final c = PaymentController(fetch: server.fetch);
        c.load();
        async.flushMicrotasks();
        expect(c.phase, PaymentPhase.payable);
        expect(c.remaining, const Duration(minutes: 14, seconds: 37));

        c.startPolling();
        expect(c.polling, isTrue);
        async.elapse(const Duration(seconds: 1));
        expect(c.remaining, const Duration(minutes: 14, seconds: 36));

        async.elapse(const Duration(seconds: 4)); // polls at 2 s and 4 s
        expect(server.calls, 3);
        expect(c.phase, PaymentPhase.payable);

        async.elapse(const Duration(seconds: 2)); // poll at 6 s: paid
        expect(c.phase, PaymentPhase.paid);
        expect(c.polling, isFalse);
        final calls = server.calls;
        async.elapse(const Duration(seconds: 30));
        expect(server.calls, calls, reason: 'no more polling and no countdown');
        c.dispose();
      }, initialTime: _start);
    });

    test('gives up after 60 seconds', () {
      fakeAsync((async) {
        final payBy = clock.now().add(const Duration(minutes: 10));
        final server = _Server([_awaiting(payBy: payBy)]);
        final c = PaymentController(fetch: server.fetch);
        c.load();
        async.flushMicrotasks();
        c.startPolling();
        async.elapse(const Duration(seconds: 59));
        expect(c.polling, isTrue);
        async.elapse(const Duration(seconds: 2));
        expect(c.polling, isFalse);
        expect(server.calls, 1 + 30);
        async.elapse(const Duration(seconds: 20));
        expect(server.calls, 31);
        expect(c.phase, PaymentPhase.payable);
        c.dispose();
      }, initialTime: _start);
    });

    test('poll errors keep the order and keep polling', () {
      fakeAsync((async) {
        final payBy = clock.now().add(const Duration(minutes: 10));
        final server = _Server([
          _awaiting(payBy: payBy),
          Exception('offline'),
          _paid(),
        ]);
        final c = PaymentController(fetch: server.fetch);
        c.load();
        async.flushMicrotasks();
        c.startPolling();
        async.elapse(const Duration(seconds: 2));
        expect(c.order, isNotNull);
        expect(c.phase, PaymentPhase.payable);
        async.elapse(const Duration(seconds: 2));
        expect(c.phase, PaymentPhase.paid);
        c.dispose();
      }, initialTime: _start);
    });

    test('immediate polling reads at once', () {
      fakeAsync((async) {
        final payBy = clock.now().add(const Duration(minutes: 10));
        final server = _Server([_awaiting(payBy: payBy), _paid()]);
        final c = PaymentController(fetch: server.fetch);
        c.load();
        async.flushMicrotasks();
        c.startPolling(immediate: true);
        async.flushMicrotasks();
        expect(c.phase, PaymentPhase.paid);
        expect(c.polling, isFalse);
        c.dispose();
      }, initialTime: _start);
    });

    test('expires when the countdown ends and re-reads the order once', () {
      fakeAsync((async) {
        final payBy = clock.now().add(const Duration(seconds: 5));
        final server = _Server([_awaiting(payBy: payBy)]);
        final c = PaymentController(fetch: server.fetch);
        c.load();
        async.flushMicrotasks();
        expect(c.phase, PaymentPhase.payable);
        async.elapse(const Duration(seconds: 5));
        expect(c.remaining, Duration.zero);
        expect(c.phase, PaymentPhase.expired);
        expect(server.calls, 2, reason: 'one re-read at zero');
        async.elapse(const Duration(seconds: 30));
        expect(server.calls, 2, reason: 'only once');
        expect(c.phase, PaymentPhase.expired);
        c.dispose();
      }, initialTime: _start);
    });

    test('actions.pay false while awaiting payment is expired', () {
      fakeAsync((async) {
        final server = _Server([
          _awaiting(
            payBy: clock.now().add(const Duration(minutes: 3)),
            pay: false,
          ),
        ]);
        final c = PaymentController(fetch: server.fetch);
        c.load();
        async.flushMicrotasks();
        expect(c.phase, PaymentPhase.expired);
        c.dispose();
      }, initialTime: _start);
    });

    test(
      'in progress shows the label instead of the countdown, and stays payable',
      () {
        fakeAsync((async) {
          final payBy = clock.now().add(const Duration(seconds: 3));
          final server = _Server([_awaiting(payBy: payBy, inProgress: true)]);
          final c = PaymentController(fetch: server.fetch);
          c.load();
          async.flushMicrotasks();
          expect(c.inProgressLabel, 'To‘lov tekshirilmoqda');
          async.elapse(const Duration(seconds: 10));
          expect(
            c.phase,
            PaymentPhase.payable,
            reason: 'a transaction in flight may still complete',
          );
          c.dispose();
        }, initialTime: _start);
      },
    );

    test('a failed first load is reported; reload recovers', () {
      fakeAsync((async) {
        final server = _Server([Exception('offline'), _paid()]);
        final c = PaymentController(fetch: server.fetch);
        c.load();
        async.flushMicrotasks();
        expect(c.phase, PaymentPhase.failed);
        c.load();
        async.flushMicrotasks();
        expect(c.phase, PaymentPhase.paid);
        c.dispose();
      }, initialTime: _start);
    });

    test('replace uses the server answer (cancel)', () {
      fakeAsync((async) {
        final Json cancelled = orderJson(
          status: 'cancelled',
          statusLabel: 'Bekor qilindi',
          paymentStatus: 'failed',
        );
        final server = _Server([
          _awaiting(payBy: clock.now().add(const Duration(minutes: 3))),
        ]);
        final c = PaymentController(fetch: server.fetch);
        c.load();
        async.flushMicrotasks();
        c.startPolling();
        c.replace(detail(cancelled));
        expect(c.phase, PaymentPhase.cancelled);
        expect(c.polling, isFalse);
        c.dispose();
      }, initialTime: _start);
    });
  });
}
