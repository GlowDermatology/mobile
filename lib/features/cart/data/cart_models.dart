import '../../../core/network/json.dart';

/// `CartLineStatus` (contract §2.5).
enum CartLineStatus { ok, insufficient, outOfStock, unavailable }

CartLineStatus _status(Object? v) => switch (v) {
  'insufficient' => CartLineStatus.insufficient,
  'out_of_stock' => CartLineStatus.outOfStock,
  'unavailable' => CartLineStatus.unavailable,
  _ => CartLineStatus.ok,
};

class CartLine {
  const CartLine({
    required this.productId,
    required this.name,
    required this.volume,
    required this.imageUrl,
    required this.unitPrice,
    required this.promo,
    required this.quantity,
    required this.lineTotal,
    required this.available,
    required this.maxQuantity,
    required this.maxReached,
    required this.status,
    required this.priceChanged,
    required this.previousPrice,
  });

  factory CartLine.fromJson(Json j) => CartLine(
    productId: asInt(j['product_id']),
    name: asString(j['name']),
    volume: asString(j['volume']),
    imageUrl: asStringOrNull(j['main_image_url']),
    unitPrice: asInt(j['unit_price']),
    promo: asBool(j['promo']),
    quantity: asInt(j['quantity'], 1),
    lineTotal: asInt(j['line_total']),
    available: asInt(j['available']),
    maxQuantity: asInt(j['max_quantity']),
    maxReached: asBool(j['max_reached']),
    status: _status(j['status']),
    priceChanged: asBool(j['price_changed']),
    previousPrice: asIntOrNull(j['previous_price']),
  );

  final int productId;
  final String name;
  final String volume;
  final String? imageUrl;
  final int unitPrice;
  final bool promo;
  final int quantity;
  final int lineTotal;
  final int available;
  final int maxQuantity;
  final bool maxReached;
  final CartLineStatus status;
  final bool priceChanged;
  final int? previousPrice;

  CartLine withQuantity(int q) => CartLine(
    productId: productId,
    name: name,
    volume: volume,
    imageUrl: imageUrl,
    unitPrice: unitPrice,
    promo: promo,
    quantity: q,
    lineTotal: unitPrice * q,
    available: available,
    maxQuantity: maxQuantity,
    maxReached: q >= maxQuantity && maxQuantity > 0,
    status: status,
    priceChanged: priceChanged,
    previousPrice: previousPrice,
  );
}

class Cart {
  const Cart({
    required this.items,
    required this.itemCount,
    required this.quantityTotal,
    required this.itemsSubtotal,
    required this.promoSubtotal,
    required this.hasProblems,
    required this.cashbackAvailable,
    required this.maxUsablePickup,
    this.lastChangeMaxReached = false,
  });

  factory Cart.fromJson(Json j) {
    final cashback = asJson(j['cashback']);
    final change = asJson(j['last_change']);
    return Cart(
      items: asJsonList(j['items']).map(CartLine.fromJson).toList(),
      itemCount: asInt(j['item_count']),
      quantityTotal: asInt(j['quantity_total']),
      itemsSubtotal: asInt(j['items_subtotal']),
      promoSubtotal: asInt(j['promo_subtotal']),
      hasProblems: asBool(j['has_problems']),
      cashbackAvailable: asInt(cashback['available']),
      maxUsablePickup: asInt(cashback['max_usable_pickup']),
      lastChangeMaxReached: asBool(change['max_reached']),
    );
  }

  static const empty = Cart(
    items: [],
    itemCount: 0,
    quantityTotal: 0,
    itemsSubtotal: 0,
    promoSubtotal: 0,
    hasProblems: false,
    cashbackAvailable: 0,
    maxUsablePickup: 0,
  );

  final List<CartLine> items;

  /// Number of distinct lines: the tab badge.
  final int itemCount;
  final int quantityTotal;

  /// Over lines with status `ok` only.
  final int itemsSubtotal;
  final int promoSubtotal;
  final bool hasProblems;
  final int cashbackAvailable;
  final int maxUsablePickup;

  /// The last write was clamped to the stock / per-line limit.
  final bool lastChangeMaxReached;

  int quantityOf(int productId) {
    for (final l in items) {
      if (l.productId == productId) return l.quantity;
    }
    return 0;
  }

  /// Local preview while a quantity change is in flight.
  Cart withLineQuantity(int productId, int quantity) {
    final lines = [
      for (final l in items)
        if (l.productId != productId)
          l
        else if (quantity > 0)
          l.withQuantity(quantity),
    ];
    final okLines = lines.where((l) => l.status == CartLineStatus.ok);
    return Cart(
      items: lines,
      itemCount: lines.length,
      quantityTotal: lines.fold(0, (s, l) => s + l.quantity),
      itemsSubtotal: okLines.fold(0, (s, l) => s + l.lineTotal),
      promoSubtotal: okLines
          .where((l) => l.promo)
          .fold(0, (s, l) => s + l.lineTotal),
      hasProblems: hasProblems,
      cashbackAvailable: cashbackAvailable,
      maxUsablePickup: maxUsablePickup,
    );
  }
}
