import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/order_models.dart';
import '../data/orders_api.dart';

/// The loaded pages of `GET me/orders/` for one scope.
class OrdersListState {
  const OrdersListState({
    required this.items,
    required this.count,
    required this.page,
    required this.pageCount,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<OrderSummary> items;
  final int count;
  final int page;
  final int pageCount;
  final bool loadingMore;
  final Object? loadMoreError;

  bool get hasMore => page < pageCount;
  bool get isEmpty => items.isEmpty;

  /// Appends the next page, skipping orders already shown (a new order shifts
  /// the pages while the customer scrolls).
  OrdersListState append(
    List<OrderSummary> more, {
    required int page,
    required int pageCount,
    required int count,
  }) {
    final seen = {for (final o in items) o.id};
    return OrdersListState(
      items: [...items, ...more.where((o) => seen.add(o.id))],
      count: count,
      page: page,
      pageCount: pageCount,
    );
  }

  OrdersListState copyWith({
    bool? loadingMore,
    Object? Function()? loadMoreError,
  }) => OrdersListState(
    items: items,
    count: count,
    page: page,
    pageCount: pageCount,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreError: loadMoreError != null ? loadMoreError() : this.loadMoreError,
  );
}

/// Infinite scroll over the customer's orders (page size 10).
class OrdersListController extends AsyncNotifier<OrdersListState> {
  OrdersListController(this.scope);
  final OrderScope scope;

  @override
  Future<OrdersListState> build() async {
    ref.watch(languageProvider);
    final page = await ref.watch(ordersApiProvider).list(scope);
    return OrdersListState(
      items: page.items,
      count: page.count,
      page: page.page,
      pageCount: page.pageCount,
    );
  }

  /// Loads the next page; a failure stays on the state (`loadMoreError`).
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        current.loadingMore ||
        !current.hasMore ||
        state.isLoading) {
      return;
    }
    state = AsyncData(
      current.copyWith(loadingMore: true, loadMoreError: () => null),
    );
    try {
      final page = await ref
          .read(ordersApiProvider)
          .list(scope, page: current.page + 1);
      if (!ref.mounted) return;
      state = AsyncData(
        current.append(
          page.items,
          page: page.page,
          pageCount: page.pageCount,
          count: page.count,
        ),
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreError: () => e),
      );
    }
  }
}

final ordersListProvider = AsyncNotifierProvider.autoDispose
    .family<OrdersListController, OrdersListState, OrderScope>(
      OrdersListController.new,
      retry: (_, _) => null,
    );
