import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/config/app_config.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../orders/application/payment_controller.dart';
import '../../orders/data/order_models.dart';
import '../../orders/data/orders_api.dart';
import '../../orders/presentation/order_actions.dart';
import '../../orders/presentation/orders_text.dart';
import '../../settings/data/public_settings.dart';

/// "To‘lov" (PDF p.6): the reservation countdown, the provider choice and the
/// hand-off to Click/Payme in the system browser; polls the order on return
/// and on every app resume until it is paid (contract §2.7.2).
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({
    super.key,
    required this.orderId,
    this.returned = false,
  });
  final int orderId;
  final bool returned;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  late final PaymentController _controller;
  late final AppLifecycleListener _lifecycle;
  String? _provider;
  bool _paying = false;
  bool _cancelling = false;
  bool _reordering = false;
  bool _simulating = false;
  bool _left = false;

  int get _id => widget.orderId;

  @override
  void initState() {
    super.initState();
    _controller = PaymentController(
      fetch: () => ref.read(ordersApiProvider).detail(_id),
    );
    _controller.addListener(_onChange);
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    unawaited(
      _controller.load().then((_) {
        if (widget.returned) _controller.startPolling();
      }),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller.removeListener(_onChange);
    _controller.dispose();
    super.dispose();
  }

  void _onResume() {
    final o = _controller.order;
    if (o == null || o.status == OrderStatus.awaitingPayment) {
      _controller.startPolling(immediate: true);
    }
  }

  void _onChange() {
    if (!mounted || _left) return;
    if (_controller.phase == PaymentPhase.paid) {
      _left = true;
      context.go('/orders/$_id/success');
    }
  }

  /// The radio choice: the order's provider when the shop offers it.
  String? _selected(List<String> providers) {
    if (providers.isEmpty) return null;
    final chosen = _provider;
    if (chosen != null && providers.contains(chosen)) return chosen;
    final current = _controller.order?.payment.provider;
    if (current != null && providers.contains(current)) return current;
    return providers.first;
  }

  Future<void> _pay(String provider) async {
    if (_paying) return;
    setState(() => _paying = true);
    try {
      final result = await runGuarded(
        context,
        // One intent per provider: a retried key must carry the same body
        // (a switch with the old key would answer `idempotency_key_reused`).
        () => withIntentKey(
          ref,
          'pay.$_id.$provider',
          (key) => ref
              .read(ordersApiProvider)
              .pay(_id, provider, idempotencyKey: key),
        ),
      );
      final uri = Uri.tryParse(result.webUrl);
      var opened = false;
      if (uri != null) {
        try {
          opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
        } on Object {
          opened = false;
        }
      }
      if (!mounted) return;
      if (!opened) showSnack(context, OrdersText.cannotOpen.of(context));
      unawaited(_controller.refresh());
    } on ApiException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'payment_in_progress':
          // Another provider's transaction is in flight: go back to it.
          final inFlight = e.details['provider'];
          setState(
            () => _provider = inFlight is String
                ? inFlight
                : _controller.order?.payment.provider,
          );
          showError(context, e);
          unawaited(_controller.refresh());
        case 'order_expired' || 'already_paid' || 'not_payable':
          showError(context, e);
          await _controller.refresh();
        default:
          showError(context, e);
      }
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _cancel() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);
    final order = await cancelOrder(context, ref, _id);
    if (!mounted) return;
    setState(() => _cancelling = false);
    if (order != null) {
      _left = true;
      ref.invalidate(orderDetailProvider(_id));
      context.pushReplacement('/orders/$_id');
    } else {
      unawaited(_controller.refresh());
    }
  }

  Future<void> _reorder() async {
    if (_reordering) return;
    setState(() => _reordering = true);
    final ok = await reorderOrder(context, ref, _id);
    if (ok) _left = true;
    if (mounted) setState(() => _reordering = false);
  }

  Future<void> _simulate(String? provider) async {
    setState(() => _simulating = true);
    try {
      await ref
          .read(ordersApiProvider)
          .simulatePayment(_id, provider: provider);
      _controller.startPolling(immediate: true);
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _simulating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(publicSettingsProvider).value;
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final phase = _controller.phase;
        final order = _controller.order;
        final providers =
            settings?.paymentProviders ??
            [if (order?.payment.provider != null) order!.payment.provider!];
        final selected = _selected(providers);
        return Scaffold(
          appBar: GdHeader(title: OrdersText.payTitle.of(context)),
          body: switch (phase) {
            PaymentPhase.loading => const GdLoading(),
            PaymentPhase.failed => _failed(context),
            PaymentPhase.expired ||
            PaymentPhase.cancelled => _ended(context, order!, phase),
            PaymentPhase.paid => const GdLoading(),
            PaymentPhase.payable => _payable(
              context,
              order!,
              providers,
              selected,
            ),
          },
          bottomNavigationBar:
              phase == PaymentPhase.payable && order!.actions.pay
              ? GdBottomBar(
                  child: GdButton(
                    label: selected == null
                        ? OrdersText.pay.of(context)
                        : OrdersText.payWith.fmt(context, {
                            'p': providerName(selected),
                          }),
                    loading: _paying,
                    semanticsId: 'pay.submit',
                    onPressed: selected == null ? null : () => _pay(selected),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _failed(BuildContext context) {
    final error = _controller.error!;
    if (error is ApiException && error.status == 404) {
      return GdEmptyView(
        icon: Icons.receipt_long_outlined,
        title: OrdersText.notFoundTitle.of(context),
        body: OrdersText.notFoundBody.of(context),
      );
    }
    return GdErrorView(error: error, onRetry: _controller.load);
  }

  Widget _payable(
    BuildContext context,
    OrderDetail order,
    List<String> providers,
    String? selected,
  ) {
    final c = context.gd;
    final t = context.gdText;
    final lang = context.language;
    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(GdSpace.page, 4, GdSpace.page, 24),
        children: [
          _reservationCard(context, order),
          const SizedBox(height: 16),
          GdCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        OrdersText.orderNumber.fmt(context, {'id': order.id}),
                        style: t.caption.copyWith(fontSize: 13),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        [
                          OrdersText.itemCount.fmt(context, {
                            'n': order.itemCount,
                          }),
                          if (order.fulfilmentLabel.isNotEmpty)
                            order.fulfilmentLabel,
                        ].join(' · '),
                        style: t.caption.copyWith(fontSize: 13),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        OrdersText.toPay.of(context),
                        style: t.subheading,
                      ),
                    ),
                    Text(
                      formatMoney(order.payable, language: lang),
                      style: t.priceLg,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Text(
            OrdersText.methodTitle.of(context),
            style: t.heading.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 14),
          if (providers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(OrdersText.noProviders.of(context), style: t.bodySm),
            ),
          for (final p in providers) ...[
            _ProviderCard(
              provider: p,
              selected: p == selected,
              enabled: !_paying,
              onTap: () => setState(() => _provider = p),
            ),
            const SizedBox(height: 12),
          ],
          const _CashCard(),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.verified_user_outlined,
                  size: 18,
                  color: c.goldInk,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(OrdersText.safetyNote.of(context), style: t.bodySm),
              ),
            ],
          ),
          if (order.actions.cancel) ...[
            const SizedBox(height: 18),
            Center(
              child: Semantics(
                identifier: 'pay.cancel',
                button: true,
                child: TextButton(
                  onPressed: _cancelling ? null : _cancel,
                  style: TextButton.styleFrom(foregroundColor: c.danger),
                  child: Text(OrdersText.cancel.of(context)),
                ),
              ),
            ),
          ],
          if (AppConfig.allowDevTools) ...[
            const SizedBox(height: 8),
            Center(
              child: SizedBox(
                width: 260,
                child: GdOutlineButton(
                  label: OrdersText.simulate.of(context),
                  icon: Icons.science_outlined,
                  semanticsId: 'pay.simulate',
                  onPressed: _simulating ? null : () => _simulate(selected),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reservationCard(BuildContext context, OrderDetail order) {
    final c = context.gd;
    final t = context.gdText;
    final checking = _controller.inProgressLabel;
    final remaining = _controller.remaining;
    final title = checking != null
        ? (checking.isEmpty
              ? OrdersText.checkingFallback.of(context)
              : checking)
        : OrdersText.reservedTitle.of(context);
    final body = checking != null
        ? OrdersText.checkingBody.of(context)
        : OrdersText.reservedBody.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 18, 18),
      decoration: BoxDecoration(
        color: c.goldSoft,
        borderRadius: BorderRadius.circular(GdRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: c.surfaceRaised,
              shape: BoxShape.circle,
            ),
            child: Icon(
              checking != null
                  ? Icons.hourglass_top_rounded
                  : Icons.schedule_rounded,
              color: c.goldInk,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.subheading),
                const SizedBox(height: 2),
                Text(body, style: t.bodySm.copyWith(color: c.ink)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (checking != null)
            SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: c.goldInk,
              ),
            )
          else if (remaining != null)
            Semantics(
              identifier: 'pay.countdown',
              child: Text(
                formatCountdown(remaining),
                style: t.priceLg.copyWith(
                  letterSpacing: 1.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ended(BuildContext context, OrderDetail order, PaymentPhase phase) {
    final c = context.gd;
    final t = context.gdText;
    final expired =
        phase == PaymentPhase.expired || order.cancellation?.expired == true;
    final title = expired
        ? OrdersText.expiredTitle.of(context)
        : (order.cancellation?.label ?? OrdersText.cancelledTitle.of(context));
    return ListView(
      padding: const EdgeInsets.fromLTRB(GdSpace.page, 48, GdSpace.page, 24),
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: c.goldSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              expired ? Icons.timer_off_outlined : Icons.cancel_outlined,
              size: 38,
              color: c.goldInk,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(title, textAlign: TextAlign.center, style: t.title),
        const SizedBox(height: 8),
        Text(
          expired
              ? OrdersText.expiredBody.of(context)
              : OrdersText.orderNumber.fmt(context, {'id': order.id}),
          textAlign: TextAlign.center,
          style: t.bodyMd.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: 28),
        GdButton(
          label: OrdersText.reorderShort.of(context),
          icon: Icons.replay_rounded,
          loading: _reordering,
          semanticsId: 'pay.reorder',
          onPressed: _reorder,
        ),
        const SizedBox(height: 10),
        Center(
          child: Semantics(
            identifier: 'pay.orders',
            button: true,
            child: TextButton(
              onPressed: () => context.go('/orders'),
              child: Text(OrdersText.ordersLink.of(context)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Radio card of one payment provider ("C · Click").
class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });
  final String provider;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final t = context.gdText;
    final name = providerName(provider);
    final hint = switch (provider) {
      'click' => OrdersText.clickHint.of(context),
      'payme' => OrdersText.paymeHint.of(context),
      _ => OrdersText.providerHint.fmt(context, {'p': name}),
    };
    final radius = BorderRadius.circular(GdRadius.lg);
    return Semantics(
      identifier: 'pay.provider.$provider',
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? c.goldSoft : c.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? c.gold : c.lineStrong,
            width: selected ? 1.6 : 1.1,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _LetterTile(letter: name.isEmpty ? '?' : name[0]),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: t.subheading.copyWith(fontSize: 17)),
                      const SizedBox(height: 2),
                      Text(hint, style: t.bodySm),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _Radio(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LetterTile extends StatelessWidget {
  const _LetterTile({required this.letter, this.muted = false, this.icon});
  final String letter;
  final bool muted;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: muted ? c.surface : c.surfaceRaised,
        borderRadius: BorderRadius.circular(GdRadius.md),
        border: Border.all(color: c.line),
      ),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, size: 22, color: c.inkMuted)
          : Text(
              letter.toUpperCase(),
              style: context.gdText.label.copyWith(fontSize: 15),
            ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? c.goldInk : c.lineStrong,
          width: 1.6,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: c.goldInk,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

/// Disabled "Naqd pul · Tez orada" card with a dashed border.
class _CashCard extends StatelessWidget {
  const _CashCard();

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final t = context.gdText;
    return Semantics(
      identifier: 'pay.provider.cash',
      enabled: false,
      child: CustomPaint(
        painter: _DashedBorder(
          color: c.lineStrong.withValues(alpha: 0.7),
          radius: GdRadius.lg,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const _LetterTile(
                letter: '',
                muted: true,
                icon: Icons.payments_outlined,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      OrdersText.cash.of(context),
                      style: t.subheading.copyWith(
                        fontSize: 17,
                        color: c.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(Strings.comingSoon.of(context), style: t.bodySm),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.radius != radius;
}
