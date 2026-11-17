import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/format/money.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../orders/data/order_models.dart';
import '../../orders/presentation/order_actions.dart';
import '../../orders/presentation/orders_text.dart';
import '../application/cart_controller.dart';
import 'cart_text.dart';

/// Where the customer's last checkout stands (the website's `recoveryPhase`).
enum RecoveryPhase {
  /// Awaiting payment, still payable.
  pending,

  /// A provider transaction is in flight: do not pay again.
  confirming,

  /// The reservation ran out (or is about to be cancelled for it).
  expired,

  /// Cancelled before payment.
  cancelled,
}

/// Pure; unit-tested. Payment status and actions stay the server's.
RecoveryPhase recoveryPhase(OrderDetail order, DateTime now) {
  if (order.payment.inProgress) return RecoveryPhase.confirming;
  final payBy = order.payBy;
  if ((order.cancellation?.expired ?? false) ||
      (order.awaitingPayment && payBy != null && !payBy.isAfter(now))) {
    return RecoveryPhase.expired;
  }
  return order.isCancelled ? RecoveryPhase.cancelled : RecoveryPhase.pending;
}

/// The unpaid (or just expired / cancelled) order on top of the cart: its
/// items and totals, "To‘lovni davom ettirish", and "Mahsulotlarni
/// tahrirlash / savatga qaytarish" (cancels it and merges its lines into the
/// cart, contract §2.7.4).
class CheckoutRecoveryCard extends ConsumerStatefulWidget {
  const CheckoutRecoveryCard({
    super.key,
    required this.order,
    this.onBusyChanged,
  });

  final OrderDetail order;

  /// The card is talking to the server (the cart pauses its polling).
  final ValueChanged<bool>? onBusyChanged;

  @override
  ConsumerState<CheckoutRecoveryCard> createState() =>
      _CheckoutRecoveryCardState();
}

class _CheckoutRecoveryCardState extends ConsumerState<CheckoutRecoveryCard> {
  Timer? _ticker;
  late RecoveryPhase _phase;
  bool _busy = false;

  OrderDetail get _order => widget.order;

  @override
  void initState() {
    super.initState();
    _phase = recoveryPhase(_order, clock.now());
    _syncTicker();
  }

  @override
  void didUpdateWidget(CheckoutRecoveryCard old) {
    super.didUpdateWidget(old);
    if (!identical(old.order, _order)) {
      _phase = recoveryPhase(_order, clock.now());
      _syncTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// A 1 s ticker while the order waits for payment against a deadline, so
  /// "Band qilish muddati tugadi" appears when the time runs out.
  void _syncTicker() {
    final needed =
        _order.awaitingPayment &&
        _order.payBy != null &&
        _phase != RecoveryPhase.expired;
    if (!needed) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final next = recoveryPhase(_order, clock.now());
      if (next == _phase) return;
      setState(() => _phase = next);
      _syncTicker();
    });
  }

  void _setBusy(bool busy) {
    // The parent hears it even when a restore removed this card.
    widget.onBusyChanged?.call(busy);
    if (mounted) setState(() => _busy = busy);
  }

  Future<void> _pay() async {
    await context.push('/pay/${_order.id}');
    // Paid, failed or still pending: the cart tells.
    if (mounted) unawaited(ref.read(cartProvider.notifier).reload());
  }

  Future<void> _restore() async {
    if (_busy) return;
    _setBusy(true);
    final notifier = ref.read(cartProvider.notifier);
    try {
      await runGuarded(context, () => notifier.restoreUnpaid(_order.id));
      if (mounted) showSnack(context, CartText.recoveryRestored.of(context));
    } on Object catch (e) {
      if (mounted) showError(context, e);
      // The order may have moved on (paid, in flight): show where it is.
      unawaited(notifier.reload());
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _refresh() async {
    if (_busy) return;
    _setBusy(true);
    try {
      await ref.read(cartProvider.notifier).reload();
    } finally {
      _setBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final t = context.gdText;
    final lang = context.language;
    final order = _order;
    final phase = _phase;
    final (title, body) = switch (phase) {
      RecoveryPhase.confirming => (
        CartText.recoveryConfirmingTitle,
        CartText.recoveryConfirmingBody,
      ),
      RecoveryPhase.expired => (
        CartText.recoveryExpiredTitle,
        CartText.recoveryExpiredBody,
      ),
      RecoveryPhase.cancelled => (
        CartText.recoveryCancelledTitle,
        CartText.recoveryCancelledBody,
      ),
      RecoveryPhase.pending => (CartText.recoveryTitle, CartText.recoveryBody),
    };
    final canPay = phase == RecoveryPhase.pending && order.actions.pay;
    final canEdit =
        phase != RecoveryPhase.confirming &&
        (order.actions.cancel || order.isCancelled);
    final editLabel = order.awaitingPayment && phase != RecoveryPhase.expired
        ? CartText.recoveryEdit
        : CartText.recoveryRestore;

    return Semantics(
      identifier: 'cart.recovery',
      container: true,
      child: GdCard(
        border: Border.all(color: c.goldInk.withValues(alpha: 0.4)),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: 24,
                    color: c.goldInk,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        liveRegion: true,
                        child: Text(title.of(context), style: t.heading),
                      ),
                      const SizedBox(height: 6),
                      Text(body.of(context), style: t.bodySm),
                      const SizedBox(height: 4),
                      Semantics(
                        identifier: 'cart.recovery.details',
                        button: true,
                        child: InkWell(
                          onTap: () => context.push('/orders/${order.id}'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              '${CartText.recoveryDetails.of(context)} · №${order.id}',
                              style: t.bodySm.copyWith(
                                color: c.ink,
                                decoration: TextDecoration.underline,
                                decorationColor: c.gold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final item in order.items) _ItemRow(item: item),
            Divider(height: 16, color: c.line),
            if (order.fulfilment == 'delivery')
              _AmountLine(
                label: CartText.recoveryDeliveryFee.of(context),
                value: formatMoney(order.deliveryFee, language: lang),
              ),
            if (order.cashbackUsed > 0)
              _AmountLine(
                label: CartText.recoveryCashback.of(context),
                value: formatMoney(-order.cashbackUsed, language: lang),
              ),
            _AmountLine(
              label: CartText.recoveryTotal.of(context),
              value: formatMoney(order.total, language: lang),
              strong: true,
            ),
            const SizedBox(height: 12),
            if (canPay) ...[
              GdButton(
                label: CartText.recoveryContinuePayment.of(context),
                icon: Icons.lock_outline_rounded,
                semanticsId: 'cart.recovery.pay',
                onPressed: _busy ? null : _pay,
              ),
              const SizedBox(height: 8),
            ],
            if (canEdit) ...[
              if (canPay)
                GdOutlineButton(
                  label: editLabel.of(context),
                  semanticsId: 'cart.recovery.restore',
                  onPressed: _busy ? null : _restore,
                )
              else
                GdButton(
                  label: editLabel.of(context),
                  loading: _busy,
                  semanticsId: 'cart.recovery.restore',
                  onPressed: _restore,
                ),
              if (order.awaitingPayment) ...[
                const SizedBox(height: 6),
                Text(CartText.recoveryEditHint.of(context), style: t.caption),
              ],
              const SizedBox(height: 4),
            ],
            Semantics(
              identifier: 'cart.recovery.refresh',
              button: true,
              child: TextButton(
                onPressed: _busy ? null : _refresh,
                child: Text(CartText.recoveryRefresh.of(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final t = context.gdText;
    final lang = context.language;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 56,
            child: GdImage(
              url: item.thumbUrl,
              fallbackUrl: item.imageUrl,
              seed: item.name,
              radius: GdRadius.sm,
              artSize: 34,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.label.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  OrdersText.quantityPrice.fmt(context, {
                    'q': item.quantity,
                    'price': formatMoney(item.unitPrice, language: lang),
                  }),
                  style: t.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatMoney(item.lineTotal, language: lang),
            style: t.label.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({
    required this.label,
    required this.value,
    this.strong = false,
  });
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final t = context.gdText;
    final c = context.gd;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: strong
                  ? t.subheading
                  : t.bodySm.copyWith(color: c.inkMuted),
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: strong ? t.price : t.label),
        ],
      ),
    );
  }
}
