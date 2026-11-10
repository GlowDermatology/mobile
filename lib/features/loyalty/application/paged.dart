import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/json.dart';
import '../../../core/network/page.dart';
import '../../auth/application/session_controller.dart';

/// An infinitely scrolled list loaded page by page.
class PagedState<T> {
  const PagedState({
    required this.items,
    required this.page,
    required this.hasMore,
    this.loadingMore = false,
    this.moreError,
    this.extra = const {},
  });

  factory PagedState.first(Page<T> page) => PagedState(
    items: page.items,
    page: page.page,
    hasMore: page.hasMore,
    extra: page.extra,
  );

  static PagedState<T> empty<T>() =>
      PagedState<T>(items: const [], page: 1, hasMore: false);

  final List<T> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;

  /// Failure of the last "next page" request (the loaded items stay).
  final Object? moreError;

  /// The last envelope (endpoint-specific keys such as `unread_count`).
  final Json extra;

  PagedState<T> copyWith({
    List<T>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    Object? moreError,
    Json? extra,
  }) => PagedState(
    items: items ?? this.items,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    moreError: moreError,
    extra: extra ?? this.extra,
  );

  /// Appends [next], dropping rows already shown (new rows arriving at the
  /// top shift the pages by one).
  PagedState<T> append(Page<T> next, Object Function(T) keyOf) {
    final seen = items.map(keyOf).toSet();
    return PagedState(
      items: [...items, ...next.items.where((e) => !seen.contains(keyOf(e)))],
      page: next.page,
      hasMore: next.hasMore,
      extra: next.extra,
    );
  }
}

/// Signed-in paged list: page 1 on build, [loadMore] at the end of the list,
/// [refresh] for pull to refresh. Guests get an empty list.
abstract class PagedNotifier<T> extends AsyncNotifier<PagedState<T>> {
  Future<Page<T>> fetchPage(int page);
  Object keyOf(T item);

  /// Bumped by [build] and [refresh] so a "next page" answer that belongs to
  /// the list before a reload is dropped instead of appended to page 1.
  int _epoch = 0;

  @override
  Future<PagedState<T>> build() async {
    _epoch++;
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    if (!signedIn) return PagedState.empty<T>();
    final first = PagedState.first(await fetchPage(1));
    onPage(first.extra);
    return first;
  }

  /// Hook for envelope extras (e.g. the inbox `unread_count`).
  void onPage(Json extra) {}

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        !current.hasMore ||
        current.loadingMore ||
        state.isLoading) {
      return;
    }
    final epoch = _epoch;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await fetchPage(current.page + 1);
      if (!ref.mounted || epoch != _epoch) return;
      final latest = state.value ?? current;
      state = AsyncData(latest.append(next, keyOf));
      onPage(next.extra);
    } on Object catch (e) {
      if (!ref.mounted || epoch != _epoch) return;
      state = AsyncData(
        (state.value ?? current).copyWith(loadingMore: false, moreError: e),
      );
    }
  }

  /// Reloads page 1; keeps the shown list when the reload fails.
  Future<void> refresh() async {
    if (!ref.read(sessionProvider).signedIn) return;
    final epoch = ++_epoch;
    try {
      final first = PagedState.first(await fetchPage(1));
      if (!ref.mounted || epoch != _epoch) return;
      state = AsyncData(first);
      onPage(first.extra);
    } on Object catch (e, st) {
      if (!ref.mounted || epoch != _epoch) return;
      final shown = state.value;
      if (shown == null) {
        state = AsyncError(e, st);
      } else if (shown.loadingMore) {
        // The "next page" request of the old list was dropped above.
        state = AsyncData(
          shown.copyWith(loadingMore: false, moreError: shown.moreError),
        );
      }
    }
  }
}
