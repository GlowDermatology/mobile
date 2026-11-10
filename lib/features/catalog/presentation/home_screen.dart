import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../../core/widgets/rings.dart';
import '../../auth/application/session_controller.dart';
import '../../cart/application/cart_controller.dart';
import '../../notifications/data/unread_count.dart';
import '../data/catalog_models.dart';
import '../data/catalog_providers.dart';
import 'catalog_text.dart';
import 'widgets/banner_carousel.dart';
import 'widgets/category_strip.dart';
import 'widgets/product_card_tile.dart';

/// Katalog tab home (PDF p.3): wordmark header, banners, search, category
/// circles and "Mashhur mahsulotlar".
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(bannersProvider)
      ..invalidate(categoriesProvider)
      ..invalidate(popularProductsProvider);
    ref.read(cartProvider.notifier).reload().ignore();
    ref.read(unreadCountProvider.notifier).refresh().ignore();
    try {
      await ref.read(popularProductsProvider.future);
    } on Object {
      // shown by the section itself
    }
  }

  void _submitSearch(String text) {
    final q = text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    context.push(
      Uri(path: '/catalog/list', queryParameters: {'q': q}).toString(),
    );
  }

  void _openCategory(CatalogCategory? category) => context.push(
    category == null
        ? '/catalog/list'
        : Uri(
            path: '/catalog/list',
            queryParameters: {'category': category.slug},
          ).toString(),
  );

  @override
  Widget build(BuildContext context) {
    final banners = ref.watch(bannersProvider);
    final categories = ref.watch(categoriesProvider);
    final popular = ref.watch(popularProductsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: _HomeHeader()),
              SliverToBoxAdapter(
                child: switch (banners) {
                  AsyncData(value: final list) when list.isNotEmpty => Padding(
                    padding: const EdgeInsets.fromLTRB(
                      GdSpace.page,
                      4,
                      GdSpace.page,
                      16,
                    ),
                    child: BannerCarousel(banners: list),
                  ),
                  AsyncLoading() when !banners.hasValue => const Padding(
                    padding: EdgeInsets.fromLTRB(
                      GdSpace.page,
                      4,
                      GdSpace.page,
                      16,
                    ),
                    child: AspectRatio(
                      aspectRatio: 2.15,
                      child: _Skeleton(radius: GdRadius.lg),
                    ),
                  ),
                  _ => const SizedBox(height: 4),
                },
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: GdSpace.page),
                  child: CatalogSearchField(
                    controller: _search,
                    onSubmitted: _submitSearch,
                    semanticsId: 'home.search',
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              SliverToBoxAdapter(
                child: CategoryStrip(
                  categories: categories.value ?? const [],
                  onSelect: _openCategory,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: GdSpace.page),
                sliver: SliverToBoxAdapter(
                  child: GdSectionTitle(
                    CatalogText.popular.of(context),
                    trailing: Semantics(
                      identifier: 'home.see_all',
                      button: true,
                      child: TextButton(
                        onPressed: () => context.push('/catalog/list'),
                        child: Text(CatalogText.seeAll.of(context)),
                      ),
                    ),
                  ),
                ),
              ),
              ...switch (popular) {
                AsyncValue(hasValue: true, value: final list?)
                    when list.isNotEmpty =>
                  [_grid(context, list)],
                AsyncValue(hasValue: true) => [
                  SliverToBoxAdapter(
                    child: GdEmptyView(
                      icon: Icons.inventory_2_outlined,
                      title: CatalogText.emptyTitle.of(context),
                    ),
                  ),
                ],
                AsyncError(:final error) => [
                  SliverToBoxAdapter(
                    child: GdErrorView(
                      error: error,
                      onRetry: () => ref.invalidate(popularProductsProvider),
                    ),
                  ),
                ],
                _ => [_skeletonGrid(context)],
              },
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(BuildContext context, List<ProductCard> products) =>
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: GdSpace.page),
        sliver: SliverGrid(
          gridDelegate: productGridDelegate(context),
          delegate: SliverChildBuilderDelegate(
            (context, i) => ProductCardTile(
              key: ValueKey(products[i].id),
              product: products[i],
            ),
            childCount: products.length,
          ),
        ),
      );

  Widget _skeletonGrid(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: GdSpace.page),
    sliver: SliverGrid(
      gridDelegate: productGridDelegate(context),
      delegate: SliverChildBuilderDelegate(
        (_, _) => const _Skeleton(radius: GdRadius.lg),
        childCount: 4,
      ),
    ),
  );
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gd;
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    final unread = signedIn ? ref.watch(unreadCountProvider) : 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(GdSpace.page, 14, 8, 10),
      child: Row(
        children: [
          const Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: GdWordmark(size: 30),
            ),
          ),
          Semantics(
            identifier: 'home.search_open',
            button: true,
            child: IconButton(
              tooltip: CatalogText.search.of(context),
              icon: Icon(Icons.search_rounded, color: c.ink, size: 26),
              onPressed: () => context.push('/catalog/list?q='),
            ),
          ),
          Semantics(
            identifier: 'home.notifications',
            button: true,
            child: IconButton(
              tooltip: CatalogText.notifications.of(context),
              onPressed: () => signedIn
                  ? context.push('/notifications')
                  : goSignIn(context, next: '/notifications'),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    color: c.ink,
                    size: 26,
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 1,
                      top: 1,
                      child: Container(
                        key: const ValueKey('home.unread_dot'),
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: c.danger,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.surface, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({this.radius = GdRadius.md});
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.gd.skeleton,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
