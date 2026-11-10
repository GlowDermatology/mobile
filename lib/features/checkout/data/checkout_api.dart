import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';

/// `FulfilmentMethod` (contract §2.6).
abstract final class Fulfilment {
  static const delivery = 'delivery';
  static const pickup = 'pickup';
}

/// The answer of `POST delivery/calculate/` (contract §2.6). The app shows
/// these numbers as they are and never recomputes a total.
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
  });

  factory DeliveryQuote.fromJson(Json j, {int? addressId}) => DeliveryQuote(
    fulfilment: asString(j['fulfilment']),
    deliveryFee: asInt(j['delivery_fee']),
    pickupAddress: asStringOrNull(j['pickup_address']),
    itemsSubtotal: asInt(j['items_subtotal']),
    cashbackMax: asInt(j['cashback_max']),
    cashbackToUse: asInt(j['cashback_to_use']),
    expectedTotal: asInt(j['expected_total']),
    addressId: addressId,
  );

  final String fulfilment;
  final int deliveryFee;
  final String? pickupAddress;
  final int itemsSubtotal;
  final int cashbackMax;
  final int cashbackToUse;
  final int expectedTotal;

  /// The address the quote was asked for (delivery only); not in the JSON.
  final int? addressId;
}

/// Body of `POST delivery/calculate/`.
Map<String, Object?> buildCalculateBody({
  required String fulfilment,
  required int? addressId,
  required bool useCashback,
  required int cashbackAvailable,
}) => {
  'fulfilment': fulfilment,
  'address_id': fulfilment == Fulfilment.delivery ? addressId : null,
  'cashback_to_use': useCashback && cashbackAvailable > 0
      ? cashbackAvailable
      : 0,
};

/// Body of `POST orders/checkout/` (contract §2.7.1): the cashback and the
/// total are copied unchanged from the last [quote]; the provider is the
/// first one the shop offers (the final choice is made on the pay screen).
Map<String, Object?> buildCheckoutBody({
  required DeliveryQuote quote,
  required List<String> paymentProviders,
  required String note,
}) {
  final delivery = quote.fulfilment == Fulfilment.delivery;
  return {
    'fulfilment': quote.fulfilment,
    'address_id': delivery ? quote.addressId : null,
    'payment_provider': paymentProviders.isEmpty
        ? null
        : paymentProviders.first,
    'cashback_to_use': quote.cashbackToUse,
    'expected_total': quote.expectedTotal,
    'customer_note': note.trim(),
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
