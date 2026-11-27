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
import 'package:glow_derma/core/widgets/gd_widgets.dart';
import 'package:glow_derma/features/catalog/presentation/widgets/photo_viewer.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'catalog_models_test.dart' show cardJson;
import 'fakes.dart';

Widget tile(ProductCard p) => Center(
  child: SizedBox(width: 180, height: 320, child: ProductCardTile(product: p)),
);

ProductDetail detail({
  bool promo = false,
  int maxQuantity = 10,
  String ingredients = 'Aqua',
  List<Object> images = const [],
}) => ProductDetail.fromJson({
  ...cardJson(promo: promo),
  'main_image_url': null,
  'description': 'Gialuron kislotasining uch xil molekulasi',
  'ingredients': ingredients,
  'usage': '',
  'images': images,
  'max_quantity': maxQuantity,
});

void main() {
  group('ProductCardTile', () {
    GdImage image(WidgetTester tester) =>
        tester.widget<GdImage>(find.byType(GdImage));

    testWidgets('shows the portrait (4:5) copy when there is one', (
      tester,
    ) async {
      final p = ProductCard.fromJson({
        ...cardJson(),
        'main_image_medium_url': 'https://m.uz/a_1000.webp',
        'main_image_renditions': {
          'portrait': {
            'url': 'https://m.uz/a_45.webp',
            'medium_url': 'https://m.uz/a_45_1000.webp',
            'thumbnail_url': 'https://m.uz/a_45_400.webp',
          },
          'square': null,
        },
      });
      await tester.pumpWidget(testApp(tile(p), baseOverrides()));
      await tester.pumpAndSettle();
      expect(image(tester).url, 'https://m.uz/a_45_1000.webp');
      expect(image(tester).fallbackUrl, p.mainImageUrl);
      expect(image(tester).fit, BoxFit.cover);
    });

    testWidgets('without a square copy: the 1000 px image as before', (
      tester,
    ) async {
      final p = ProductCard.fromJson({
        ...cardJson(),
        'main_image_medium_url': 'https://m.uz/a_1000.webp',
        'main_image_renditions': {'portrait': null, 'square': null},
      });
      await tester.pumpWidget(testApp(tile(p), baseOverrides()));
      await tester.pumpAndSettle();
      expect(image(tester).url, 'https://m.uz/a_1000.webp');
      expect(image(tester).fallbackUrl, p.mainImageUrl);
    });

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

    GdImage page(WidgetTester tester) => tester.widget<GdImage>(
      find.descendant(
        of: find.byType(PageView),
        matching: find.byType(GdImage),
      ),
    );

    testWidgets('a portrait copy fills the hero', (tester) async {
      await pump(
        tester,
        overrides(
          detail(
            images: [
              {
                'id': 1,
                'url': 'https://m.uz/a.webp',
                'medium_url': 'https://m.uz/a_1000.webp',
                'position': 0,
                'renditions': {
                  'portrait': {
                    'url': 'https://m.uz/a_45.webp',
                    'medium_url': 'https://m.uz/a_45_1000.webp',
                    'thumbnail_url': 'https://m.uz/a_45_400.webp',
                  },
                  'square': null,
                },
              },
            ],
          ),
        ),
      );
      final img = page(tester);
      expect(img.url, 'https://m.uz/a_45_1000.webp');
      expect(img.fallbackUrl, 'https://m.uz/a.webp');
      expect(img.fit, BoxFit.cover);
      expect(img.radius, 0);
      // Edge to edge: as wide as the screen.
      expect(tester.getSize(find.byWidget(img)).width, 390);
    });

    testWidgets('without one, the photo still fills the hero edge to edge', (
      tester,
    ) async {
      await pump(
        tester,
        overrides(
          detail(
            images: [
              {
                'id': 1,
                'url': 'https://m.uz/a.webp',
                'medium_url': 'https://m.uz/a_1000.webp',
                'position': 0,
              },
            ],
          ),
        ),
      );
      final img = page(tester);
      expect(img.url, 'https://m.uz/a_1000.webp');
      expect(img.fallbackUrl, 'https://m.uz/a.webp');
      expect(img.fit, BoxFit.cover);
      expect(img.radius, 0);
      expect(tester.getSize(find.byWidget(img)).width, 390);
    });

    List<Object> photos(int n) => [
      for (var i = 1; i <= n; i++)
        {
          'id': i,
          'url': 'https://m.uz/p$i.webp',
          'medium_url': 'https://m.uz/p${i}_1000.webp',
          'position': i - 1,
        },
    ];

    testWidgets('«Kattalashtirish» opens the photos full screen', (
      tester,
    ) async {
      await pump(tester, overrides(detail(images: photos(3))));
      final chip = find.bySemanticsIdentifier('product.enlarge');
      expect(chip, findsOneWidget);
      expect(find.text('Kattalashtirish'), findsOneWidget);
      await tester.tap(find.text('Kattalashtirish'));
      await tester.pumpAndSettle();

      expect(find.byType(PhotoViewer), findsOneWidget);
      expect(find.text('3 ta rasmdan 1-si'), findsOneWidget);
      expect(
        find.text('Ikki barmoq bilan yoki ikki marta bosib kattalashtiring'),
        findsOneWidget,
      );
      // The whole original photo, not the hero's crop.
      final shown = tester.widget<CachedNetworkImage>(
        find
            .descendant(
              of: find.byKey(const ValueKey('photo-viewer.zoom.0')),
              matching: find.byType(CachedNetworkImage),
            )
            .first,
      );
      expect(shown.imageUrl, 'https://m.uz/p1.webp');
      expect(shown.fit, BoxFit.contain);

      // A thumbnail jumps; a swipe moves on.
      await tester.tap(find.bySemanticsIdentifier('photo-viewer.thumb.2'));
      await tester.pumpAndSettle();
      expect(find.text('3 ta rasmdan 3-si'), findsOneWidget);
      await tester.fling(
        find.byKey(const ValueKey('photo-viewer.pages')),
        const Offset(300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text('3 ta rasmdan 2-si'), findsOneWidget);

      // A double tap zooms in (the hint says how to get back), and out again.
      final page = find.byKey(const ValueKey('photo-viewer.zoom.1'));
      await tester.tap(page);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(page);
      await tester.pumpAndSettle();
      expect(
        find.text('Suring va ko‘ring · ikki marta bosib kichraytiring'),
        findsOneWidget,
      );
      await tester.tap(page);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(page);
      await tester.pumpAndSettle();
      expect(
        find.text('Ikki barmoq bilan yoki ikki marta bosib kattalashtiring'),
        findsOneWidget,
      );

      // «Yopish» (a labelled button, not a bare cross) goes back.
      expect(find.text('Yopish'), findsOneWidget);
      await tester.tap(find.bySemanticsIdentifier('photo-viewer.close'));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewer), findsNothing);
    });

    testWidgets('a tap on the hero photo opens that photo', (tester) async {
      await pump(tester, overrides(detail(images: photos(2))));
      await tester.tap(find.byKey(const ValueKey('product.photo.0')));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewer), findsOneWidget);
      expect(find.text('2 ta rasmdan 1-si'), findsOneWidget);
    });

    testWidgets('signed in, regular product: cashback chip, tabs, add button', (
      tester,
    ) async {
      await pump(tester, overrides(detail()));
      expect(find.text('Gialuron kislotali serum'), findsOneWidget);
      expect(find.text(formatMoney(185000)), findsOneWidget);
      expect(find.text('+${formatMoney(1850)} cashback'), findsOneWidget);
      // Below the 4:5 hero: scroll as a person would.
      await tester.scrollUntilVisible(
        find.text('Tarkibi'),
        200,
        scrollable: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );
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
