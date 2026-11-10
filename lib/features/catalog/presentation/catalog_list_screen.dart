import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../data/catalog_models.dart';
import '../data/catalog_providers.dart';
import 'catalog_text.dart';
import 'widgets/category_strip.dart';
import 'widgets/product_card_tile.dart';

/// Search results, a category or the promo list, with filters, sorting and
/// infinite scroll. Opened with `?q=` (empty = focus the search field),
/// `?category=<slug>` or `?promo=1`.
class CatalogListScreen extends ConsumerStatefulWidget {
  const CatalogListScreen({
    super.key,
    this.category,
    this.search,
    this.promo = false,
  });
  final String? category;
  final String? search;
  final bool promo;

  @override
  ConsumerState<CatalogListScreen> createState() => _CatalogListScreenState();
}

class _CatalogListScreenState extends ConsumerState<CatalogListScreen> {
  static const debounce = Duration(milliseconds: 400);

  late final TextEditingController _text = TextEditingController(
    text: widget.search ?? '',
  );
  final _scroll = ScrollController();
  Timer? _debounce;
  late ProductQuery _query = ProductQuery(
    search: widget.search ?? '',
    category: widget.category,
    promo: widget.promo,
  );

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void didUpdateWidget(CatalogListScreen old) {
    super.didUpdateWidget(old);
    // The same page re-targeted by a link (`context.go` with new parameters).
    if (old.category != widget.category ||
        old.search != widget.search ||
        old.promo != widget.promo) {
      _debounce?.cancel();
      _text.text = widget.search ?? '';
      _query = ProductQuery(
        search: widget.search ?? '',
        category: widget.category,
        promo: widget.promo,
        ordering: _query.ordering,
      );
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _setQuery(ProductQuery q) {
    if (q == _query) {
      _query = q;
      return;
    }
    setState(() => _query = q);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(debounce, () {
      if (mounted) _setQuery(_query.copyWith(search: value));
    });
    setState(() {}); // the "at least 2 letters" hint
  }

  void _onSubmitted(String value) {
    _debounce?.cancel();
    _setQuery(_query.copyWith(search: value));
  }

  void _clearSearch() {
    _debounce?.cancel();
    _text.clear();
    _setQuery(_query.copyWith(search: ''));
  }

  void _resetFilters() {
    _debounce?.cancel();
    _text.clear();
    _setQuery(ProductQuery(ordering: _query.ordering));
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 600) {
      ref.read(productListProvider(_query).notifier).loadMore();
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(productListProvider(_query));
    try {
      await ref.read(productListProvider(_query).future);
    } on Object {
      // shown in the list
    }
  }

  String _title(BuildContext context, List<CatalogCategory> categories) {
    final slug = _query.category;
    if (slug != null) {
      final match = categories.where((c) => c.slug == slug).firstOrNull;
      if (match != null) return match.name;
    }
    if (_query.promo) return CatalogText.promoTitle.of(context);
    return CatalogText.catalog.of(context);
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(categoriesProvider).value ?? const <CatalogCategory>[];
    final list = ref.watch(productListProvider(_query));
    final typed = _text.text.trim();
    final showShortHint =
        typed.isNotEmpty && typed.length < ProductQuery.minSearchLength;

    // A first page that does not fill the screen: fetch the next one.
    final pending = list.value;
    if (pending != null &&
        pending.hasMore &&
        pending.loadMoreError == null &&
        !pending.loadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _scroll.hasClients &&
            _scroll.position.maxScrollExtent < 200) {
          ref.read(productListProvider(_query).notifier).loadMore();
        }
      });
    }

    return Scaffold(
      appBar: GdHeader(title: _title(context, categories)),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    GdSpace.page,
                    4,
                    GdSpace.page,
                    0,
                  ),
                  child: CatalogSearchField(
                    controller: _text,
                    autofocus: widget.search != null && widget.search!.isEmpty,
                    hint: CatalogText.searchHint.of(context),
                    onChanged: _onTextChanged,
                    onSubmitted: _onSubmitted,
                    onClear: _clearSearch,
                    semanticsId: 'catalog.search',
                  ),
                ),
              ),
              if (showShortHint)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      GdSpace.page + 4,
                      6,
                      GdSpace.page,
                      0,
                    ),
                    child: Text(
                      CatalogText.shortQuery.of(context),
                      style: context.gdText.caption,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(child: _categoryChips(context, categories)),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverToBoxAdapter(child: _filterRow(context)),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ..._results(context, list),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryChips(
    BuildContext context,
    List<CatalogCategory> categories,
  ) => SizedBox(
    height: 44 * MediaQuery.textScalerOf(context).scale(14) / 14,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: GdSpace.page),
      children: [
        Semantics(
          identifier: 'catalog.category.all',
          button: true,
          child: GdFilterChip(
            label: CatalogText.all.of(context),
            selected: _query.category == null,
            onTap: () => _setQuery(_query.copyWith(category: () => null)),
          ),
        ),
        for (final cat in categories) ...[
          const SizedBox(width: 8),
          Semantics(
            identifier: 'catalog.category.${cat.slug}',
            button: true,
            child: GdFilterChip(
              label: cat.name,
              selected: _query.category == cat.slug,
              onTap: () => _setQuery(_query.copyWith(category: () => cat.slug)),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _filterRow(BuildContext context) {
    final c = context.gd;
    final t = context.gdText;
    return SizedBox(
      height: 44 * MediaQuery.textScalerOf(context).scale(14) / 14,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: GdSpace.page),
        children: [
          Semantics(
            identifier: 'catalog.sort',
            button: true,
            child: PopupMenuButton<ProductOrdering>(
              tooltip: CatalogText.sortLabel.of(context),
              initialValue: _query.ordering,
              onSelected: (o) => _setQuery(_query.copyWith(ordering: o)),
              itemBuilder: (context) => [
                for (final o in ProductOrdering.values)
                  CheckedPopupMenuItem(
                    value: o,
                    checked: o == _query.ordering,
                    child: Text(orderingLabel(o).of(context)),
                  ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: ShapeDecoration(
                  color: c.surfaceRaised,
                  shape: StadiumBorder(
                    side: BorderSide(color: c.lineStrong, width: 1.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swap_vert_rounded, size: 18, color: c.ink),
                    const SizedBox(width: 6),
                    Text(
                      orderingLabel(_query.ordering).of(context),
                      style: t.label,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            identifier: 'catalog.in_stock',
            button: true,
            child: GdFilterChip(
              label: CatalogText.onlyInStock.of(context),
              selected: _query.inStock,
              onTap: () => _setQuery(_query.copyWith(inStock: !_query.inStock)),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            identifier: 'catalog.promo',
            button: true,
            child: GdFilterChip(
              label: CatalogText.promoTitle.of(context),
              selected: _query.promo,
              onTap: () => _setQuery(_query.copyWith(promo: !_query.promo)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _results(
    BuildContext context,
    AsyncValue<ProductListState> list,
  ) {
    const pad = EdgeInsets.symmetric(horizontal: GdSpace.page);
    final data = list.value;
    if (data == null) {
      if (list.hasError) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: GdErrorView(
              error: list.error!,
              onRetry: () => ref.invalidate(productListProvider(_query)),
            ),
          ),
        ];
      }
      return const [
        SliverFillRemaining(hasScrollBody: false, child: GdLoading()),
      ];
    }
    if (data.items.isEmpty) {
      final hasFilters =
          _query.effectiveSearch.isNotEmpty ||
          _query.category != null ||
          _query.inStock ||
          _query.promo;
      final onlyCategory =
          _query.category != null &&
          _query.effectiveSearch.isEmpty &&
          !_query.inStock &&
          !_query.promo;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: GdEmptyView(
            icon: Icons.search_off_rounded,
            title: CatalogText.emptyTitle.of(context),
            body: onlyCategory
                ? CatalogText.emptyCategory.of(context)
                : CatalogText.emptyBody.of(context),
            action: hasFilters
                ? SizedBox(
                    width: 220,
                    child: GdOutlineButton(
                      label: CatalogText.resetFilters.of(context),
                      onPressed: _resetFilters,
                      semanticsId: 'catalog.reset',
                    ),
                  )
                : null,
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(GdSpace.page, 0, GdSpace.page, 10),
        sliver: SliverToBoxAdapter(
          child: Text(
            CatalogText.results.fmt(context, {'n': data.count}),
            style: context.gdText.caption,
          ),
        ),
      ),
      SliverPadding(
        padding: pad,
        sliver: SliverGrid(
          gridDelegate: productGridDelegate(context),
          delegate: SliverChildBuilderDelegate(
            (context, i) => ProductCardTile(
              key: ValueKey(data.items[i].id),
              product: data.items[i],
            ),
            childCount: data.items.length,
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            GdSpace.page,
            16,
            GdSpace.page,
            28,
          ),
          child: data.loadingMore
              ? const Center(
                  child: SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              : data.loadMoreError != null
              ? Center(
                  child: TextButton.icon(
                    onPressed: () => ref
                        .read(productListProvider(_query).notifier)
                        .loadMore(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      errorMessage(context, data.loadMoreError!),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    ];
  }
}

Tr orderingLabel(ProductOrdering o) => switch (o) {
  ProductOrdering.newest => CatalogText.sortNewest,
  ProductOrdering.priceAsc => CatalogText.sortPriceAsc,
  ProductOrdering.priceDesc => CatalogText.sortPriceDesc,
  ProductOrdering.name => CatalogText.sortName,
};
