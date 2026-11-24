import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../settings/data/public_settings.dart';

/// `FulfilmentMethod` (contract §2.6).
abstract final class Fulfilment {
  static const delivery = 'delivery';
  static const pickup = 'pickup';
}

/// `DeliveryProvider` / `DeliveryMethod` (contract §2.6): who carries a
/// home delivery and, for Yandex, how fast.
abstract final class DeliveryProvider {
  static const yandex = 'yandex';
  static const bts = 'bts';
}

abstract final class DeliveryMethod {
  static const standard = 'standard';
  static const express = 'express';
}

/// A carrier choice: BTS, or Yandex with its method.
typedef DeliveryChoice = ({String provider, String? method});

bool sameChoice(DeliveryChoice? a, DeliveryChoice? b) => a == null || b == null
    ? a == b
    : a.provider == b.provider && a.method == b.method;

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// One home-delivery option of a quote (`DeliveryOption`, contract §2.6).
/// Prices come from the server; an option missing its price, total or (for
/// Yandex) quote id is shown unavailable rather than with a made-up price.
class DeliveryOption {
  const DeliveryOption({
    required this.provider,
    required this.method,
    required this.label,
    required this.available,
    this.unavailableReason,
    this.fee,
    this.etaFrom,
    this.etaTo,
    this.scheduled = false,
    this.quoteId,
    this.expiresAt,
    this.expectedTotal,
  });

  /// Null for an option the app cannot use (unknown provider, Yandex without
  /// a known method).
  static DeliveryOption? fromJson(Json j) {
    final provider = asString(j['provider']);
    var method = asStringOrNull(j['method']);
    if (provider == DeliveryProvider.bts) {
      method = null;
    } else if (provider != DeliveryProvider.yandex ||
        (method != DeliveryMethod.standard &&
            method != DeliveryMethod.express)) {
      return null;
    }
    final fee = asIntOrNull(j['fee']);
    final total = asIntOrNull(j['expected_total']);
    final rawQuote = asStringOrNull(j['quote_id'])?.toLowerCase();
    final quoteId = rawQuote != null && _uuid.hasMatch(rawQuote)
        ? rawQuote
        : null;
    final usable =
        j['available'] == true &&
        fee != null &&
        total != null &&
        (provider == DeliveryProvider.bts || quoteId != null);
    final reason = asStringOrNull(j['unavailable_reason']);
    return DeliveryOption(
      provider: provider,
      method: method,
      label: asString(j['label']),
      available: usable,
      unavailableReason: usable
          ? null
          : (reason ??
                (j['available'] == true
                    ? 'provider_unavailable'
                    : 'not_configured')),
      fee: usable ? fee : null,
      etaFrom: usable ? asDate(j['eta_from']) : null,
      etaTo: usable ? asDate(j['eta_to']) : null,
      scheduled: usable && asBool(j['scheduled']),
      quoteId: usable ? quoteId : null,
      expiresAt: usable ? asDate(j['expires_at']) : null,
      expectedTotal: usable ? total : null,
    );
  }

  /// Usable options in the server's order (Yandex Standard, Express, BTS),
  /// one per provider and method.
  static List<DeliveryOption> listFrom(Object? raw) {
    final out = <DeliveryOption>[];
    for (final j in asJsonList(raw)) {
      final o = DeliveryOption.fromJson(j);
      if (o != null && !out.any((e) => sameChoice(e.choice, o.choice))) {
        out.add(o);
      }
    }
    return out;
  }

  final String provider;
  final String? method;

  /// Server-localised ("Yandex Ekspress", "BTS pochta").
  final String label;
  final bool available;

  /// `DeliveryUnavailableReason`: coordinates_required, provider_unavailable,
  /// out_of_zone, too_heavy, warehouse_closed, dispatch_suspended,
  /// not_configured, method_disabled.
  final String? unavailableReason;
  final int? fee;
  final DateTime? etaFrom;
  final DateTime? etaTo;

  /// The window starts when the warehouse next opens.
  final bool scheduled;
  final String? quoteId;
  final DateTime? expiresAt;
  final int? expectedTotal;

  DeliveryChoice get choice => (provider: provider, method: method);
  bool get isYandex => provider == DeliveryProvider.yandex;
}

DeliveryOption? findOption(
  List<DeliveryOption> options,
  DeliveryChoice? choice,
) {
  if (choice == null) return null;
  for (final o in options) {
    if (sameChoice(o.choice, choice)) return o;
  }
  return null;
}

/// The answer of `POST delivery/calculate/` (contract §2.6). The app shows
/// these numbers as they are and never recomputes a total. A delivery quote
/// asked `with_options` also names the selected carrier and lists every
/// option; pickup and older answers have none.
class DeliveryQuote {
  const DeliveryQuote({
    required this.fulfilment,
    required this.deliveryFee,
    required this.pickupAddress,
    required this.itemsSubtotal,
    required this.cashbackMax,
    required this.cashbackToUse,
    required this.expectedTotal,
    this.addressId,
    this.provider,
    this.method,
    this.quoteId,
    this.quoteExpiresAt,
    this.quotedAt,
    this.options = const [],
  });

  factory DeliveryQuote.fromJson(Json j, {int? addressId}) {
    final fulfilment = asString(j['fulfilment']);
    final delivery = fulfilment == Fulfilment.delivery;
    final options = delivery
        ? DeliveryOption.listFrom(j['options'])
        : const <DeliveryOption>[];
    var provider = delivery ? asStringOrNull(j['provider']) : null;
    var method = provider == DeliveryProvider.yandex
        ? asStringOrNull(j['method'])
        : null;
    final rawQuote = asStringOrNull(j['quote_id'])?.toLowerCase();
    var quoteId = rawQuote != null && _uuid.hasMatch(rawQuote)
        ? rawQuote
        : null;
    if (provider != DeliveryProvider.bts &&
        provider != DeliveryProvider.yandex) {
      provider = null;
    }
    // A Yandex selection without its method and quote id cannot be placed.
    if (provider == DeliveryProvider.yandex &&
        (method == null || quoteId == null)) {
      provider = null;
      method = null;
      quoteId = null;
    }
    if (provider != DeliveryProvider.yandex) quoteId = null;
    return DeliveryQuote(
      fulfilment: fulfilment,
      deliveryFee: asInt(j['delivery_fee']),
      pickupAddress: asStringOrNull(j['pickup_address']),
      itemsSubtotal: asInt(j['items_subtotal']),
      cashbackMax: asInt(j['cashback_max']),
      cashbackToUse: asInt(j['cashback_to_use']),
      expectedTotal: asInt(j['expected_total']),
      addressId: addressId,
      provider: provider,
      method: method,
      quoteId: quoteId,
      quoteExpiresAt: quoteId == null ? null : asDate(j['quote_expires_at']),
      quotedAt: asDate(j['quoted_at']),
      options: options,
    );
  }

  final String fulfilment;
  final int deliveryFee;
  final String? pickupAddress;
  final int itemsSubtotal;
  final int cashbackMax;
  final int cashbackToUse;
  final int expectedTotal;

  /// The address the quote was asked for (delivery only); not in the JSON.
  final int? addressId;

  /// The selected carrier (null for pickup or an answer without options).
  final String? provider;
  final String? method;

  /// Yandex only: what checkout sends as `delivery_quote_id`.
  final String? quoteId;
  final DateTime? quoteExpiresAt;

  /// When the server made the quote (its clock).
  final DateTime? quotedAt;
  final List<DeliveryOption> options;

  DeliveryChoice? get choice =>
      provider == null ? null : (provider: provider!, method: method);
  DeliveryOption? get selectedOption => findOption(options, choice);
}

/// Body of `POST delivery/calculate/`. A delivery quote always asks for the
/// carrier options (`with_options`) and passes the customer's [preferred]
/// choice; the server answers it when it is available, else its default.
Map<String, Object?> buildCalculateBody({
  required String fulfilment,
  required int? addressId,
  required bool useCashback,
  required int cashbackAvailable,
  DeliveryChoice? preferred,
}) {
  final delivery = fulfilment == Fulfilment.delivery;
  return {
    'fulfilment': fulfilment,
    'address_id': delivery ? addressId : null,
    'cashback_to_use': useCashback && cashbackAvailable > 0
        ? cashbackAvailable
        : 0,
    if (delivery) 'with_options': true,
    if (delivery && preferred != null) 'delivery_provider': preferred.provider,
    if (delivery && preferred?.provider == DeliveryProvider.yandex)
      'delivery_method': preferred!.method,
  };
}

/// Body of `POST orders/checkout/` (contract §2.7.1): the cashback and the
/// total are copied unchanged from the last [quote] (the selected option's
/// total when it has options); a Yandex choice sends its `delivery_quote_id`,
/// BTS and pickup send the released body. The provider is the first one the
/// shop offers that this app knows (the final choice is made on the pay
/// screen); null when there is none.
Map<String, Object?> buildCheckoutBody({
  required DeliveryQuote quote,
  required List<String> paymentProviders,
  required String note,
}) {
  final delivery = quote.fulfilment == Fulfilment.delivery;
  final option = quote.selectedOption;
  final yandex = delivery && quote.provider == DeliveryProvider.yandex;
  return {
    'fulfilment': quote.fulfilment,
    'address_id': delivery ? quote.addressId : null,
    'payment_provider': paymentProviders
        .where(knownPaymentProviders.contains)
        .firstOrNull,
    'cashback_to_use': quote.cashbackToUse,
    'expected_total': option != null && option.available
        ? (option.expectedTotal ?? quote.expectedTotal)
        : quote.expectedTotal,
    'customer_note': note.trim(),
    if (yandex) 'delivery_quote_id': quote.quoteId,
  };
}

class CheckoutApi {
  CheckoutApi(this._api);
  final ApiClient _api;

  Future<DeliveryQuote> calculate(Map<String, Object?> body) async =>
      DeliveryQuote.fromJson(
        asJson(await _api.post('delivery/calculate/', body: body)),
        addressId: asIntOrNull(body['address_id']),
      );

  /// Places the order; answers the new order's id (201 `OrderDetail`).
  Future<int> checkout(
    Map<String, Object?> body, {
    required String idempotencyKey,
  }) async => asInt(
    asJson(
      await _api.post(
        'orders/checkout/',
        body: body,
        idempotencyKey: idempotencyKey,
      ),
    )['id'],
  );
}

final checkoutApiProvider = Provider<CheckoutApi>(
  (ref) => CheckoutApi(ref.watch(apiClientProvider)),
);

/// One line of the `OUT_OF_STOCK` details (contract §2.7.1 row 7).
class StockProblem {
  const StockProblem({
    required this.productId,
    required this.name,
    required this.requested,
    required this.available,
    required this.status,
  });

  factory StockProblem.fromJson(Json j) => StockProblem(
    productId: asInt(j['product_id']),
    name: asString(j['name']),
    requested: asInt(j['requested']),
    available: asInt(j['available']),
    status: asString(j['status']),
  );

  static List<StockProblem> listFrom(Json details) =>
      asJsonList(details['lines']).map(StockProblem.fromJson).toList();

  final int productId;
  final String name;
  final int requested;
  final int available;
  final String status;
}
