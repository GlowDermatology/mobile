import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/features/loyalty/data/loyalty_models.dart';

void main() {
  test('LedgerItem.fromJson', () {
    final item = LedgerItem.fromJson({
      'id': 121,
      'at': '2026-10-23T14:05:00+05:00',
      'kind': 'credit',
      'amount': 5680,
      'balance_after': 48600,
      'title': 'Cashback hisoblandi',
      'subtitle': 'Buyurtma №10248 · 1%',
      'order_id': 10248,
      'source': 'online',
    });
    expect(item.id, 121);
    expect(item.at, DateTime.utc(2026, 10, 23, 9, 5));
    expect(item.amount, 5680);
    expect(item.orderId, 10248);
    expect(item.isStore, isFalse);
    expect(item.isDebit, isFalse);
  });

  test('LedgerItem tolerates nulls', () {
    final item = LedgerItem.fromJson({
      'id': 1,
      'kind': 'adjustment',
      'amount': -100,
      'subtitle': null,
      'order_id': null,
      'source': 'admin',
    });
    expect(item.subtitle, isNull);
    expect(item.orderId, isNull);
    expect(item.at, isNull);
  });

  test('QrToken.fromJson', () {
    final t = QrToken.fromJson({
      'token': 'GD1:abc',
      'expires_at': '2026-10-26T12:01:00+05:00',
      'ttl_seconds': 60,
      'refresh_in_seconds': 50,
    });
    expect(t.token, 'GD1:abc');
    expect(t.refreshInSeconds, 50);
    expect(t.expiresAt, DateTime.utc(2026, 10, 26, 7, 1));
  });

  test('percentText', () {
    expect(percentText('1.00'), '1');
    expect(percentText('1.50'), '1,5');
    expect(percentText('0.57'), '0,57');
    expect(percentText('2.50', english: true), '2.5');
    expect(percentText(null), '0');
  });
}
