import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/gd_colors.dart';
import '../../../../app/theme/gd_theme.dart';
import '../../../../core/format/money.dart';
import '../../../../core/i18n/tr.dart';
import '../../../../core/widgets/gd_widgets.dart';
import '../../../cart/application/cart_controller.dart';
import '../../../settings/data/public_settings.dart';
import '../../data/catalog_models.dart';
import '../catalog_text.dart';
import 'cart_actions.dart';

/// Height of a [ProductCardTile] in a two-column grid, grown with the text
/// scale so the name and the button never clip.
double productTileExtent(BuildContext context) {
  final s = MediaQuery.textScalerOf(context).scale(16) / 16;
  return 240 + 64 * s;
}

/// Grid delegate shared by the home screen and the catalog list.
SliverGridDelegate productGridDelegate(BuildContext context) =>
    SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      mainAxisExtent: productTileExtent(context),
    );

/// Product card of the design (PDF p.3): image well, name, "30 ml · Serumlar"
/// and either the gold price pill (adds to the cart) or a stepper.
class ProductCardTile extends ConsumerStatefulWidget {
  const ProductCardTile({super.key, required this.product});
  final ProductCard product;

  @override
  ConsumerState<ProductCardTile> createState() => _ProductCardTileState();
}

class _ProductCardTileState extends ConsumerState<ProductCardTile> {
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

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final c = context.gd;
    final t = context.gdText;
    final (cartQty, maxReached) = ref.watch(
      cartProvider.select((s) {
        final cart = s.value;
        if (cart == null) return (null, false);
        final line = cart.items.where((l) => l.productId == p.id).firstOrNull;
        return (line?.quantity ?? 0, line?.maxReached ?? false);
      }),
    );
    final quantity = cartQuantityFor(
      cartQuantity: cartQty,
      inCartQuantity: p.inCartQuantity,
    );
    final salesEnabled = ref.watch(
      publicSettingsProvider.select((s) => s.value?.onlineSalesEnabled ?? true),
    );
    final nameHeight = MediaQuery.textScalerOf(context).scale(16) * 22 / 16 * 2;

    return Semantics(
      identifier: 'catalog.product.${p.id}',
      button: true,
      child: GdCard(
        padding: const EdgeInsets.all(10),
        onTap: () => context.push('/product/${p.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GdImage(
                    url: p.mainImageUrl,
                    seed: p.artSeed,
                    radius: 14,
                    artSize: 64,
                  ),
                  if (p.promo)
                    const Positioned(top: 8, left: 8, child: PromoBadge()),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: nameHeight,
              child: Text(
                p.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.subheading,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              p.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.caption,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: _action(
                context,
                c,
                t,
                p,
                quantity: quantity,
                maxReached: maxReached,
                salesEnabled: salesEnabled,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context,
    GdColors c,
    GdText t,
    ProductCard p, {
    required int quantity,
    required bool maxReached,
    required bool salesEnabled,
  }) {
    final price = formatMoney(p.price, language: context.language);
    if (!salesEnabled) {
      return _Pill(
        color: c.goldSoft,
        child: Text(
          price,
          style: t.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      );
    }
    if (quantity > 0) {
      return WideStepper(
        value: quantity,
        busy: _busy,
        idPrefix: 'catalog.card.${p.id}',
        onMinus: () =>
            _guard(() => setCartQuantity(context, ref, p.id, quantity - 1)),
        onPlus: () {
          if (maxReached) {
            showSnack(context, CatalogText.maxReached.of(context));
            return;
          }
          _guard(() => setCartQuantity(context, ref, p.id, quantity + 1));
        },
      );
    }
    if (!p.inStock) {
      return _Pill(
        color: c.line,
        child: Text(
          CatalogText.soldOutPill.of(context),
          style: t.label.copyWith(color: c.inkMuted),
        ),
      );
    }
    return Semantics(
      identifier: 'catalog.add.${p.id}',
      button: true,
      label: '${CatalogText.addToCart.of(context)}: $price',
      excludeSemantics: true,
      onTap: _busy
          ? null
          : () => _guard(() => addProductToCart(context, ref, p.id)),
      child: Material(
        color: c.gold,
        borderRadius: BorderRadius.circular(GdRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(GdRadius.md),
          onTap: _busy
              ? null
              : () => _guard(() => addProductToCart(context, ref, p.id)),
          child: Center(
            child: _busy
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: c.onGold,
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        price,
                        style: t.label.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: c.onGold,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(GdRadius.md),
    ),
    child: Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: child,
        ),
      ),
    ),
  );
}

/// Gold "AKSIYA" badge over a product image.
class PromoBadge extends StatelessWidget {
  const PromoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.gold,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        CatalogText.promoBadge.of(context),
        style: context.gdText.overline.copyWith(color: c.onGold, fontSize: 10),
      ),
    );
  }
}

/// Full-width "− 1 +" stepper of the product card (the shared [GdStepper]
/// only sizes to its content).
class WideStepper extends StatelessWidget {
  const WideStepper({
    super.key,
    required this.value,
    this.onMinus,
    this.onPlus,
    this.busy = false,
    this.idPrefix,
    this.height = 44,
  });
  final int value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final bool busy;
  final String? idPrefix;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    Widget btn(IconData icon, VoidCallback? onTap, String label, String id) =>
        Semantics(
          identifier: idPrefix == null ? null : '$idPrefix.$id',
          button: true,
          label: label,
          excludeSemantics: true,
          onTap: busy ? null : onTap,
          child: InkResponse(
            onTap: busy ? null : onTap,
            radius: height / 2,
            child: SizedBox(
              width: height,
              height: height,
              child: Icon(
                icon,
                size: 20,
                color: onTap == null ? c.line : c.ink,
              ),
            ),
          ),
        );
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GdRadius.md),
        border: Border.all(color: c.lineStrong, width: 1.2),
        color: c.surfaceRaised,
      ),
      child: Row(
        children: [
          btn(Icons.remove, onMinus, '−', 'minus'),
          Expanded(
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: context.gdText.label.copyWith(
                fontSize: 16,
                color: busy ? c.inkMuted : c.ink,
              ),
            ),
          ),
          btn(Icons.add, onPlus, '+', 'plus'),
        ],
      ),
    );
  }
}
