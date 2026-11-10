import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/core/format/money.dart';
import 'package:glow_derma/features/cart/application/cart_controller.dart';
import 'package:glow_derma/features/cart/data/cart_models.dart';
import 'package:glow_derma/features/catalog/data/catalog_models.dart';
import 'package:glow_derma/features/catalog/presentation/product_screen.dart';
import 'package:glow_derma/features/catalog/presentation/widgets/product_card_tile.dart';
import 'package:glow_derma/features/loyalty/data/cashback_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'catalog_models_test.dart' show cardJson;
import 'fakes.dart';

Widget tile(ProductCard p) => Center(
  child: SizedBox(width: 180, height: 320, child: ProductCardTile(product: p)),
);

ProductDetail detail({
  bool promo = false,
  int maxQuantity = 10,
  String ingredients = 'Aqua',
}) => ProductDetail.fromJson({
  ...cardJson(promo: promo),
  'main_image_url': null,
  'description': 'Gialuron kislotasining uch xil molekulasi',
  'ingredients': ingredients,
  'usage': '',
  'images': <Object>[],
  'max_quantity': maxQuantity,
});

void main() {
  group('ProductCardTile', () {
    testWidgets('price pill when not in the cart', (tester) async {
      final p = ProductCard.fromJson(
        cardJson(promo: true)..['main_image_url'] = null,
      );
      await tester.pumpWidget(testApp(tile(p), baseOverrides()));
      await tester.pumpAndSettle();
      expect(find.text(formatMoney(185000)), findsOneWidget);
      expect(find.text('AKSIYA'), findsOneWidget);
      expect(find.text('Gialuron kislotali serum'), findsOneWidget);
      expect(find.text('30 ml · Serumlar'), findsOneWidget);
      expect(find.byType(WideStepper), findsNothing);
    });

    testWidgets(
      'stepper with the cart quantity, minus sets an absolute quantity',
      (tester) async {
        final p = ProductCard.fromJson(cardJson()..['main_image_url'] = null);
        await tester.pumpWidget(
          testApp(tile(p), baseOverrides(cart: cartWith(1, 2))),
        );
        await tester.pumpAndSettle();
        expect(find.byType(WideStepper), findsOneWidget);
        expect(find.text('2'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.remove));
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ProductCardTile)),
        );
        final cart = container.read(cartProvider.notifier) as FakeCart;
        expect(cart.calls, [(1, 1)]);
        expect(find.text('1'), findsOneWidget);
      },
    );

    testWidgets('a loaded cart wins over a stale in_cart_quantity', (
      tester,
    ) async {
      final p = ProductCard.fromJson(
        cardJson(inCart: 3)..['main_image_url'] = null,
      );
      await tester.pumpWidget(testApp(tile(p), baseOverrides()));
      await tester.pumpAndSettle();
      expect(find.byType(WideStepper), findsNothing);
    });

    testWidgets('out of stock shows Tugagan', (tester) async {
      final p = ProductCard.fromJson(
        cardJson(stock: 'out_of_stock', available: 0)
          ..['main_image_url'] = null,
      );
      await tester.pumpWidget(testApp(tile(p), baseOverrides()));
      await tester.pumpAndSettle();
      expect(find.text('Tugagan'), findsOneWidget);
      expect(find.text(formatMoney(185000)), findsNothing);
    });

    testWidgets('online sales off: price only, no add button', (tester) async {
      final p = ProductCard.fromJson(cardJson()..['main_image_url'] = null);
      await tester.pumpWidget(
        testApp(
          tile(p),
          baseOverrides(salesEnabled: false, cart: cartWith(1, 2)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(formatMoney(185000)), findsOneWidget);
      expect(find.byType(WideStepper), findsNothing);
    });
  });

  group('ProductScreen', () {
    List<Override> overrides(
      ProductDetail d, {
      bool signedIn = true,
      bool inCart = false,
    }) => [
      ...baseOverrides(
        signedIn: signedIn,
        api: FakeCatalogApi(detail: d),
        cart: inCart ? cartWith(1, 1) : Cart.empty,
      ),
      cashbackSummaryProvider.overrideWith(
        (ref) async => signedIn
            ? const CashbackSummary({
                'tier': {'percent': '1.00'},
              })
            : null,
      ),
    ];

    Future<void> pump(WidgetTester tester, List<Override> o) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(testApp(const ProductScreen(id: 1), o));
      await tester.pumpAndSettle();
    }

    testWidgets('signed in, regular product: cashback chip, tabs, add button', (
      tester,
    ) async {
      await pump(tester, overrides(detail()));
      expect(find.text('Gialuron kislotali serum'), findsOneWidget);
      expect(find.text(formatMoney(185000)), findsOneWidget);
      expect(find.text('+${formatMoney(1850)} cashback'), findsOneWidget);
      expect(find.text('Omborda bor'), findsOneWidget);
      expect(find.text('Tavsif'), findsOneWidget);
      expect(find.text('Tarkibi'), findsOneWidget);
      expect(find.text('Qo‘llash'), findsNothing); // empty usage is hidden
      expect(find.text('Savatga qo‘shish'), findsOneWidget);

      await tester.tap(find.text('Tarkibi'));
      await tester.pumpAndSettle();
      expect(find.text('Aqua'), findsOneWidget);
    });

    testWidgets('promo product: no cashback, promo note', (tester) async {
      await pump(tester, overrides(detail(promo: true)));
      expect(find.byKey(const ValueKey('product.cashback')), findsNothing);
      expect(find.text('Aksiya — cashback hisoblanmaydi'), findsOneWidget);
    });

    testWidgets('guest: no cashback chip', (tester) async {
      await pump(tester, overrides(detail(), signedIn: false));
      expect(find.byKey(const ValueKey('product.cashback')), findsNothing);
      expect(find.text('Savatga qo‘shish'), findsOneWidget);
    });

    testWidgets('in the cart: stepper and go to cart', (tester) async {
      await pump(tester, overrides(detail(), inCart: true));
      expect(find.text('Savatga o‘tish'), findsOneWidget);
      expect(find.byType(WideStepper), findsOneWidget);
    });

    testWidgets('max_quantity 0: disabled sold-out button', (tester) async {
      await pump(tester, overrides(detail(maxQuantity: 0)));
      expect(find.text('Hozircha mavjud emas'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('404 shows not found', (tester) async {
      await pump(tester, [...baseOverrides(api: FakeCatalogApi())]);
      expect(find.text('Mahsulot topilmadi'), findsOneWidget);
    });
  });
}
