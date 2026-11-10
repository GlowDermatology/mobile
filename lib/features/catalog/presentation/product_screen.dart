import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/format/money.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../../core/widgets/rings.dart';
import '../../auth/application/session_controller.dart';
import '../../cart/application/cart_controller.dart';
import '../../loyalty/data/cashback_summary.dart';
import '../../settings/data/public_settings.dart';
import '../data/catalog_models.dart';
import '../data/catalog_providers.dart';
import 'catalog_text.dart';
import 'widgets/banner_carousel.dart' show PageDots;
import 'widgets/cart_actions.dart';
import 'widgets/product_card_tile.dart';

/// Product page (PDF p.4): gallery on the rings motif, then the sheet with
/// the name, price, cashback, stock, texts and the sticky "Savatga qo‘shish".
class ProductScreen extends ConsumerWidget {
  const ProductScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productDetailProvider(id));
    return switch (product) {
      AsyncValue(hasValue: true, value: final p?) => _ProductView(product: p),
      AsyncError(:final error) => Scaffold(
        appBar: const GdHeader(title: ''),
        body: error is ApiException && error.status == 404
            ? GdEmptyView(
                icon: Icons.search_off_rounded,
                title: CatalogText.notFound.of(context),
              )
            : GdErrorView(
                error: error,
                onRetry: () => ref.invalidate(productDetailProvider(id)),
              ),
      ),
      _ => const _ProductSkeleton(),
    };
  }
}

class _ProductView extends ConsumerStatefulWidget {
  const _ProductView({required this.product});
  final ProductDetail product;

  @override
  ConsumerState<_ProductView> createState() => _ProductViewState();
}

enum _Tab { description, ingredients, usage }

class _ProductViewState extends ConsumerState<_ProductView> {
  _Tab? _tab;
  bool _busy = false;

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(productDetailProvider(widget.product.id));
    ref.read(cartProvider.notifier).reload().ignore();
    try {
      await ref.read(productDetailProvider(widget.product.id).future);
    } on Object {
      // the screen shows the error
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final c = context.gd;
    final t = context.gdText;
    final lang = context.language;

    final tabs = <(_Tab, Tr, String)>[
      if (p.description.isNotEmpty)
        (_Tab.description, CatalogText.tabDescription, p.description),
      if (p.ingredients.isNotEmpty)
        (_Tab.ingredients, CatalogText.tabIngredients, p.ingredients),
      if (p.usage.isNotEmpty) (_Tab.usage, CatalogText.tabUsage, p.usage),
    ];
    final current =
        tabs.where((e) => e.$1 == _tab).firstOrNull ?? tabs.firstOrNull;

    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    final percent = signedIn
        ? ref.watch(cashbackSummaryProvider.select((s) => s.value?.percent))
        : null;
    final cashback = signedIn && !p.card.promo
        ? cashbackFor(p.card.price, percent)
        : 0;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: MediaQuery.paddingOf(context).top,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _Hero(product: p)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                GdSpace.page,
                4,
                GdSpace.page,
                28,
              ),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      if (p.card.category != null)
                        Flexible(
                          child: Semantics(
                            identifier: 'product.category',
                            button: true,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => context.push(
                                Uri(
                                  path: '/catalog/list',
                                  queryParameters: {
                                    'category': p.card.category!.slug,
                                  },
                                ).toString(),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: c.goldSoft,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  p.card.category!.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.label.copyWith(fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (p.card.promo) ...[
                        const SizedBox(width: 8),
                        const PromoBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    p.card.name,
                    style: t.displayLg.copyWith(fontSize: 32, height: 1.15),
                  ),
                  if (p.card.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(p.card.subtitle, style: t.bodySm),
                  ],
                  const SizedBox(height: 18),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Text(
                        formatMoney(p.card.price, language: lang),
                        style: t.priceLg,
                      ),
                      if (cashback > 0)
                        Container(
                          key: const ValueKey('product.cashback'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: c.goldSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.toll_outlined,
                                size: 17,
                                color: c.goldInk,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                CatalogText.cashback.fmt(context, {
                                  'amount': formatMoney(
                                    cashback,
                                    language: lang,
                                  ),
                                }),
                                style: t.label.copyWith(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (p.card.promo) ...[
                    const SizedBox(height: 8),
                    Text(
                      CatalogText.promoNoCashback.of(context),
                      style: t.caption,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _StockLine(inStock: p.card.inStock),
                  if (current != null) ...[
                    const SizedBox(height: 22),
                    if (tabs.length > 1)
                      _Segmented(
                        tabs: [for (final e in tabs) (e.$1, e.$2.of(context))],
                        selected: current.$1,
                        onSelect: (tab) => setState(() => _tab = tab),
                      )
                    else
                      Text(current.$2.of(context), style: t.subheading),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Align(
                        key: ValueKey(current.$1),
                        alignment: Alignment.topLeft,
                        child: SelectableText(
                          current.$3,
                          style: t.bodyMd.copyWith(height: 1.5),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _bottomBar(context),
    );
  }

  Widget _bottomBar(BuildContext context) {
    final p = widget.product;
    final t = context.gdText;
    final salesEnabled = ref.watch(
      publicSettingsProvider.select((s) => s.value?.onlineSalesEnabled ?? true),
    );
    final (cartQty, lineMaxReached) = ref.watch(
      cartProvider.select((s) {
        final cart = s.value;
        if (cart == null) return (null, false);
        final line = cart.items.where((l) => l.productId == p.id).firstOrNull;
        return (line?.quantity ?? 0, line?.maxReached ?? false);
      }),
    );
    final quantity = cartQuantityFor(
      cartQuantity: cartQty,
      inCartQuantity: p.card.inCartQuantity,
    );

    if (!salesEnabled) {
      return GdBottomBar(
        child: Text(
          CatalogText.salesOff.of(context),
          textAlign: TextAlign.center,
          style: t.bodySm,
        ),
      );
    }
    if (quantity > 0) {
      final maxReached =
          lineMaxReached || (p.maxQuantity > 0 && quantity >= p.maxQuantity);
      return GdBottomBar(
        child: Row(
          children: [
            SizedBox(
              width: 150,
              child: WideStepper(
                value: quantity,
                height: 52,
                busy: _busy,
                idPrefix: 'product.qty',
                onMinus: () => _guard(
                  () => setCartQuantity(context, ref, p.id, quantity - 1),
                ),
                onPlus: () {
                  if (maxReached) {
                    showSnack(context, CatalogText.maxReached.of(context));
                    return;
                  }
                  _guard(
                    () => setCartQuantity(context, ref, p.id, quantity + 1),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GdButton(
                label: CatalogText.goToCart.of(context),
                icon: Icons.shopping_bag_outlined,
                semanticsId: 'product.go_cart',
                onPressed: () => context.go('/cart'),
              ),
            ),
          ],
        ),
      );
    }
    if (!p.canAdd) {
      return GdBottomBar(
        child: GdButton(
          label: CatalogText.soldOut.of(context),
          onPressed: null,
          semanticsId: 'product.add',
        ),
      );
    }
    return GdBottomBar(
      child: GdButton(
        label: CatalogText.addToCart.of(context),
        icon: Icons.shopping_bag_outlined,
        loading: _busy,
        semanticsId: 'product.add',
        onPressed: () => _guard(() => addProductToCart(context, ref, p.id)),
      ),
    );
  }
}

class _Hero extends StatefulWidget {
  const _Hero({required this.product});
  final ProductDetail product;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final p = widget.product;
    final urls = p.galleryUrls;
    final top = MediaQuery.paddingOf(context).top;
    final width = MediaQuery.sizeOf(context).width;
    final height = top + (width * 0.9).clamp(300.0, 420.0);
    final count = urls.isEmpty ? 1 : urls.length;

    return SizedBox(
      height: height,
      child: ColoredBox(
        color: c.goldSoft,
        child: Stack(
          children: [
            Positioned(
              left: -width * 0.1,
              right: -width * 0.1,
              top: top + 10,
              bottom: 10,
              child: GdRings(count: 3, color: c.gold.withValues(alpha: 0.55)),
            ),
            Positioned.fill(
              top: top + 64,
              bottom: 52,
              child: urls.isEmpty
                  ? Center(child: ProductArtFallback(seed: p.card.artSeed))
                  : PageView.builder(
                      controller: _controller,
                      itemCount: urls.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) => Semantics(
                        image: true,
                        label: CatalogText.imageLabel.fmt(context, {
                          'i': i + 1,
                          'n': urls.length,
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 48),
                          child: GdImage(
                            url: urls[i],
                            seed: p.card.artSeed,
                            fit: BoxFit.contain,
                            radius: 16,
                            artSize: 140,
                          ),
                        ),
                      ),
                    ),
            ),
            Positioned(
              top: top + 10,
              left: 14,
              child: Semantics(
                identifier: 'product.back',
                button: true,
                label: Strings.back.of(context),
                excludeSemantics: true,
                onTap: () => _back(context),
                child: Material(
                  color: c.surfaceRaised,
                  shape: const CircleBorder(),
                  elevation: 0,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _back(context),
                    child: SizedBox.square(
                      dimension: 46,
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 28,
                        color: c.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (count > 1)
              Positioned(
                top: top + 18,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.surfaceRaised,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    CatalogText.imageCounter.fmt(context, {
                      'i': _index + 1,
                      'n': count,
                    }),
                    style: context.gdText.label.copyWith(fontSize: 13),
                  ),
                ),
              ),
            if (count > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 36,
                child: Center(
                  child: PageDots(count: count, index: _index),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: -1,
              height: 22,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _back(BuildContext context) =>
    context.canPop() ? context.pop() : context.go('/catalog');

/// The illustrated bottle when a product has no photo.
class ProductArtFallback extends StatelessWidget {
  const ProductArtFallback({super.key, required this.seed});
  final String seed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 180,
    height: 220,
    child: GdImage(url: null, seed: seed, artSize: 150, radius: 0),
  );
}

class _StockLine extends StatelessWidget {
  const _StockLine({required this.inStock});
  final bool inStock;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final color = inStock ? c.success : c.danger;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          inStock
              ? CatalogText.inStock.of(context)
              : CatalogText.outOfStock.of(context),
          style: context.gdText.bodyMd.copyWith(
            fontSize: 14,
            color: inStock ? c.ink : c.danger,
          ),
        ),
      ],
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });
  final List<(_Tab, String)> tabs;
  final _Tab selected;
  final ValueChanged<_Tab> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final t = context.gdText;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.goldSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final (tab, label) in tabs)
            Expanded(
              child: Semantics(
                identifier: 'product.tab.${tab.name}',
                button: true,
                selected: tab == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(tab),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: tab == selected
                          ? c.surfaceRaised
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: tab == selected
                          ? const [
                              BoxShadow(
                                color: Color(0x142A2418),
                                blurRadius: 6,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.label.copyWith(
                        fontWeight: tab == selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductSkeleton extends StatelessWidget {
  const _ProductSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final top = MediaQuery.paddingOf(context).top;
    final width = MediaQuery.sizeOf(context).width;
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: c.skeleton,
        borderRadius: BorderRadius.circular(8),
      ),
    );
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: top + (width * 0.9).clamp(300.0, 420.0),
            color: c.goldSoft,
            alignment: Alignment.topLeft,
            padding: EdgeInsets.only(top: top + 10, left: 14),
            child: Semantics(
              identifier: 'product.back',
              button: true,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: c.surfaceRaised,
                  foregroundColor: c.ink,
                  fixedSize: const Size.square(46),
                ),
                tooltip: Strings.back.of(context),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/catalog'),
                icon: const Icon(Icons.chevron_left_rounded, size: 28),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(GdSpace.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(90, 26),
                const SizedBox(height: 16),
                bar(width * 0.7, 32),
                const SizedBox(height: 10),
                bar(140, 14),
                const SizedBox(height: 20),
                bar(160, 28),
                const SizedBox(height: 26),
                bar(double.infinity, 46),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
