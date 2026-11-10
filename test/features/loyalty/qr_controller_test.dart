import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/core/network/api_exception.dart';
import 'package:glow_derma/features/loyalty/application/qr_controller.dart';
import 'package:glow_derma/features/loyalty/data/loyalty_models.dart';

/// Hands out "GD1:t1", "GD1:t2"… and records each call.
class FakeQrSource {
  int calls = 0;
  Object? Function(int call)? failWith;
  Duration delay = Duration.zero;

  Future<QrToken> call() async {
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final failure = failWith?.call(calls);
    if (failure != null) throw failure;
    return QrToken(
      token: 'GD1:t$calls',
      expiresAt: null,
      ttlSeconds: 60,
      refreshInSeconds: 50,
    );
  }
}

void main() {
  late FakeQrSource source;
  setUp(() => source = FakeQrSource());

  QrController make(FakeAsync async) {
    final start = DateTime.utc(2026, 10, 23, 9);
    return QrController(
      fetch: source.call,
      now: () => start.add(async.elapsed),
    );
  }

  test(
    'fetches a token when shown and counts down from refresh_in_seconds',
    () {
      fakeAsync((async) {
        final qr = make(async);
        expect(qr.value.token, isNull);
        qr.setActive(true);
        async.flushMicrotasks();
        expect(source.calls, 1);
        expect(qr.value.token?.token, 'GD1:t1');
        expect(qr.value.secondsLeft, 50);
        expect(qr.value.fraction, 1);
        async.elapse(const Duration(seconds: 23));
        expect(qr.value.secondsLeft, 27);
        expect(source.calls, 1);
        qr.dispose();
      });
    },
  );

  test('refreshes automatically after refresh_in_seconds', () {
    fakeAsync((async) {
      final qr = make(async)..setActive(true);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 49));
      expect(source.calls, 1);
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(source.calls, 2);
      expect(qr.value.token?.token, 'GD1:t2');
      expect(qr.value.secondsLeft, 50);
      async.elapse(const Duration(seconds: 100));
      expect(source.calls, 4);
      qr.dispose();
    });
  });

  test(
    'pause clears the token and stops the timer; resume fetches a new one',
    () {
      fakeAsync((async) {
        final qr = make(async)..setActive(true);
        async.flushMicrotasks();
        expect(qr.value.token, isNotNull);
        qr.setActive(false);
        expect(qr.value.token, isNull);
        expect(qr.value.active, isFalse);
        async.elapse(const Duration(minutes: 5));
        expect(source.calls, 1, reason: 'no refresh while hidden');
        qr.setActive(true);
        async.flushMicrotasks();
        expect(source.calls, 2);
        expect(qr.value.token?.token, 'GD1:t2');
        qr.dispose();
      });
    },
  );

  test('an answer arriving after the screen was hidden is dropped', () {
    fakeAsync((async) {
      source.delay = const Duration(seconds: 2);
      final qr = make(async)..setActive(true);
      async.elapse(const Duration(seconds: 1));
      qr.setActive(false);
      async.elapse(const Duration(seconds: 5));
      expect(qr.value.token, isNull);
      qr.dispose();
    });
  });

  test('manual refresh is throttled to one per 10 s', () {
    fakeAsync((async) {
      final qr = make(async)..setActive(true);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 3));
      bool? accepted;
      qr.refresh().then((v) => accepted = v);
      async.flushMicrotasks();
      expect(accepted, isFalse);
      expect(source.calls, 1);
      async.elapse(const Duration(seconds: 7));
      qr.refresh().then((v) => accepted = v);
      async.flushMicrotasks();
      expect(accepted, isTrue);
      expect(source.calls, 2);
      expect(qr.value.secondsLeft, 50, reason: 'the countdown restarts');
      qr.dispose();
    });
  });

  test('429 waits retry_after seconds, then fetches again', () {
    fakeAsync((async) {
      source.failWith = (call) => call == 2
          ? const ApiException(
              status: 429,
              code: 'throttled',
              message: '',
              retryAfter: 8,
            )
          : null;
      final qr = make(async)..setActive(true);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 50));
      async.flushMicrotasks();
      expect(source.calls, 2);
      expect(qr.value.rateLimited, isTrue);
      expect(qr.value.secondsLeft, 8);
      expect(
        qr.value.token?.token,
        'GD1:t1',
        reason: 'the last code stays until the next one',
      );
      bool? accepted;
      qr.refresh().then((v) => accepted = v);
      async.flushMicrotasks();
      expect(accepted, isFalse);
      async.elapse(const Duration(seconds: 8));
      async.flushMicrotasks();
      expect(source.calls, 3);
      expect(qr.value.rateLimited, isFalse);
      expect(qr.value.token?.token, 'GD1:t3');
      qr.dispose();
    });
  });

  test('an error stops the cycle; a manual retry is not throttled', () {
    fakeAsync((async) {
      source.failWith = (call) => call == 1
          ? const ApiException(
              status: 409,
              code: 'phone_required',
              message: 'Telefon kerak',
            )
          : null;
      final qr = make(async)..setActive(true);
      async.flushMicrotasks();
      expect(qr.value.error, isA<ApiException>());
      expect(qr.value.token, isNull);
      async.elapse(const Duration(minutes: 2));
      expect(source.calls, 1);
      qr.refresh();
      async.flushMicrotasks();
      expect(source.calls, 2);
      expect(qr.value.token?.token, 'GD1:t2');
      qr.dispose();
    });
  });

  test(
    'a long 429 wait stops showing the old code once its ttl has passed',
    () {
      fakeAsync((async) {
        source.failWith = (call) => call == 2
            ? const ApiException(
                status: 429,
                code: 'throttled',
                message: '',
                retryAfter: 60,
              )
            : null;
        final qr = make(async)..setActive(true);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 50));
        async.flushMicrotasks();
        expect(qr.value.rateLimited, isTrue);
        expect(qr.value.token?.token, 'GD1:t1');
        async.elapse(const Duration(seconds: 9));
        expect(
          qr.value.token,
          isNotNull,
          reason: 'still inside ttl_seconds (60)',
        );
        async.elapse(const Duration(seconds: 1));
        expect(qr.value.token, isNull);
        expect(qr.value.rateLimited, isTrue);
        async.elapse(const Duration(seconds: 50));
        async.flushMicrotasks();
        expect(source.calls, 3);
        expect(qr.value.token?.token, 'GD1:t3');
        qr.dispose();
      });
    },
  );
}
