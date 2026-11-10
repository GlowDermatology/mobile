import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// One `Idempotency-Key` per user intent (contract §1.7): created on the first
/// tap, reused when the same intent is retried after a network error, dropped
/// after any answer so the next intent gets a new key.
class IdempotencyKeys {
  final _keys = <String, String>{};

  String keyFor(String intent) => _keys.putIfAbsent(intent, () => _uuid.v4());

  void done(String intent) => _keys.remove(intent);
}
