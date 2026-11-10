import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/core/network/api_exception.dart';
import 'package:glow_derma/core/network/idempotency.dart';
import 'package:glow_derma/features/appointments/presentation/appointment_actions.dart';

void main() {
  test('withIntentKey reuses the key after a network error and drops it after an answer', () async {
    final keys = IdempotencyKeys();
    final seen = <String>[];
    Future<int> fail(int status) =>
        withIntentKey<int>(keys, 'appointment.book:1', (key) async {
          seen.add(key);
          throw ApiException(
            status: status,
            code: status == 0 ? 'network' : 'slot_taken',
            message: '',
          );
        });

    await expectLater(fail(0), throwsA(isA<ApiException>()));
    await expectLater(fail(409), throwsA(isA<ApiException>()));
    final ok = await withIntentKey<int>(keys, 'appointment.book:1', (
      key,
    ) async {
      seen.add(key);
      return 1;
    });

    expect(ok, 1);
    expect(
      seen[0],
      seen[1],
      reason: 'retried after a network error with the same key',
    );
    expect(seen[2], isNot(seen[1]), reason: 'a server answer ends the intent');
    expect(
      keys.keyFor('appointment.book:1'),
      isNot(seen[2]),
      reason: 'success ends the intent too',
    );
  });
}
