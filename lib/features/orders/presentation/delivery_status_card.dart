import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../data/order_models.dart';
import 'delivery_format.dart';
import 'orders_text.dart';

/// Opens the carrier's tracking page outside the app; swappable in tests.
typedef TrackingOpener = Future<bool> Function(Uri url);

final trackingOpenerProvider = Provider<TrackingOpener>(
  (ref) =>
      (url) => launchUrl(url, mode: LaunchMode.externalApplication),
);

/// The carrier's tracking page of [order] while the parcel is under way:
/// `delivery.tracking_url`, else `shipment.tracking_url` (https only); null
/// once the order or the parcel is done.
String? trackingUrlOf(OrderDetail order) {
  final delivery = order.delivery;
  if (delivery == null) return null;
  final open =
      order.status != OrderStatus.cancelled &&
      order.status != OrderStatus.delivered;
  if (!open || delivery.isFinished) return null;
  final fallback = order.shipment?.trackingUrl;
  return delivery.trackingUrl ??
      (fallback != null && Uri.tryParse(fallback)?.scheme == 'https'
          ? fallback
          : null);
}

/// The courier part of a Yandex order's status card (the website's
/// `DeliveryStatus`): the method, the shipment stage, the promised window,
/// the courier's name and vehicle while one is on the job (never a phone
/// number), Yandex's tracking page and the auto-refresh note. Labels are
/// the server's.
class DeliveryStatusCard extends ConsumerWidget {
  const DeliveryStatusCard({
    super.key,
    required this.order,
    required this.live,
  });

  final OrderDetail order;

  /// The screen re-reads the order on its own (shows "Holat avtomatik
  /// yangilanadi").
  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delivery = order.delivery!;
    final c = context.gd;
    final t = context.gdText;
    final open =
        order.status != OrderStatus.cancelled &&
        order.status != OrderStatus.delivered;
    final carrier = (order.shipment?.carrier.isNotEmpty ?? false)
        ? order.shipment!.carrier
        : 'Yandex';
    final eta = open && delivery.etaShown
        ? formatEtaWindow(
            delivery.etaFrom,
            delivery.etaTo,
            context.language,
            now: clock.now(),
          )
        : null;
    final courier = delivery.courierLine;
    final tracking = trackingUrlOf(order);

    Widget row(String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: t.bodySm.copyWith(color: c.inkMuted)),
          const SizedBox(width: 12),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: value),
          ),
        ],
      ),
    );
    Widget text(String value) => Text(
      value,
      textAlign: TextAlign.right,
      style: t.label.copyWith(fontSize: 14),
    );

    return Semantics(
      identifier: 'order.delivery',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (delivery.methodLabel != null)
            row(
              OrdersText.deliveryMethod.of(context),
              text('$carrier · ${delivery.methodLabel}'),
            ),
          if (delivery.stage != null && delivery.stageLabel != null)
            row(
              OrdersText.deliveryStage.of(context),
              Semantics(
                liveRegion: true,
                child: GdStatusChip(
                  label: delivery.stageLabel!,
                  tone: stageTone(delivery.stage),
                  uppercase: false,
                ),
              ),
            ),
          if (eta != null) row(OrdersText.deliveryEta.of(context), text(eta)),
          if (courier != null)
            row(OrdersText.courier.of(context), text(courier)),
          if (tracking != null) ...[
            const SizedBox(height: 8),
            GdOutlineButton(
              label: OrdersText.trackCourier.of(context),
              icon: Icons.map_outlined,
              semanticsId: 'order.delivery.track',
              onPressed: () async {
                bool ok;
                try {
                  ok = await ref.read(trackingOpenerProvider)(
                    Uri.parse(tracking),
                  );
                } on Object {
                  ok = false;
                }
                if (!ok && context.mounted) {
                  showSnack(context, OrdersText.cannotOpenTracking.of(context));
                }
              },
            ),
          ],
          if (live) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: c.gold,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    OrdersText.deliveryLive.of(context),
                    style: t.caption,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
