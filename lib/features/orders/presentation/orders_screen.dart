import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../application/orders_list_controller.dart';
import '../data/order_models.dart';
import 'order_widgets.dart';
import 'orders_text.dart';

/// "Buyurtmalar": the customer's orders by scope, with infinite scroll.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  OrderScope _scope = OrderScope.all;

  static const _scopes = {
    OrderScope.all: OrdersText.scopeAll,
    OrderScope.active: OrdersText.scopeActive,
    OrderScope.completed: OrdersText.scopeCompleted,
    OrderScope.cancelled: OrdersText.scopeCancelled,
  };

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 400) {
      ref.read(ordersListProvider(_scope).notifier).loadMore();
    }
    return false;
  }

  Future<void> _open(OrderSummary order) async {
    await context.push(order.routeAt(clock.now()));
    // The order may have been paid or cancelled meanwhile.
    if (mounted) ref.invalidate(ordersListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ordersListProvider(_scope));
    return Scaffold(
      appBar: GdHeader(title: OrdersText.ordersTitle.of(context)),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              GdSpace.page,
              4,
              GdSpace.page,
              8,
            ),
            child: Row(
              children: [
                for (final entry in _scopes.entries) ...[
                  Semantics(
                    identifier: 'orders.scope.${entry.key.code}',
                    button: true,
                    selected: entry.key == _scope,
                    child: GdFilterChip(
                      label: entry.value.of(context),
                      selected: entry.key == _scope,
                      onTap: () => setState(() => _scope = entry.key),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: switch (async) {
              AsyncValue(value: final OrdersListState list) => _list(
                context,
                list,
              ),
              AsyncError(:final error) => GdErrorView(
                error: error,
                onRetry: () => ref.invalidate(ordersListProvider(_scope)),
              ),
              _ => const GdLoading(),
            },
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, OrdersListState list) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.refresh(ordersListProvider(_scope).future),
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: box.maxHeight,
              child: GdEmptyView(
                icon: Icons.receipt_long_outlined,
                title: OrdersText.emptyTitle.of(context),
                body: _scope == OrderScope.all
                    ? OrdersText.emptyBody.of(context)
                    : OrdersText.emptyScope.of(context),
                action: _scope == OrderScope.all
                    ? SizedBox(
                        width: 220,
                        child: GdButton(
                          label: OrdersText.toCatalog.of(context),
                          onPressed: () => context.go('/catalog'),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
      );
    }
    final footer = list.hasMore || list.loadMoreError != null;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(ordersListProvider(_scope).future),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(GdSpace.page, 6, GdSpace.page, 24),
          itemCount: list.items.length + (footer ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            if (i < list.items.length) {
              final order = list.items[i];
              return OrderCard(order: order, onTap: () => _open(order));
            }
            if (list.loadMoreError != null) {
              return Center(
                child: TextButton.icon(
                  onPressed: () =>
                      ref.read(ordersListProvider(_scope).notifier).loadMore(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    '${OrdersText.loadMoreFailed.of(context)} · ${Strings.retry.of(context)}',
                  ),
                ),
              );
            }
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }
}

/// One order in the list: number, date, status, previews, total.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, required this.onTap});
  final OrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final t = context.gdText;
    final lang = context.language;
    final payable = order.payableAt(clock.now());
    return Semantics(
      identifier: 'orders.item.${order.id}',
      button: true,
      child: GdCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        OrdersText.shortNumber.fmt(context, {'id': order.id}),
                        style: t.subheading.copyWith(fontSize: 17),
                      ),
                      if (order.createdAt != null)
                        Text(
                          formatDateTime(order.createdAt!, lang),
                          style: t.caption,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(child: OrderStatusChip(order: order)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final url in order.previewImages.take(3)) ...[
                  SizedBox.square(
                    dimension: 46,
                    child: GdImage(
                      url: url,
                      seed: url,
                      radius: GdRadius.sm,
                      artSize: 28,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (order.previewImages.isEmpty)
                  SizedBox.square(
                    dimension: 46,
                    child: GdImage(
                      url: null,
                      seed: '${order.id}',
                      radius: GdRadius.sm,
                      artSize: 28,
                    ),
                  ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatMoney(order.total, language: lang),
                      style: t.price,
                    ),
                    Text(
                      OrdersText.itemCount.fmt(context, {'n': order.itemCount}),
                      style: t.caption,
                    ),
                  ],
                ),
              ],
            ),
            if (payable) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 16, color: c.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      OrdersText.payBy.fmt(context, {
                        'time': formatTime(order.payBy!),
                      }),
                      style: t.label.copyWith(color: c.warning, fontSize: 13),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.inkMuted),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
