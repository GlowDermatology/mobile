import '../../../core/network/json.dart';

/// `OrderStatus` literals (contract §3).
abstract final class OrderStatus {
  static const awaitingPayment = 'awaiting_payment';
  static const processing = 'processing';
  static const handedToCourier = 'handed_to_courier';
  static const delivered = 'delivered';
  static const cancelled = 'cancelled';

  /// Statuses reached only after the order was paid.
  static const paidStatuses = {processing, handedToCourier, delivered};
}

/// `scope` filter of `GET me/orders/` (contract §2.8).
enum OrderScope {
  all('all'),
  active('active'),
  completed('completed'),
  cancelled('cancelled');

  const OrderScope(this.code);
  final String code;
}

/// Brand name of a payment provider literal ("click" → "Click").
String providerName(String? provider) => switch (provider) {
  'click' => 'Click',
  'payme' => 'Payme',
  null || '' => '',
  _ => provider[0].toUpperCase() + provider.substring(1),
};

/// The displayed payment of an order (`payment` in OrderSummary / OrderDetail).
class OrderPayment {
  const OrderPayment({
    required this.status,
    required this.statusLabel,
    required this.provider,
    required this.inProgress,
    this.amount,
    this.confirmedAt,
    this.inProgressLabel,
  });

  factory OrderPayment.fromJson(Json j) => OrderPayment(
    status: asString(j['status']),
    statusLabel: asString(j['status_label']),
    provider: asStringOrNull(j['provider']),
    inProgress: asBool(j['in_progress']),
    amount: asIntOrNull(j['amount']),
    confirmedAt: asDate(j['confirmed_at']),
    inProgressLabel: asStringOrNull(j['in_progress_label']),
  );

  static const none = OrderPayment(
    status: '',
    statusLabel: '',
    provider: null,
    inProgress: false,
  );

  final String status;
  final String statusLabel;
  final String? provider;
  final bool inProgress;
  final int? amount;
  final DateTime? confirmedAt;
  final String? inProgressLabel;

  bool get isPaid => status == 'paid';
  bool get isSettled => status == 'paid' || status == 'refunded';
}

/// `OrderSummary` (contract §2.8).
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.statusLabel,
    required this.fulfilment,
    required this.total,
    required this.itemCount,
    required this.previewImages,
    required this.payment,
    required this.payBy,
    required this.trackingNumber,
  });

  factory OrderSummary.fromJson(Json j) => OrderSummary(
    id: asInt(j['id']),
    createdAt: asDate(j['created_at']),
    status: asString(j['status']),
    statusLabel: asString(j['status_label']),
    fulfilment: asString(j['fulfilment']),
    total: asInt(j['total']),
    itemCount: asInt(j['item_count']),
    previewImages: [
      if (j['preview_images'] case final List<Object?> list)
        ...list.whereType<String>().where((e) => e.isNotEmpty),
    ],
    payment: j['payment'] is Map
        ? OrderPayment.fromJson(asJson(j['payment']))
        : OrderPayment.none,
    payBy: asDate(j['pay_by']),
    trackingNumber: asStringOrNull(j['tracking_number']),
  );

  final int id;
  final DateTime? createdAt;
  final String status;
  final String statusLabel;
  final String fulfilment;
  final int total;
  final int itemCount;
  final List<String> previewImages;
  final OrderPayment payment;
  final DateTime? payBy;
  final String? trackingNumber;

  bool get awaitingPayment => status == OrderStatus.awaitingPayment;

  /// Still payable on the clock: awaiting payment with `pay_by` ahead of [now].
  bool payableAt(DateTime now) =>
      awaitingPayment && payBy != null && payBy!.isAfter(now);

  /// Where a tap on the list card goes.
  String routeAt(DateTime now) => payableAt(now) ? '/pay/$id' : '/orders/$id';
}

class OrderItem {
  const OrderItem({
    required this.productId,
    required this.name,
    required this.imageUrl,
    required this.quantity,
    required this.unitPrice,
    required this.promo,
    required this.lineTotal,
  });

  factory OrderItem.fromJson(Json j) => OrderItem(
    productId: asInt(j['product_id']),
    name: asString(j['name']),
    imageUrl: asStringOrNull(j['image_url']),
    quantity: asInt(j['quantity'], 1),
    unitPrice: asInt(j['unit_price']),
    promo: asBool(j['promo']),
    lineTotal: asInt(j['line_total']),
  );

  final int productId;
  final String name;
  final String? imageUrl;
  final int quantity;
  final int unitPrice;
  final bool promo;
  final int lineTotal;
}

class OrderRefund {
  const OrderRefund({
    required this.state,
    required this.stateLabel,
    required this.amount,
    this.requestedAt,
    this.completedAt,
  });

  factory OrderRefund.fromJson(Json j) => OrderRefund(
    state: asString(j['state']),
    stateLabel: asString(j['state_label']),
    amount: asInt(j['amount']),
    requestedAt: asDate(j['requested_at']),
    completedAt: asDate(j['completed_at']),
  );

  final String state;
  final String stateLabel;
  final int amount;
  final DateTime? requestedAt;
  final DateTime? completedAt;

  bool get completed => state == 'completed';
}

class OrderShipment {
  const OrderShipment({
    required this.carrier,
    required this.trackingNumber,
    this.trackingUrl,
  });

  factory OrderShipment.fromJson(Json j) => OrderShipment(
    carrier: asString(j['carrier']),
    trackingNumber: asStringOrNull(j['tracking_number']),
    trackingUrl: asStringOrNull(j['tracking_url']),
  );

  final String carrier;
  final String? trackingNumber;
  final String? trackingUrl;

  /// "BTS · 48213907"
  String get display =>
      [carrier, ?trackingNumber].where((e) => e.isNotEmpty).join(' · ');
}

class OrderCashback {
  const OrderCashback({
    required this.used,
    required this.earned,
    required this.earnedState,
  });

  factory OrderCashback.fromJson(Json j) => OrderCashback(
    used: asInt(j['used']),
    earned: asInt(j['earned']),
    earnedState: asString(j['earned_state'], 'none'),
  );

  static const none = OrderCashback(used: 0, earned: 0, earnedState: 'none');

  final int used;
  final int earned;

  /// `none` | `credited` | `reversed`.
  final String earnedState;

  bool get showEarned => earned > 0 && earnedState != 'none';
  bool get reversed => earnedState == 'reversed';
}

class OrderCancellation {
  const OrderCancellation({required this.reason, required this.label});

  factory OrderCancellation.fromJson(Json j) => OrderCancellation(
    reason: asString(j['reason']),
    label: asString(j['label']),
  );

  /// `reservation_expired` | `admin` | `customer_request`.
  final String reason;
  final String label;

  bool get expired => reason == 'reservation_expired';
}

/// `ProgressStep` (contract §4.2).
enum ProgressState { done, current, upcoming, skipped }

class ProgressStep {
  const ProgressStep({
    required this.step,
    required this.label,
    required this.state,
    this.at,
  });

  factory ProgressStep.fromJson(Json j) => ProgressStep(
    step: asString(j['step']),
    label: asString(j['label']),
    state: switch (j['state']) {
      'done' => ProgressState.done,
      'current' => ProgressState.current,
      'skipped' => ProgressState.skipped,
      _ => ProgressState.upcoming,
    },
    at: asDate(j['at']),
  );

  final String step;
  final String label;
  final ProgressState state;
  final DateTime? at;
}

/// `TimelineEntry` (contract §4.1).
class TimelineEntry {
  const TimelineEntry({
    required this.type,
    required this.at,
    required this.title,
    this.subtitle,
  });

  factory TimelineEntry.fromJson(Json j) => TimelineEntry(
    type: asString(j['type']),
    at: asDate(j['at']),
    title: asString(j['title']),
    subtitle: asStringOrNull(j['subtitle']),
  );

  final String type;
  final DateTime? at;
  final String title;
  final String? subtitle;
}

class OrderActions {
  const OrderActions({
    required this.pay,
    required this.cancel,
    required this.reorder,
  });

  factory OrderActions.fromJson(Json j) => OrderActions(
    pay: asBool(j['pay']),
    cancel: asBool(j['cancel']),
    reorder: asBool(j['reorder']),
  );

  static const none = OrderActions(pay: false, cancel: false, reorder: false);

  final bool pay;
  final bool cancel;
  final bool reorder;
}

/// `OrderDetail` (contract §2.8).
class OrderDetail extends OrderSummary {
  const OrderDetail({
    required super.id,
    required super.createdAt,
    required super.status,
    required super.statusLabel,
    required super.fulfilment,
    required super.total,
    required super.itemCount,
    required super.previewImages,
    required super.payment,
    required super.payBy,
    required super.trackingNumber,
    required this.fulfilmentLabel,
    required this.items,
    required this.itemsSubtotal,
    required this.promoSubtotal,
    required this.deliveryFee,
    required this.cashbackUsed,
    required this.address,
    required this.addressComment,
    required this.pickupAddress,
    required this.customerNote,
    required this.refund,
    required this.shipment,
    required this.cashback,
    required this.cancellation,
    required this.progress,
    required this.timeline,
    required this.actions,
  });

  factory OrderDetail.fromJson(Json j) {
    final s = OrderSummary.fromJson(j);
    return OrderDetail(
      id: s.id,
      createdAt: s.createdAt,
      status: s.status,
      statusLabel: s.statusLabel,
      fulfilment: s.fulfilment,
      total: s.total,
      itemCount: s.itemCount,
      previewImages: s.previewImages,
      payment: s.payment,
      payBy: s.payBy,
      trackingNumber: s.trackingNumber,
      fulfilmentLabel: asString(j['fulfilment_label']),
      items: asJsonList(j['items']).map(OrderItem.fromJson).toList(),
      itemsSubtotal: asInt(j['items_subtotal']),
      promoSubtotal: asInt(j['promo_subtotal']),
      deliveryFee: asInt(j['delivery_fee']),
      cashbackUsed: asInt(j['cashback_used']),
      address: asStringOrNull(j['address']),
      addressComment: asStringOrNull(j['address_comment']),
      pickupAddress: asStringOrNull(j['pickup_address']),
      customerNote: asStringOrNull(j['customer_note']),
      refund: j['refund'] is Map
          ? OrderRefund.fromJson(asJson(j['refund']))
          : null,
      shipment: j['shipment'] is Map
          ? OrderShipment.fromJson(asJson(j['shipment']))
          : null,
      cashback: j['cashback'] is Map
          ? OrderCashback.fromJson(asJson(j['cashback']))
          : OrderCashback.none,
      cancellation: j['cancellation'] is Map
          ? OrderCancellation.fromJson(asJson(j['cancellation']))
          : null,
      progress: asJsonList(j['progress']).map(ProgressStep.fromJson).toList(),
      timeline: asJsonList(j['timeline']).map(TimelineEntry.fromJson).toList(),
      actions: j['actions'] is Map
          ? OrderActions.fromJson(asJson(j['actions']))
          : OrderActions.none,
    );
  }

  final String fulfilmentLabel;
  final List<OrderItem> items;
  final int itemsSubtotal;
  final int promoSubtotal;
  final int deliveryFee;
  final int cashbackUsed;
  final String? address;
  final String? addressComment;
  final String? pickupAddress;
  final String? customerNote;
  final OrderRefund? refund;
  final OrderShipment? shipment;
  final OrderCashback cashback;
  final OrderCancellation? cancellation;
  final List<ProgressStep> progress;
  final List<TimelineEntry> timeline;
  final OrderActions actions;

  /// The order was paid (the payment went through, whatever happened next).
  bool get isPaid =>
      payment.isPaid || OrderStatus.paidStatuses.contains(status);

  bool get isCancelled => status == OrderStatus.cancelled;

  /// The amount the customer pays (or paid) online.
  int get payable => payment.amount ?? total;
}

/// The answer of `POST orders/{id}/pay/` (contract §2.7.2).
class PayResult {
  const PayResult({
    required this.orderId,
    required this.provider,
    required this.amount,
    required this.payBy,
    required this.webUrl,
    this.appUrl,
  });

  factory PayResult.fromJson(Json j) => PayResult(
    orderId: asInt(j['order_id']),
    provider: asString(j['provider']),
    amount: asInt(j['amount']),
    payBy: asDate(j['pay_by']),
    webUrl: asString(j['web_url']),
    appUrl: asStringOrNull(j['app_url']),
  );

  final int orderId;
  final String provider;
  final int amount;
  final DateTime? payBy;
  final String webUrl;
  final String? appUrl;
}

/// Timeline types that tell the story of each progress step.
const _stepTimelineTypes = {
  'placed': {'order_created'},
  'paid': {'payment_confirmed'},
  'with_courier': {'handed_to_courier'},
  'delivered': {'delivered'},
  'picked_up': {'delivered'},
  'cancelled': {'cancelled'},
};

/// The newest timeline entry describing [step], if any ([timeline] is newest
/// first, contract §4.1).
TimelineEntry? timelineFor(ProgressStep step, List<TimelineEntry> timeline) {
  final types = _stepTimelineTypes[step.step];
  if (types == null) return null;
  for (final e in timeline) {
    if (types.contains(e.type)) return e;
  }
  return null;
}

/// Timeline entries that no progress step tells (failed payments, refunds,
/// shipment booking), newest first.
List<TimelineEntry> extraTimeline(
  List<ProgressStep> progress,
  List<TimelineEntry> timeline,
) {
  final used = <TimelineEntry>{
    for (final s in progress) ?timelineFor(s, timeline),
  };
  return timeline.where((e) => !used.contains(e)).toList();
}
