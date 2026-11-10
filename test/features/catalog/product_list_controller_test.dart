import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/app/providers.dart';
import 'package:glow_derma/core/network/page.dart';
import 'package:glow_derma/features/catalog/data/catalog_api.dart';
import 'package:glow_derma/features/catalog/data/catalog_models.dart';
import 'package:glow_derma/features/catalog/data/catalog_providers.dart';

import 'fakes.dart';

void main() {
  const query = ProductQuery(category: 'serums');

  ProviderContainer containerWith(CatalogApi api) {
    final container = ProviderContainer(
      overrides: [
        languageProvider.overrideWith(FakeLanguage.new),
        catalogApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'loads the first page then appends the next without duplicates',
    () async {
      final api = FakeCatalogApi(
        pages: {
          1: pageOf([1, 2, 3], page: 1, pageCount: 2, count: 5),
          2: pageOf([3, 4, 5], page: 2, pageCount: 2, count: 5),
        },
      );
      final container = containerWith(api);
      final sub = container.listen(productListProvider(query), (_, _) {});
      addTearDown(sub.close);

      final first = await container.read(productListProvider(query).future);
      expect(first.items.map((p) => p.id), [1, 2, 3]);
      expect(first.hasMore, isTrue);

      await container.read(productListProvider(query).notifier).loadMore();
      final state = container.read(productListProvider(query)).value!;
      expect(state.items.map((p) => p.id), [1, 2, 3, 4, 5]);
      expect(state.hasMore, isFalse);
      expect(api.calls.map((c) => c.$2), [1, 2]);
      expect(api.calls.every((c) => c.$1 == query), isTrue);

      // Nothing more to load: no request.
      await container.read(productListProvider(query).notifier).loadMore();
      expect(api.calls, hasLength(2));
    },
  );

  test('a failed next page keeps the items and records the error', () async {
    final api = FakeCatalogApi(
      pages: {
        1: pageOf([1, 2], page: 1, pageCount: 3),
        2: pageOf([3], page: 2, pageCount: 3),
      },
      failPage: 2,
    );
    final container = containerWith(api);
    final sub = container.listen(productListProvider(query), (_, _) {});
    addTearDown(sub.close);
    await container.read(productListProvider(query).future);

    await container.read(productListProvider(query).notifier).loadMore();
    var state = container.read(productListProvider(query)).value!;
    expect(state.items.map((p) => p.id), [1, 2]);
    expect(state.loadMoreError, isNotNull);
    expect(state.loadingMore, isFalse);

    api.failPage = null;
    await container.read(productListProvider(query).notifier).loadMore();
    state = container.read(productListProvider(query)).value!;
    expect(state.items.map((p) => p.id), [1, 2, 3]);
    expect(state.loadMoreError, isNull);
    expect(state.page, 2);
  });

  test('popular products merge promo first then newest', () async {
    final container = containerWith(_PopularApi());
    final list = await container.read(popularProductsProvider.future);
    expect(list.map((p) => p.id), [7, 1, 2]);
  });

  test('ProductListState.append skips products already shown', () {
    final s = ProductListState(
      items: pageOf([1, 2], page: 1, pageCount: 2).items,
      count: 4,
      page: 1,
      pageCount: 2,
    );
    final next = s.append(
      pageOf([2, 3], page: 2, pageCount: 2).items,
      page: 2,
      pageCount: 2,
      count: 4,
    );
    expect(next.items.map((p) => p.id), [1, 2, 3]);
    expect(next.hasMore, isFalse);
  });
}

class _PopularApi extends FakeCatalogApi {
  @override
  Future<Page<ProductCard>> products(
    ProductQuery query, {
    int page = 1,
  }) async => query.promo
      ? pageOf([7, 1], page: 1, pageCount: 1)
      : pageOf([1, 2], page: 1, pageCount: 1);
}
