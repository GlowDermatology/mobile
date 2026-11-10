import 'package:flutter/material.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../data/order_models.dart';
import 'orders_text.dart';

GdTone toneForStatus(String status) => switch (status) {
  OrderStatus.awaitingPayment => GdTone.warning,
  OrderStatus.delivered => GdTone.success,
  OrderStatus.cancelled => GdTone.danger,
  OrderStatus.handedToCourier => GdTone.neutral,
  _ => GdTone.gold,
};

/// The server's status label as an uppercase chip.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.order, this.tone});
  final OrderSummary order;
  final GdTone? tone;

  @override
  Widget build(BuildContext context) => GdStatusChip(
    label: order.statusLabel,
    tone: tone ?? toneForStatus(order.status),
  );
}

/// "Mahsulotlar ........ 808 000 so‘m"
class AmountRow extends StatelessWidget {
  const AmountRow({
    super.key,
    required this.label,
    required this.value,
    this.strong = false,
    this.leading,
    this.valueColor,
  });
  final String label;
  final String value;
  final bool strong;
  final Widget? leading;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final t = context.gdText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(
            child: Text(
              label,
              style: strong
                  ? t.subheading.copyWith(fontSize: 17)
                  : t.bodyMd.copyWith(color: context.gd.inkMuted),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style:
                (strong
                        ? t.priceLg.copyWith(fontSize: 20)
                        : t.label.copyWith(fontSize: 15))
                    .copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}

/// The subtitle of a progress step: "23-oktabr, 14:02 · Click orqali".
String stepSubtitle(
  ProgressStep step,
  List<TimelineEntry> timeline,
  AppLanguage language,
) {
  final entry = timelineFor(step, timeline);
  final at = step.at ?? entry?.at;
  final parts = <String>[
    if (at != null) formatDateTime(at, language),
    if (entry != null)
      if (entry.subtitle != null && entry.subtitle!.isNotEmpty)
        entry.subtitle!
      else if (entry.title != step.label && entry.title.isNotEmpty)
        entry.title,
  ];
  return parts.join(' · ');
}

/// Vertical stepper built from `progress[]` (PDF p.8).
class OrderProgress extends StatelessWidget {
  const OrderProgress({super.key, required this.order});
  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final steps = order.progress;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _StepRow(
            step: steps[i],
            subtitle: _subtitle(context, steps[i]),
            last: i == steps.length - 1,
            nextReached:
                i + 1 < steps.length &&
                (steps[i + 1].state == ProgressState.done ||
                    steps[i + 1].state == ProgressState.current),
          ),
      ],
    );
  }

  String _subtitle(BuildContext context, ProgressStep step) {
    final text = stepSubtitle(step, order.timeline, context.language);
    if (text.isNotEmpty) return text;
    final delivery = order.fulfilment == 'delivery';
    final open =
        step.state == ProgressState.current ||
        step.state == ProgressState.upcoming;
    if (delivery && step.step == 'delivered' && open) {
      return OrdersText.awaitBts.of(context);
    }
    return '';
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.subtitle,
    required this.last,
    required this.nextReached,
  });
  final ProgressStep step;
  final String subtitle;
  final bool last;
  final bool nextReached;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final t = context.gdText;
    final done = step.state == ProgressState.done;
    final muted =
        step.state == ProgressState.upcoming ||
        step.state == ProgressState.skipped;
    final cancelledStep = step.step == 'cancelled';
    Widget marker;
    switch (step.state) {
      case ProgressState.done:
        marker = Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: cancelledStep ? c.danger : c.gold,
            shape: BoxShape.circle,
          ),
          child: Icon(
            cancelledStep ? Icons.close_rounded : Icons.check_rounded,
            size: 16,
            color: cancelledStep ? Colors.white : c.onGold,
          ),
        );
      case ProgressState.current:
        marker = Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            shape: BoxShape.circle,
            border: Border.all(color: c.gold, width: 2),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c.gold, shape: BoxShape.circle),
          ),
        );
      case ProgressState.upcoming:
        marker = Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c.lineStrong, width: 1.5),
          ),
        );
      case ProgressState.skipped:
        marker = Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c.line, width: 1.5),
          ),
          child: Icon(Icons.remove_rounded, size: 14, color: c.inkMuted),
        );
    }
    return Semantics(
      container: true,
      label: '${step.label}${subtitle.isEmpty ? '' : ', $subtitle'}',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  marker,
                  if (!last)
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 2,
                          color: done && nextReached ? c.gold : c.line,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: last ? 0 : 14, top: 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.label,
                      style: t.subheading.copyWith(
                        color: muted ? c.inkMuted : c.ink,
                        fontWeight: step.state == ProgressState.upcoming
                            ? FontWeight.w500
                            : FontWeight.w700,
                        decoration: step.state == ProgressState.skipped
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: t.caption),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One product line: image, name, "1 × 312 000 so‘m · Aksiya", line total.
class OrderItemRow extends StatelessWidget {
  const OrderItemRow({super.key, required this.item});
  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final lang = context.language;
    final t = context.gdText;
    final qty = OrdersText.quantityPrice.fmt(context, {
      'q': item.quantity,
      'price': formatMoney(item.unitPrice, language: lang),
    });
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 52,
            child: GdImage(url: item.imageUrl, seed: item.name, artSize: 34),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: t.label.copyWith(fontSize: 15),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.promo ? '$qty · ${OrdersText.promo.of(context)}' : qty,
                  style: t.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatNumber(item.lineTotal, language: lang),
            style: t.label.copyWith(fontSize: 15),
          ),
        ],
      ),
    );
  }
}
