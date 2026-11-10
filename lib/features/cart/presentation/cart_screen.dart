import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/format/money.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../auth/application/session_controller.dart';
import '../../settings/data/public_settings.dart';
import '../application/cart_controller.dart';
import '../data/cart_models.dart';
import 'cart_line_view.dart';
import 'cart_text.dart';

/// The "Savat" tab (PDF page 5, contract §2.5). Selection only helps to remove
/// several lines at once: checkout always takes the whole cart.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _selected = <int>{};
  final _busy = <int>{};
  bool _removing = false;

  Future<void> _guard(int productId, Future<void> Function() body) async {
    setState(() => _busy.add(productId));
    try {
      await body();
    } on ApiException catch (e) {
      if (!mounted) return;
      showError(context, e);
      // A refused write (stock, visibility) changed what the line shows.
      if (e.isConflict || e.status == 404) {
        unawaited(ref.read(cartProvider.notifier).reload());
      }
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(productId));
    }
  }

  Future<bool> _confirm(String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(message, style: context.gdText.bodyMd),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(Strings.cancel.of(context)),
            ),
            Semantics(
              identifier: 'cart.confirmRemove',
              button: true,
              child: TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: context.gd.danger),
                child: Text(CartText.remove.of(context)),
              ),
            ),
          ],
        ),
      ) ??
      false;

  void _setQuantity(CartLine line, int quantity) =>
      _guard(line.productId, () async {
        await ref
            .read(cartProvider.notifier)
            .setQuantity(line.productId, quantity);
      });

  Future<void> _minus(CartLine line) async {
    if (line.quantity <= 1) {
      if (!await _confirm(
        CartText.removeOneConfirm.fmt(context, {'name': line.name}),
      )) {
        return;
      }
      if (!mounted) return;
      return _removeOne(line);
    }
    _setQuantity(line, line.quantity - 1);
  }

  Future<void> _removeOne(CartLine line) => _guard(line.productId, () async {
    await ref.read(cartProvider.notifier).remove([line.productId]);
    _selected.remove(line.productId);
    if (mounted) {
      showSnack(context, CartText.removed.fmt(context, {'name': line.name}));
    }
  });

  Future<void> _removeSelected() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    if (!await _confirm(
      CartText.removeSelectedConfirm.fmt(context, {'n': ids.length}),
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _removing = true);
    try {
      await ref.read(cartProvider.notifier).remove(ids);
      _selected.removeAll(ids);
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    final cartAsync = ref.watch(cartProvider);
    final settings = ref.watch(publicSettingsProvider).value;
    final cart = cartAsync.value;

    if (cart != null) _selected.retainAll(cart.items.map((l) => l.productId));

    final Widget body;
    Widget? bottom;
    if (!signedIn) {
      body = _fill(
        GdEmptyView(
          icon: Icons.shopping_bag_outlined,
          title: CartText.signedOutTitle.of(context),
          body: CartText.signedOutBody.of(context),
          action: SizedBox(
            width: 220,
            child: GdButton(
              label: CartText.signIn.of(context),
              semanticsId: 'cart.signIn',
              onPressed: () => goSignIn(context, next: '/cart'),
            ),
          ),
        ),
      );
    } else if (cart == null) {
      body = cartAsync.hasError
          ? _fill(
              GdErrorView(
                error: cartAsync.error!,
                onRetry: () => ref.invalidate(cartProvider),
              ),
            )
          : const GdLoading();
    } else if (cart.items.isEmpty) {
      body = _fill(
        GdEmptyView(
          icon: Icons.shopping_bag_outlined,
          title: CartText.emptyTitle.of(context),
          body: CartText.emptyBody.of(context),
          action: SizedBox(
            width: 220,
            child: GdButton(
              label: CartText.toCatalog.of(context),
              semanticsId: 'cart.toCatalog',
              onPressed: () => context.go('/catalog'),
            ),
          ),
        ),
      );
    } else {
      body = _list(cart);
      bottom = _PayBar(cart: cart, settings: settings);
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              count: cart?.itemCount ?? 0,
              showCount: signedIn && (cart?.items.isNotEmpty ?? false),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(cartProvider.notifier).reload(),
                child: body,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: bottom,
    );
  }

  /// A scrollable full-height box, so pull-to-refresh works on empty states.
  Widget _fill(Widget child) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: child,
      ),
    ),
  );

  Widget _list(Cart cart) {
    final allSelected =
        cart.items.isNotEmpty && _selected.length == cart.items.length;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(GdSpace.page, 4, GdSpace.page, 24),
      children: [
        _SelectAllRow(
          selected: allSelected,
          count: _selected.length,
          removing: _removing,
          onToggle: () => setState(() {
            if (allSelected) {
              _selected.clear();
            } else {
              _selected.addAll(cart.items.map((l) => l.productId));
            }
          }),
          onRemove: _removeSelected,
        ),
        const SizedBox(height: 12),
        for (final line in cart.items) ...[
          _CartLineCard(
            line: line,
            selected: _selected.contains(line.productId),
            busy: _busy.contains(line.productId),
            onSelect: () => setState(() {
              if (!_selected.remove(line.productId)) {
                _selected.add(line.productId);
              }
            }),
            onMinus: () => _minus(line),
            onPlus: () => _setQuantity(line, line.quantity + 1),
            onFix: (q) => _setQuantity(line, q),
            onRemove: () => _removeOne(line),
            onOpen: () => context.push('/product/${line.productId}'),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count, required this.showCount});
  final int count;
  final bool showCount;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(GdSpace.page, 20, GdSpace.page, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            CartText.title.of(context),
            style: context.gdText.displayLg,
          ),
        ),
        if (showCount)
          Text(
            Strings.products.fmt(context, {'n': count}),
            style: context.gdText.caption,
          ),
      ],
    ),
  );
}

/// Round check of the design (PDF page 5).
class _RoundCheck extends StatelessWidget {
  const _RoundCheck({required this.selected});
  final bool selected;
  static const size = 26.0;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
        border: Border.all(
          color: selected ? c.ink : c.ink.withValues(alpha: 0.45),
          width: 1.4,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: size * 0.62, color: c.ink)
          : null,
    );
  }
}

class _SelectAllRow extends StatelessWidget {
  const _SelectAllRow({
    required this.selected,
    required this.count,
    required this.removing,
    required this.onToggle,
    required this.onRemove,
  });
  final bool selected;
  final int count;
  final bool removing;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            identifier: 'cart.selectAll',
            button: true,
            checked: selected,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(GdRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    _RoundCheck(selected: selected),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        CartText.selectAll.of(context),
                        style: context.gdText.subheading.copyWith(fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (count > 0)
          Semantics(
            identifier: 'cart.removeSelected',
            button: true,
            child: TextButton.icon(
              onPressed: removing ? null : onRemove,
              style: TextButton.styleFrom(foregroundColor: c.danger),
              icon: removing
                  ? SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.danger,
                      ),
                    )
                  : const Icon(Icons.delete_outline_rounded, size: 20),
              label: Text(CartText.removeSelected.fmt(context, {'n': count})),
            ),
          ),
      ],
    );
  }
}

class _CartLineCard extends StatelessWidget {
  const _CartLineCard({
    required this.line,
    required this.selected,
    required this.busy,
    required this.onSelect,
    required this.onMinus,
    required this.onPlus,
    required this.onFix,
    required this.onRemove,
    required this.onOpen,
  });

  final CartLine line;
  final bool selected;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<int> onFix;
  final VoidCallback onRemove;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final t = context.gdText;
    final lang = context.language;
    final view = CartLineView.of(line);
    final id = 'cart.line.${line.productId}';
    final muted = view.inactive;

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          line.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: t.subheading.copyWith(color: muted ? c.inkMuted : c.ink),
        ),
        if (line.volume.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(line.volume, style: t.caption),
        ],
        if (view.showPromo && !muted) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: c.gold,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  CartText.promo.of(context),
                  style: t.overline.copyWith(color: c.onGold, fontSize: 10),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  CartText.noCashback.of(context),
                  style: t.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        if (view.blockingWarning != null) ...[
          const SizedBox(height: 10),
          _WarningBox(text: view.blockingWarning!.of(context)),
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              identifier: '$id.remove',
              button: true,
              child: TextButton.icon(
                onPressed: busy ? null : onRemove,
                style: TextButton.styleFrom(
                  foregroundColor: c.inkMuted,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(
                  CartText.remove.of(context),
                  style: t.caption.copyWith(
                    color: c.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatMoney(line.unitPrice, language: lang),
                    style: t.price,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _LineStepper(
                id: id,
                value: line.quantity,
                busy: busy,
                onMinus: onMinus,
                onPlus: view.canIncrease ? onPlus : null,
              ),
            ],
          ),
          if (view.previousPrice != null) ...[
            const SizedBox(height: 6),
            Text(
              CartText.priceChanged.fmt(context, {
                'previous': formatMoney(view.previousPrice!, language: lang),
              }),
              style: t.caption.copyWith(color: c.warning),
            ),
          ],
          if (view.insufficientAvailable != null) ...[
            const SizedBox(height: 8),
            _WarningBox(
              text: CartText.insufficient.fmt(context, {
                'available': view.insufficientAvailable!,
              }),
            ),
            if (view.fixQuantity != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  identifier: '$id.fix',
                  button: true,
                  child: TextButton(
                    onPressed: busy ? null : () => onFix(view.fixQuantity!),
                    style: TextButton.styleFrom(
                      foregroundColor: c.goldInk,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      CartText.fixQuantity.fmt(context, {
                        'n': view.fixQuantity!,
                      }),
                      style: t.label.copyWith(color: c.goldInk),
                    ),
                  ),
                ),
              ),
          ],
          if (view.showMaxHint) ...[
            const SizedBox(height: 6),
            Text(CartText.maxReached.of(context), style: t.caption),
          ],
        ],
      ],
    );

    return Opacity(
      opacity: muted ? 0.85 : 1,
      child: GdCard(
        padding: const EdgeInsets.fromLTRB(8, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              identifier: '$id.select',
              button: true,
              checked: selected,
              child: InkResponse(
                onTap: onSelect,
                radius: 22,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 26, 8, 26),
                  child: _RoundCheck(selected: selected),
                ),
              ),
            ),
            GestureDetector(
              onTap: onOpen,
              child: SizedBox.square(
                dimension: 78,
                child: muted
                    ? ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          0.5, 0.4, 0.1, 0, 20, //
                          0.3, 0.6, 0.1, 0, 20, //
                          0.3, 0.4, 0.3, 0, 20, //
                          0, 0, 0, 0.7, 0,
                        ]),
                        child: GdImage(
                          url: line.imageUrl,
                          seed: line.name,
                          artSize: 48,
                        ),
                      )
                    : GdImage(url: line.imageUrl, seed: line.name, artSize: 48),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: info),
          ],
        ),
      ),
    );
  }
}

/// The compact quantity stepper of the design (same look as [GdStepper]),
/// with its own semantics ids so the end-to-end harness can tap − and +
/// separately (`cart.line.<id>.minus` / `.plus`; the whole box is
/// `cart.line.<id>.stepper`).
class _LineStepper extends StatelessWidget {
  const _LineStepper({
    required this.id,
    required this.value,
    required this.busy,
    this.onMinus,
    this.onPlus,
  });
  final String id;
  final int value;
  final bool busy;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    const h = 38.0;
    Widget btn(IconData icon, VoidCallback? onTap, String label, String sid) {
      final enabled = onTap != null && !busy;
      return Semantics(
        identifier: '$id.$sid',
        button: true,
        enabled: enabled,
        label: label,
        child: InkResponse(
          onTap: enabled ? onTap : null,
          radius: h / 2,
          child: SizedBox(
            width: h,
            height: h,
            child: Icon(icon, size: 20, color: onTap == null ? c.line : c.ink),
          ),
        ),
      );
    }

    return Semantics(
      identifier: '$id.stepper',
      container: true,
      child: Container(
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GdRadius.md),
          border: Border.all(color: c.lineStrong, width: 1.2),
          color: c.surfaceRaised,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            btn(Icons.remove, onMinus, '−', 'minus'),
            SizedBox(
              width: 26,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: context.gdText.label.copyWith(fontSize: 16),
              ),
            ),
            btn(Icons.add, onPlus, '+', 'plus'),
          ],
        ),
      ),
    );
  }
}

/// Peach box with a warning icon ("Tugagan — buyurtmaga kirmaydi").
class _WarningBox extends StatelessWidget {
  const _WarningBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.warningSoft,
        borderRadius: BorderRadius.circular(GdRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: c.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: context.gdText.caption.copyWith(
                color: c.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sticky gold "To‘lash ··· 784 400 so‘m" bar.
class _PayBar extends StatelessWidget {
  const _PayBar({required this.cart, required this.settings});
  final Cart cart;
  final PublicSettings? settings;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final reason = payBlockReason(cart, settings);
    final enabled = canPay(cart, settings);
    final fg = enabled ? c.onGold : c.inkMuted;
    return GdBottomBar(
      top: reason == null
          ? null
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: c.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reason.of(context),
                    style: context.gdText.caption.copyWith(color: c.ink),
                  ),
                ),
              ],
            ),
      child: Semantics(
        identifier: 'cart.pay',
        button: true,
        enabled: enabled,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: enabled ? () => context.push('/checkout') : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(GdRadius.md),
              ),
            ),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    CartText.pay.of(context),
                    overflow: TextOverflow.ellipsis,
                    style: context.gdText.subheading.copyWith(color: fg),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatMoney(
                        cart.itemsSubtotal,
                        language: context.language,
                      ),
                      style: context.gdText.price.copyWith(color: fg),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
