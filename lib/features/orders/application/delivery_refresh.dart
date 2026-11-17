import 'dart:async';

import '../data/order_models.dart';

/// The order page re-reads a Yandex order this often while the parcel is on
/// its way (contract §2.8; the website does the same).
const deliveryRefreshInterval = Duration(seconds: 30);

/// Whether the order page should keep itself current: a paid Yandex order
/// whose shipment is in a live stage. Stops once the stage is delivered,
/// cancelled or returned, or the order itself is delivered or cancelled.
bool shouldRefreshDelivery(OrderSummary order) {
  final delivery = order.delivery;
  if (delivery == null || !delivery.isYandex || delivery.stage == null) {
    return false;
  }
  if (order.status != OrderStatus.processing &&
      order.status != OrderStatus.handedToCourier) {
    return false;
  }
  return !delivery.isFinished;
}

/// Calls [onRefresh] every [interval] while the order is [live] and the
/// screen is visible (app in the foreground, route on top). Coming back from
/// a pause (app backgrounded, another screen on top) refreshes once at once.
/// One timer at most.
class DeliveryRefresher {
  DeliveryRefresher({
    required this.onRefresh,
    this.interval = deliveryRefreshInterval,
  });

  final void Function() onRefresh;
  final Duration interval;

  Timer? _timer;
  bool _paused = false;

  /// True while the timer runs.
  bool get active => _timer != null;

  void update({required bool live, required bool visible}) {
    if (!live) {
      _paused = false;
      _stop();
      return;
    }
    if (!visible) {
      if (active) _paused = true;
      _stop();
      return;
    }
    if (active) return;
    if (_paused) onRefresh();
    _paused = false;
    _timer = Timer.periodic(interval, (_) => onRefresh());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => _stop();
}
