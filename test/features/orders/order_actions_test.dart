import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/core/network/api_exception.dart';
import 'package:glow_derma/core/network/idempotency.dart';
import 'package:glow_derma/features/orders/presentation/order_actions.dart';

ApiException _err(int status) => ApiException(
  status: status,
  code: status == 0 ? 'network' : 'x',
  message: '',
);

void main() {
  test('withKey: one key per intent', () async {
    final keys = IdempotencyKeys();
    final seen = <String>[];

    Future<void> run(String intent, ApiException? error) async {
      try {
        await withKey<void>(keys, intent, (k) async {
          seen.add(k);
          if (error != null) throw error;
        });
      } on ApiException {
        // expected
      }
    }

    await run('pay.1.click', _err(0)); // network error: key kept
    await run('pay.1.click', _err(409)); // server answer: key dropped
    await run('pay.1.click', null); // new intent attempt
    await run('pay.1.payme', null); // another provider, another key

    expect(seen[0], seen[1]);
    expect(seen[2], isNot(seen[1]));
    expect(seen[3], isNot(seen[2]));
    expect(
      keys.keyFor('pay.1.click'),
      isNot(seen[2]),
      reason: 'done() after success',
    );
  });
}
