import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../application/orders_list_controller.dart';
import '../data/order_models.dart';
import '../data/orders_api.dart';
import 'order_actions.dart';
import 'order_widgets.dart';
import 'orders_text.dart';

/// "Buyurtma №10248" (PDF p.8): status, progress, items, totals, address and
/// the actions the server allows (`actions{pay, cancel, reorder}`).
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final int orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _cancelling = false;
  bool _reordering = false;

  int get _id => widget.orderId;

  Future<void> _refresh() => ref
      .refresh(orderDetailProvider(_id).future)
      .then((_) {}, onError: (_) {});

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    final order = await cancelOrder(context, ref, _id);
    if (!mounted) return;
    setState(() => _cancelling = false);
    ref.invalidate(orderDetailProvider(_id));
    if (order != null) ref.invalidate(ordersListProvider);
  }

  Future<void> _openPay() async {
    await context.push('/pay/$_id');
    // The payment may have started (in progress), failed or been cancelled.
    if (mounted) ref.invalidate(orderDetailProvider(_id));
  }

  Future<void> _reorder() async {
    setState(() => _reordering = true);
    await reorderOrder(context, ref, _id);
    if (mounted) setState(() => _reordering = false);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderDetailProvider(_id));
    final order = async.value;
    return Scaffold(
      appBar: GdHeader(title: OrdersText.orderNumber.fmt(context, {'id': _id})),
      body: switch (async) {
        AsyncValue(value: final OrderDetail o) => RefreshIndicator(
          onRefresh: _refresh,
          child: _content(context, o),
        ),
        AsyncError(:final error) => _error(context, error),
        _ => const GdLoading(),
      },
      bottomNavigationBar: order == null ? null : _actions(context, order),
    );
  }

  Widget _error(BuildContext context, Object error) {
    if (error is ApiException && error.status == 404) {
      return GdEmptyView(
        icon: Icons.receipt_long_outlined,
        title: OrdersText.notFoundTitle.of(context),
        body: OrdersText.notFoundBody.of(context),
      );
    }
    return GdErrorView(
      error: error,
      onRetry: () => ref.invalidate(orderDetailProvider(_id)),
    );
  }

  Widget? _actions(BuildContext context, OrderDetail order) {
    final a = order.actions;
    if (!a.pay && !a.cancel && !a.reorder) return null;
    final c = context.gd;
    return GdBottomBar(
      top: order.payBy != null && a.pay
          ? Text(
              OrdersText.payByLine.fmt(context, {
                'time': formatTime(order.payBy!),
              }),
              style: context.gdText.bodySm,
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (a.pay)
            GdButton(
              label: OrdersText.pay.of(context),
              icon: Icons.lock_outline_rounded,
              semanticsId: 'order.pay',
              onPressed: _openPay,
            )
          else if (a.reorder)
            GdButton(
              label: OrdersText.reorder.of(context),
              icon: Icons.replay_rounded,
              loading: _reordering,
              semanticsId: 'order.reorder',
              onPressed: _reorder,
            ),
          if (a.cancel)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Semantics(
                identifier: 'order.cancel',
                button: true,
                child: TextButton(
                  onPressed: _cancelling ? null : _cancel,
                  style: TextButton.styleFrom(foregroundColor: c.danger),
                  child: Text(OrdersText.cancel.of(context)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, OrderDetail order) {
    final c = context.gd;
    final t = context.gdText;
    final lang = context.language;
    final extra = extraTimeline(order.progress, order.timeline);
    final provider = providerName(order.payment.provider);
    final paid = order.payment.isSettled || order.isPaid;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(GdSpace.page, 4, GdSpace.page, 24),
      children: [
        // Status + progress
        GdCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: OrderStatusChip(order: order)),
                  const SizedBox(width: 12),
                  const Spacer(),
                  if (order.shipment != null &&
                      order.shipment!.display.isNotEmpty)
                    Text(
                      order.shipment!.display,
                      style: t.caption.copyWith(fontSize: 13),
                    )
                  else if (order.trackingNumber != null)
                    Text(
                      order.trackingNumber!,
                      style: t.caption.copyWith(fontSize: 13),
                    ),
                ],
              ),
              if (order.progress.isNotEmpty) ...[
                const SizedBox(height: 18),
                OrderProgress(order: order),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Items
        GdCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(OrdersText.itemsTitle.of(context), style: t.heading),
              const SizedBox(height: 6),
              for (final item in order.items) OrderItemRow(item: item),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Totals
        GdCard(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              AmountRow(
                label: OrdersText.subtotal.of(context),
                value: formatMoney(order.itemsSubtotal, language: lang),
              ),
              if (order.fulfilment == 'delivery')
                AmountRow(
                  label: OrdersText.deliveryFee.of(context),
                  value: order.deliveryFee == 0
                      ? OrdersText.free.of(context)
                      : formatMoney(order.deliveryFee, language: lang),
                ),
              if (order.cashbackUsed > 0)
                AmountRow(
                  label: OrdersText.cashbackDiscount.of(context),
                  value: formatMoney(-order.cashbackUsed, language: lang),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: c.line),
              ),
              AmountRow(
                strong: true,
                label: paid
                    ? (provider.isEmpty
                          ? OrdersText.paid.of(context)
                          : OrdersText.paidVia.fmt(context, {'p': provider}))
                    : OrdersText.toPay.of(context),
                value: formatMoney(order.total, language: lang),
              ),
              if (order.cashback.showEarned)
                AmountRow(
                  leading: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: order.cashback.reversed ? c.inkMuted : c.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  label: order.cashback.reversed
                      ? OrdersText.cashbackReversed.of(context)
                      : OrdersText.cashbackEarned.of(context),
                  value:
                      '+${formatMoney(order.cashback.earned, language: lang)}',
                  valueColor: order.cashback.reversed ? c.inkMuted : null,
                ),
            ],
          ),
        ),
        if (order.refund != null) ...[
          const SizedBox(height: 16),
          _InfoCard(
            icon: order.refund!.completed
                ? Icons.check_circle_outline_rounded
                : Icons.sync_rounded,
            title: order.refund!.stateLabel.isEmpty
                ? OrdersText.refund.of(context)
                : order.refund!.stateLabel,
            lines: [
              formatMoney(order.refund!.amount, language: lang),
              if ((order.refund!.completedAt ?? order.refund!.requestedAt) !=
                  null)
                formatDateTime(
                  (order.refund!.completedAt ?? order.refund!.requestedAt)!,
                  lang,
                ),
            ],
          ),
        ],
        if (order.cancellation != null &&
            order.cancellation!.label.isNotEmpty) ...[
          const SizedBox(height: 16),
          _InfoCard(
            icon: Icons.cancel_outlined,
            title: OrdersText.cancelledTitle.of(context),
            lines: [order.cancellation!.label],
          ),
        ],
        if (order.address != null && order.address!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _InfoCard(
            icon: Icons.location_on_outlined,
            title: OrdersText.address.of(context),
            lines: [
              order.address!,
              if (order.addressComment != null &&
                  order.addressComment!.isNotEmpty)
                order.addressComment!,
            ],
          ),
        ] else if (order.pickupAddress != null &&
            order.pickupAddress!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _InfoCard(
            icon: Icons.storefront_outlined,
            title: OrdersText.pickupAddress.of(context),
            lines: [order.pickupAddress!],
          ),
        ],
        if (order.customerNote != null && order.customerNote!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _InfoCard(
            icon: Icons.notes_rounded,
            title: OrdersText.note.of(context),
            lines: [order.customerNote!],
          ),
        ],
        if (extra.isNotEmpty) ...[
          const SizedBox(height: 16),
          GdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(OrdersText.history.of(context), style: t.heading),
                const SizedBox(height: 8),
                for (final e in extra)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title, style: t.label),
                        Text(
                          [
                            if (e.at != null) formatDateTime(e.at!, lang),
                            if (e.subtitle != null && e.subtitle!.isNotEmpty)
                              e.subtitle!,
                          ].join(' · '),
                          style: t.caption,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.lines,
  });
  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final t = context.gdText;
    return GdCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.goldSoft,
              borderRadius: BorderRadius.circular(GdRadius.sm),
            ),
            child: Icon(icon, size: 20, color: c.goldInk),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.label),
                for (final l in lines) ...[
                  const SizedBox(height: 2),
                  Text(l, style: t.bodySm),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
