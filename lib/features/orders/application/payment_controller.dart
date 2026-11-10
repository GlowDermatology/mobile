import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../data/order_models.dart';

/// What the payment screen shows (contract §2.7.2).
enum PaymentPhase {
  /// First load in flight.
  loading,

  /// First load failed ([PaymentController.error]).
  failed,

  /// Awaiting payment and still payable: countdown (or "To‘lov tekshirilmoqda"
  /// while a transaction is in flight) and the pay button.
  payable,

  /// Awaiting payment but the reservation ran out ("To‘lov muddati tugadi").
  expired,

  /// The payment went through: the screen moves to the success page.
  paid,

  /// The order was cancelled (by the customer, the shop or the expiry job).
  cancelled,
}

/// The phase of [order] at [now]; pure, so it is easy to test.
PaymentPhase phaseOf(OrderDetail order, DateTime now) {
  if (order.isPaid) return PaymentPhase.paid;
  if (order.isCancelled) return PaymentPhase.cancelled;
  if (order.status != OrderStatus.awaitingPayment) return PaymentPhase.paid;
  // A transaction in flight may still complete within the grace period, so
  // it is never shown as expired.
  if (order.payment.inProgress) return PaymentPhase.payable;
  final payBy = order.payBy;
  if (!order.actions.pay) return PaymentPhase.expired;
  if (payBy != null && !now.isBefore(payBy)) return PaymentPhase.expired;
  return PaymentPhase.payable;
}

/// State of the payment screen: the order, a 1-second countdown to `pay_by`
/// and the status polling after the customer comes back from Click/Payme.
///
/// * [startPolling] re-reads the order every [pollInterval] for at most
///   [pollTimeout], stopping as soon as the order is no longer awaiting
///   payment (paid, cancelled) — used on `?returned=1`, on every app resume
///   and after the dev "simulate payment".
/// * When the countdown reaches zero the order is re-read once (the server
///   decides whether it is still payable).
///
/// Time comes from `package:clock`, so tests drive it with `fake_async`.
class PaymentController extends ChangeNotifier {
  PaymentController({
    required this.fetch,
    this.pollInterval = const Duration(seconds: 2),
    this.pollTimeout = const Duration(seconds: 60),
    this.tickInterval = const Duration(seconds: 1),
  }) : _now = clock.now();

  /// Reads `GET me/orders/{id}/`.
  final Future<OrderDetail> Function() fetch;
  final Duration pollInterval;
  final Duration pollTimeout;
  final Duration tickInterval;

  OrderDetail? _order;
  Object? _error;
  bool _loading = false;
  DateTime _now;
  Timer? _ticker;
  Timer? _poller;
  DateTime? _pollUntil;
  bool _fetching = false;
  bool _expiryRefetched = false;
  bool _disposed = false;

  OrderDetail? get order => _order;
  Object? get error => _error;
  bool get loading => _loading;
  bool get polling => _poller != null;
  DateTime get now => _now;

  PaymentPhase get phase {
    final o = _order;
    if (o == null) {
      return _error != null && !_loading
          ? PaymentPhase.failed
          : PaymentPhase.loading;
    }
    return phaseOf(o, _now);
  }

  /// Time left to pay; null without a `pay_by`.
  Duration? get remaining {
    final payBy = _order?.payBy;
    if (payBy == null) return null;
    final left = payBy.difference(_now);
    return left.isNegative ? Duration.zero : left;
  }

  /// "To‘lov tekshirilmoqda" replaces the countdown while this is set.
  String? get inProgressLabel {
    final p = _order?.payment;
    if (p == null ||
        !p.inProgress ||
        _order!.status != OrderStatus.awaitingPayment) {
      return null;
    }
    final label = p.inProgressLabel;
    return label == null || label.isEmpty ? '' : label;
  }

  /// First load, or a manual refresh. Errors keep the last known order.
  Future<void> load() async {
    if (_disposed) return;
    _loading = true;
    _notify();
    await _read();
    _loading = false;
    _notify();
  }

  /// Re-reads the order (after a 409, a cancel, the countdown's end).
  Future<void> refresh() => _read();

  /// Uses an order the server just answered (cancel → OrderDetail).
  void replace(OrderDetail order) {
    _error = null;
    _apply(order);
    _notify();
  }

  /// Polls every [pollInterval] for up to [pollTimeout] while the order is
  /// awaiting payment. [immediate] reads once right away as well.
  void startPolling({bool immediate = false}) {
    if (_disposed) return;
    final o = _order;
    if (o != null && o.status != OrderStatus.awaitingPayment) return;
    _pollUntil = clock.now().add(pollTimeout);
    _poller?.cancel();
    _poller = Timer.periodic(pollInterval, (_) => _pollOnce());
    if (immediate) unawaited(_read());
    _notify();
  }

  void stopPolling() {
    if (_poller == null) return;
    _poller?.cancel();
    _poller = null;
    _pollUntil = null;
    _notify();
  }

  Future<void> _pollOnce() async {
    final until = _pollUntil;
    if (until == null) return;
    await _read();
    if (_disposed) return;
    if (!clock.now().isBefore(until)) stopPolling();
  }

  Future<void> _read() async {
    if (_fetching || _disposed) return;
    _fetching = true;
    try {
      final o = await fetch();
      if (_disposed) return;
      _error = null;
      _apply(o);
    } on Object catch (e) {
      if (_disposed) return;
      _error = e;
    } finally {
      _fetching = false;
    }
    _notify();
  }

  void _apply(OrderDetail o) {
    final payByChanged = o.payBy != _order?.payBy;
    _order = o;
    _now = clock.now();
    if (payByChanged) _expiryRefetched = false;
    if (o.status != OrderStatus.awaitingPayment) {
      _poller?.cancel();
      _poller = null;
      _pollUntil = null;
    }
    _syncTicker();
  }

  void _syncTicker() {
    final o = _order;
    final needed =
        o != null && o.status == OrderStatus.awaitingPayment && o.payBy != null;
    if (!needed) {
      _ticker?.cancel();
      _ticker = null;
    } else {
      _ticker ??= Timer.periodic(tickInterval, (_) => _tick());
    }
  }

  void _tick() {
    if (_disposed) return;
    _now = clock.now();
    final left = remaining;
    if (left != null && left == Duration.zero && !_expiryRefetched) {
      _expiryRefetched = true;
      unawaited(_read());
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _poller?.cancel();
    super.dispose();
  }
}
