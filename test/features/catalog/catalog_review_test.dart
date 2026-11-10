import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/app/providers.dart';
import 'package:glow_derma/core/network/page.dart';
import 'package:glow_derma/features/cart/application/cart_controller.dart';
import 'package:glow_derma/features/catalog/data/catalog_api.dart';
import 'package:glow_derma/features/catalog/data/catalog_models.dart';
import 'package:glow_derma/features/catalog/data/catalog_providers.dart';
import 'package:glow_derma/features/catalog/presentation/widgets/category_strip.dart';
import 'package:glow_derma/features/catalog/presentation/widgets/product_card_tile.dart';

import 'catalog_models_test.dart' show cardJson;
import 'fakes.dart';

/// First page answers at once; page 2 waits for [release].
class _SlowApi extends FakeCatalogApi {
  final release = Completer<void>();
  int builds = 0;

  @override
  Future<Page<ProductCard>> products(ProductQuery query, {int page = 1}) async {
    if (page == 1) {
      builds++;
      return pageOf(
        builds == 1 ? [1, 2] : [10, 11],
        page: 1,
        pageCount: 2,
        count: 4,
      );
    }
    await release.future;
    return pageOf([3, 4], page: 2, pageCount: 2, count: 4);
  }
}

void main() {
  group('e2e semantics nodes carry a tap action', () {
    bool hasTap(WidgetTester tester, String id) => tester
        .getSemantics(find.bySemanticsIdentifier(id))
        .getSemanticsData()
        .hasAction(SemanticsAction.tap);

    testWidgets('card price pill and stepper buttons', (tester) async {
      final handle = tester.ensureSemantics();
      final p = ProductCard.fromJson(cardJson()..['main_image_url'] = null);
      await tester.pumpWidget(
        testApp(
          Center(
            child: SizedBox(
              width: 180,
              height: 320,
              child: ProductCardTile(product: p),
            ),
          ),
          baseOverrides(),
        ),
      );
      await tester.pumpAndSettle();
      expect(hasTap(tester, 'catalog.add.1'), isTrue);
      handle.dispose();
    });

    testWidgets('stepper plus via semantics action', (tester) async {
      final handle = tester.ensureSemantics();
      final p = ProductCard.fromJson(cardJson()..['main_image_url'] = null);
      await tester.pumpWidget(
        testApp(
          Center(
            child: SizedBox(
              width: 180,
              height: 320,
              child: ProductCardTile(product: p),
            ),
          ),
          baseOverrides(cart: cartWith(1, 1)),
        ),
      );
      await tester.pumpAndSettle();
      expect(hasTap(tester, 'catalog.card.1.minus'), isTrue);
      expect(hasTap(tester, 'catalog.card.1.plus'), isTrue);
      tester.semantics.tap(
        find.semantics.byPredicate(
          (n) => n.identifier == 'catalog.card.1.plus',
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProductCardTile)),
      );
      expect((container.read(cartProvider.notifier) as FakeCart).calls, [
        (1, 2),
      ]);
      handle.dispose();
    });

    testWidgets('category bubble', (tester) async {
      final handle = tester.ensureSemantics();
      CatalogCategory? picked;
      var tapped = false;
      await tester.pumpWidget(
        testApp(
          Material(
            child: CategoryStrip(
              categories: [
                CatalogCategory.fromJson({
                  'slug': 'serums',
                  'name': 'Serumlar',
                  'image_url': null,
                  'product_count': 1,
                }),
              ],
              onSelect: (c) {
                picked = c;
                tapped = true;
              },
            ),
          ),
          baseOverrides(),
        ),
      );
      await tester.pumpAndSettle();
      expect(hasTap(tester, 'home.category.serums'), isTrue);
      tester.semantics.tap(
        find.semantics.byPredicate(
          (n) => n.identifier == 'home.category.serums',
        ),
      );
      await tester.pump();
      expect(tapped, isTrue);
      expect(picked?.slug, 'serums');
      handle.dispose();
    });
  });

  test('a next page that lands after a refresh is dropped', () async {
    const query = ProductQuery();
    final api = _SlowApi();
    final container = ProviderContainer(
      overrides: [
        languageProvider.overrideWith(FakeLanguage.new),
        catalogApiProvider.overrideWithValue(api as CatalogApi),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(productListProvider(query), (_, _) {});
    addTearDown(sub.close);
    await container.read(productListProvider(query).future);

    final more = container.read(productListProvider(query).notifier).loadMore();
    container.invalidate(productListProvider(query));
    final refreshed = await container.read(productListProvider(query).future);
    expect(refreshed.items.map((p) => p.id), [10, 11]);

    api.release.complete();
    await more;
    final state = container.read(productListProvider(query)).value!;
    expect(state.items.map((p) => p.id), [10, 11]);
  });
}
