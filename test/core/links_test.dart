import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/core/links/deep_links.dart';
import 'package:glow_derma/core/push/push_service.dart';

void main() {
  test('payment return links open the payment screen in polling mode', () {
    expect(
      locationForLink(
        Uri.parse('https://glowderma.uz/pay/return?order_id=10248'),
      ),
      '/pay/10248?returned=1',
    );
    expect(
      locationForLink(
        Uri.parse('https://staging.glowderma.uz/pay/return?order_id=7'),
      ),
      '/pay/7?returned=1',
    );
    expect(
      locationForLink(Uri.parse('glowderma://payment/return?order_id=10248')),
      '/pay/10248?returned=1',
    );
  });

  test('foreign hosts, other paths and junk ids are ignored or neutral', () {
    expect(
      locationForLink(Uri.parse('https://evil.example/pay/return?order_id=1')),
      isNull,
    );
    expect(locationForLink(Uri.parse('https://glowderma.uz/katalog')), isNull);
    expect(
      locationForLink(Uri.parse('http://glowderma.uz/pay/return?order_id=1')),
      isNull,
    );
    expect(
      locationForLink(Uri.parse('glowderma://payment/return?order_id=../../x')),
      '/orders',
    );
  });

  test('push data (all values strings) maps to screens', () {
    expect(
      locationForPush({
        'type': 'order_status',
        'inbox_id': '901',
        'order_id': '10248',
        'status': 'handed_to_courier',
      }),
      '/orders/10248',
    );
    expect(
      locationForPush({
        'type': 'appointment',
        'inbox_id': '1',
        'appointment_id': '41',
        'action': 'confirmed',
      }),
      '/appointments/41',
    );
    expect(
      locationForPush({
        'type': 'campaign',
        'inbox_id': '1',
        'campaign_id': '3',
        'product_id': '4',
        'link_url': '',
      }),
      '/product/4',
    );
    expect(
      locationForPush({
        'type': 'campaign',
        'inbox_id': '1',
        'campaign_id': '3',
        'product_id': '',
        'link_url': '',
      }),
      '/notifications',
    );
    expect(
      locationForPush({
        'type': 'account_security',
        'inbox_id': '1',
        'event': 'password_reset',
        'provider': '',
      }),
      '/notifications',
    );
  });
}
