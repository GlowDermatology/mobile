import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/features/checkout/data/checkout_api.dart';
import 'package:glow_derma/features/checkout/presentation/address_form_screen.dart';

void main() {
  group('buildCalculateBody', () {
    test('delivery sends the address and the whole available cashback when switched on', () {
      expect(
        buildCalculateBody(
          fulfilment: 'delivery',
          addressId: 12,
          useCashback: true,
          cashbackAvailable: 48600,
        ),
        {'fulfilment': 'delivery', 'address_id': 12, 'cashback_to_use': 48600},
      );
    });

    test('pickup never sends an address; switch off sends 0', () {
      expect(
        buildCalculateBody(
          fulfilment: 'pickup',
          addressId: 12,
          useCashback: false,
          cashbackAvailable: 48600,
        ),
        {'fulfilment': 'pickup', 'address_id': null, 'cashback_to_use': 0},
      );
    });

    test('a negative balance is never sent', () {
      expect(
        buildCalculateBody(
          fulfilment: 'pickup',
          addressId: null,
          useCashback: true,
          cashbackAvailable: -500,
        )['cashback_to_use'],
        0,
      );
    });
  });

  group('DeliveryQuote', () {
    test('parses the delivery answer and remembers the address', () {
      final q = DeliveryQuote.fromJson({
        'fulfilment': 'delivery',
        'delivery_fee': 25000,
        'region_code': '10',
        'city_code': '1001',
        'pickup_address': null,
        'items_subtotal': 808000,
        'cashback_max': 48600,
        'cashback_to_use': 48600,
        'expected_total': 784400,
      }, addressId: 12);
      expect(q.deliveryFee, 25000);
      expect(q.itemsSubtotal, 808000);
      expect(q.cashbackMax, 48600);
      expect(q.cashbackToUse, 48600);
      expect(q.expectedTotal, 784400);
      expect(q.addressId, 12);
      expect(q.pickupAddress, isNull);
    });
  });

  group('buildCheckoutBody', () {
    const delivery = DeliveryQuote(
      fulfilment: 'delivery',
      deliveryFee: 25000,
      pickupAddress: null,
      itemsSubtotal: 808000,
      cashbackMax: 48600,
      cashbackToUse: 48600,
      expectedTotal: 784400,
      addressId: 12,
    );

    test('copies cashback and total unchanged from the quote, first provider, trimmed note', () {
      expect(
        buildCheckoutBody(
          quote: delivery,
          paymentProviders: const ['click', 'payme'],
          note: '  Soat 18:00 dan keyin ',
        ),
        {
          'fulfilment': 'delivery',
          'address_id': 12,
          'payment_provider': 'click',
          'cashback_to_use': 48600,
          'expected_total': 784400,
          'customer_note': 'Soat 18:00 dan keyin',
        },
      );
    });

    test('pickup sends a null address', () {
      const pickup = DeliveryQuote(
        fulfilment: 'pickup',
        deliveryFee: 0,
        pickupAddress: 'Toshkent',
        itemsSubtotal: 808000,
        cashbackMax: 48600,
        cashbackToUse: 0,
        expectedTotal: 808000,
        addressId: 12,
      );
      final body = buildCheckoutBody(
        quote: pickup,
        paymentProviders: const ['payme'],
        note: '',
      );
      expect(body['address_id'], isNull);
      expect(body['payment_provider'], 'payme');
      expect(body['expected_total'], 808000);
      expect(body['cashback_to_use'], 0);
      expect(body['customer_note'], '');
    });
  });

  test('StockProblem.listFrom reads OUT_OF_STOCK details', () {
    final lines = StockProblem.listFrom({
      'lines': [
        {
          'product_id': 9,
          'name': 'Niatsinamidli toner',
          'requested': 2,
          'available': 0,
          'status': 'out_of_stock',
        },
        {
          'product_id': 3,
          'name': 'Ko‘pik',
          'requested': 5,
          'available': 3,
          'status': 'insufficient',
        },
      ],
    });
    expect(lines, hasLength(2));
    expect(lines.first.name, 'Niatsinamidli toner');
    expect(lines.last.requested, 5);
    expect(lines.last.available, 3);
    expect(StockProblem.listFrom(const {}), isEmpty);
  });

  test('validateAddressText enforces 5..300 characters', () {
    expect(validateAddressText('abc'), isNotNull);
    expect(validateAddressText('   abcd   '), isNotNull);
    expect(validateAddressText('Chilonzor 9'), isNull);
    expect(validateAddressText('x' * 301), isNotNull);
  });
}
