import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/features/cart/data/cart_models.dart';
import 'package:glow_derma/features/cart/presentation/cart_line_view.dart';
import 'package:glow_derma/features/cart/presentation/cart_text.dart';
import 'package:glow_derma/features/settings/data/public_settings.dart';

CartLine line({
  String status = 'ok',
  int quantity = 1,
  int available = 7,
  int maxQuantity = 7,
  bool maxReached = false,
  bool promo = false,
  bool priceChanged = false,
  int? previousPrice,
}) => CartLine.fromJson({
  'product_id': 4,
  'name': 'Seramidli namlantiruvchi krem',
  'volume': '50 ml',
  'main_image_url': null,
  'unit_price': 312000,
  'promo': promo,
  'quantity': quantity,
  'line_total': 312000 * quantity,
  'available': available,
  'max_quantity': maxQuantity,
  'max_reached': maxReached,
  'status': status,
  'price_changed': priceChanged,
  'previous_price': previousPrice,
});

Cart cart({bool hasProblems = false, List<CartLine>? items}) => Cart(
  items: items ?? [line()],
  itemCount: 1,
  quantityTotal: 1,
  itemsSubtotal: 312000,
  promoSubtotal: 0,
  hasProblems: hasProblems,
  cashbackAvailable: 0,
  maxUsablePickup: 0,
);

PublicSettings settings({
  List<String> providers = const ['click', 'payme'],
  bool sales = true,
}) => PublicSettings({
  'payment_providers': providers,
  'online_sales_enabled': sales,
  'fulfilment_methods': ['delivery', 'pickup'],
});

void main() {
  group('CartLineView.of', () {
    test(
      'ok line: active stepper, plus enabled below the limit, no notices',
      () {
        final v = CartLineView.of(line(quantity: 2));
        expect(v.inactive, isFalse);
        expect(v.showStepper, isTrue);
        expect(v.canIncrease, isTrue);
        expect(v.blockingWarning, isNull);
        expect(v.insufficientAvailable, isNull);
        expect(v.fixQuantity, isNull);
        expect(v.previousPrice, isNull);
        expect(v.showPromo, isFalse);
        expect(v.showMaxHint, isFalse);
      },
    );

    test('ok line at max_quantity: plus disabled, max hint shown', () {
      final v = CartLineView.of(line(quantity: 7, maxReached: true));
      expect(v.canIncrease, isFalse);
      expect(v.showMaxHint, isTrue);
    });

    test('out_of_stock: greyed, stepper hidden, "Tugagan" warning', () {
      final v = CartLineView.of(
        line(status: 'out_of_stock', available: 0, maxQuantity: 0),
      );
      expect(v.inactive, isTrue);
      expect(v.showStepper, isFalse);
      expect(v.canIncrease, isFalse);
      expect(v.blockingWarning, same(CartText.outOfStock));
      expect(v.blockingWarning!.uz, 'Tugagan — buyurtmaga kirmaydi');
      expect(v.showMaxHint, isFalse);
    });

    test('unavailable: greyed, "Hozir sotuvda yo‘q" warning, no price-changed caption', () {
      final v = CartLineView.of(
        line(status: 'unavailable', priceChanged: true, previousPrice: 300000),
      );
      expect(v.inactive, isTrue);
      expect(v.blockingWarning, same(CartText.unavailable));
      expect(v.previousPrice, isNull);
    });

    test('insufficient: active line, plus disabled, available caption and one-tap fix to max_quantity', () {
      final v = CartLineView.of(
        line(status: 'insufficient', quantity: 5, available: 3, maxQuantity: 3),
      );
      expect(v.inactive, isFalse);
      expect(v.showStepper, isTrue);
      expect(v.canIncrease, isFalse);
      expect(v.insufficientAvailable, 3);
      expect(v.fixQuantity, 3);
      expect(v.blockingWarning, isNull);
    });

    test('price_changed: shows the previous price', () {
      final v = CartLineView.of(
        line(priceChanged: true, previousPrice: 290000),
      );
      expect(v.previousPrice, 290000);
    });

    test('promo: badge and no-cashback note', () {
      expect(CartLineView.of(line(promo: true)).showPromo, isTrue);
    });
  });

  group('pay bar', () {
    test('enabled for a healthy cart with providers', () {
      expect(payBlockReason(cart(), settings()), isNull);
      expect(canPay(cart(), settings()), isTrue);
    });

    test('disabled while the settings are loading, without a reason', () {
      expect(payBlockReason(cart(), null), isNull);
      expect(canPay(cart(), null), isFalse);
    });

    test('has_problems blocks with the fix-problems explanation', () {
      expect(
        payBlockReason(cart(hasProblems: true), settings()),
        same(CartText.fixProblems),
      );
      expect(canPay(cart(hasProblems: true), settings()), isFalse);
    });

    test('no payment providers / online sales off block checkout', () {
      expect(
        payBlockReason(cart(), settings(providers: const [])),
        same(CartText.noPayments),
      );
      expect(
        payBlockReason(cart(), settings(sales: false)),
        same(CartText.salesOff),
      );
      expect(canPay(cart(), settings(sales: false)), isFalse);
    });

    test('an empty cart cannot be paid', () {
      expect(canPay(cart(items: const []), settings()), isFalse);
    });
  });
}
