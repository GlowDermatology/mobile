import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/format/money.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../../core/widgets/rings.dart';
import '../../loyalty/data/cashback_summary.dart';
import '../data/order_models.dart';
import '../data/orders_api.dart';
import 'order_widgets.dart';
import 'orders_text.dart';

/// "Buyurtmangiz qabul qilindi" (PDF p.7), shown once the payment is confirmed.
class OrderSuccessScreen extends ConsumerStatefulWidget {
  const OrderSuccessScreen({super.key, required this.orderId});
  final int orderId;

  @override
  ConsumerState<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends ConsumerState<OrderSuccessScreen> {
  @override
  void initState() {
    super.initState();
    // The purchase changed the cashback balance.
    Future.microtask(() {
      if (mounted) ref.invalidate(cashbackSummaryProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderDetailProvider(widget.orderId));
    return Scaffold(
      body: SafeArea(
        child: switch (async) {
          AsyncData(:final value) => _content(context, value),
          AsyncError(:final error) => GdErrorView(
            error: error,
            onRetry: () => ref.invalidate(orderDetailProvider(widget.orderId)),
          ),
          _ => const GdLoading(),
        },
      ),
    );
  }

  Widget _content(BuildContext context, OrderDetail order) {
    final c = context.gd;
    final t = context.gdText;
    final lang = context.language;
    final provider = providerName(order.payment.provider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(GdSpace.page, 36, GdSpace.page, 24),
      children: [
        Center(
          child: SizedBox.square(
            dimension: 200,
            child: GdRings(
              color: c.gold.withValues(alpha: 0.55),
              count: 4,
              child: Center(
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: c.gold,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_rounded, size: 46, color: c.onGold),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          identifier: 'success.title',
          child: Text(
            OrdersText.successTitle.of(context),
            textAlign: TextAlign.center,
            style: t.displayLg,
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            OrdersText.successBody.of(context),
            textAlign: TextAlign.center,
            style: t.bodyMd.copyWith(color: c.inkMuted),
          ),
        ),
        const SizedBox(height: 26),
        GdCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      OrdersText.orderNumber.fmt(context, {'id': order.id}),
                      style: t.subheading.copyWith(fontSize: 17),
                    ),
                  ),
                  OrderStatusChip(order: order, tone: GdTone.gold),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: c.line),
              const SizedBox(height: 6),
              AmountRow(
                label: provider.isEmpty
                    ? OrdersText.paid.of(context)
                    : OrdersText.paidVia.fmt(context, {'p': provider}),
                value: formatMoney(order.payable, language: lang),
              ),
              if (order.cashbackUsed > 0)
                AmountRow(
                  label: OrdersText.cashbackUsed.of(context),
                  value: formatMoney(-order.cashbackUsed, language: lang),
                ),
              if (order.fulfilmentLabel.isNotEmpty)
                AmountRow(
                  label: OrdersText.fulfilment.of(context),
                  value: order.fulfilmentLabel,
                ),
              if (order.cashback.showEarned && !order.cashback.reversed) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: c.successSoft,
                    borderRadius: BorderRadius.circular(GdRadius.md),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: c.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text:
                                    '+${formatMoney(order.cashback.earned, language: lang)} ',
                                style: t.label,
                              ),
                              TextSpan(
                                text: OrdersText.cashbackEarnedBox.of(context),
                              ),
                            ],
                          ),
                          style: t.bodySm.copyWith(color: c.ink),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        GdButton(
          label: OrdersText.track.of(context),
          semanticsId: 'success.track',
          onPressed: () => context.go('/orders/${order.id}'),
        ),
        const SizedBox(height: 10),
        GdOutlineButton(
          label: OrdersText.toCatalog.of(context),
          semanticsId: 'success.catalog',
          onPressed: () => context.go('/catalog'),
        ),
      ],
    );
  }
}
