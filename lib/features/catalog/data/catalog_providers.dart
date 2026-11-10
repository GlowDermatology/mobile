import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import 'catalog_api.dart';
import 'catalog_models.dart';

/// Riverpod's automatic retry, limited to network failures (a 400/404 will
/// not get better by asking again).
Duration? catalogRetry(int retryCount, Object error) =>
    error is ApiException && error.isNetwork && retryCount < 3
    ? Duration(milliseconds: 800 * (1 << retryCount))
    : null;

final bannersProvider = FutureProvider<List<CatalogBanner>>((ref) {
  ref.watch(languageProvider);
  return ref.watch(catalogApiProvider).banners();
}, retry: catalogRetry);

final categoriesProvider = FutureProvider<List<CatalogCategory>>((ref) {
  ref.watch(languageProvider);
  return ref.watch(catalogApiProvider).categories();
}, retry: catalogRetry);

/// Home "Mashhur mahsulotlar": promo products first, then the newest.
final popularProductsProvider = FutureProvider<List<ProductCard>>((ref) async {
  ref.watch(languageProvider);
  final api = ref.watch(catalogApiProvider);
  final results = await Future.wait([
    api.products(const ProductQuery(promo: true)),
    api.products(const ProductQuery()),
  ]);
  return mergePopular(results[0].items, results[1].items);
}, retry: catalogRetry);

final productDetailProvider = FutureProvider.autoDispose
    .family<ProductDetail, int>((ref, id) {
      ref.watch(languageProvider);
      return ref.watch(catalogApiProvider).product(id);
    }, retry: catalogRetry);

/// The loaded pages of one product list.
@immutable
class ProductListState {
  const ProductListState({
    required this.items,
    required this.count,
    required this.page,
    required this.pageCount,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<ProductCard> items;
  final int count;
  final int page;
  final int pageCount;
  final bool loadingMore;
  final Object? loadMoreError;

  bool get hasMore => page < pageCount;

  /// Appends the next page, skipping products already shown (a product can
  /// move between pages when the list changes while scrolling).
  ProductListState append(
    List<ProductCard> more, {
    required int page,
    required int pageCount,
    required int count,
  }) {
    final seen = {for (final p in items) p.id};
    return ProductListState(
      items: [...items, ...more.where((p) => seen.add(p.id))],
      count: count,
      page: page,
      pageCount: pageCount,
    );
  }

  ProductListState copyWith({
    bool? loadingMore,
    Object? Function()? loadMoreError,
  }) => ProductListState(
    items: items,
    count: count,
    page: page,
    pageCount: pageCount,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreError: loadMoreError != null ? loadMoreError() : this.loadMoreError,
  );
}

/// Infinite scroll over `GET catalog/products/` for one [ProductQuery].
class ProductListController extends AsyncNotifier<ProductListState> {
  ProductListController(this.query);
  final ProductQuery query;

  @override
  Future<ProductListState> build() async {
    ref.watch(languageProvider);
    final page = await ref.watch(catalogApiProvider).products(query);
    return ProductListState(
      items: page.items,
      count: page.count,
      page: page.page,
      pageCount: page.pageCount,
    );
  }

  /// Loads the next page; errors stay on the state (`loadMoreError`).
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        current.loadingMore ||
        !current.hasMore ||
        state.isLoading) {
      return;
    }
    final loading = current.copyWith(
      loadingMore: true,
      loadMoreError: () => null,
    );
    state = AsyncData(loading);
    // A refresh (or a language change) that rebuilt the list meanwhile wins:
    // its first page must not get this stale page appended.
    bool stale() =>
        !ref.mounted || !identical(state.value, loading) || state.isLoading;
    try {
      final page = await ref
          .read(catalogApiProvider)
          .products(query, page: current.page + 1);
      if (stale()) return;
      state = AsyncData(
        current.append(
          page.items,
          page: page.page,
          pageCount: page.pageCount,
          count: page.count,
        ),
      );
    } on Object catch (e) {
      if (stale()) return;
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreError: () => e),
      );
    }
  }
}

final productListProvider = AsyncNotifierProvider.autoDispose
    .family<ProductListController, ProductListState, ProductQuery>(
      ProductListController.new,
      retry: catalogRetry,
    );
