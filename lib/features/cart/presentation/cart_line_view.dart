import '../../../core/i18n/tr.dart';
import '../../settings/data/public_settings.dart';
import '../data/cart_models.dart';
import 'cart_text.dart';

/// What one cart line shows, derived from its server status (contract §2.5,
/// PDF page 5). Pure, so the rules are unit-tested.
class CartLineView {
  const CartLineView({
    required this.inactive,
    required this.showStepper,
    required this.canIncrease,
    required this.blockingWarning,
    required this.insufficientAvailable,
    required this.fixQuantity,
    required this.previousPrice,
    required this.showPromo,
    required this.showMaxHint,
  });

  factory CartLineView.of(CartLine line) {
    final inactive =
        line.status == CartLineStatus.outOfStock ||
        line.status == CartLineStatus.unavailable;
    final insufficient = line.status == CartLineStatus.insufficient;
    return CartLineView(
      inactive: inactive,
      showStepper: !inactive,
      canIncrease:
          line.status == CartLineStatus.ok && line.quantity < line.maxQuantity,
      blockingWarning: switch (line.status) {
        CartLineStatus.outOfStock => CartText.outOfStock,
        CartLineStatus.unavailable => CartText.unavailable,
        _ => null,
      },
      insufficientAvailable: insufficient ? line.available : null,
      fixQuantity: insufficient && line.maxQuantity > 0
          ? line.maxQuantity
          : null,
      previousPrice:
          !inactive && line.priceChanged && line.previousPrice != null
          ? line.previousPrice
          : null,
      showPromo: line.promo,
      showMaxHint: line.status == CartLineStatus.ok && line.maxReached,
    );
  }

  /// Greyed card, no stepper, a peach warning box and a small remove action.
  final bool inactive;
  final bool showStepper;

  /// "+" is enabled only for a healthy line below its limit.
  final bool canIncrease;

  /// "Tugagan — buyurtmaga kirmaydi" / "Hozir sotuvda yo‘q".
  final Tr? blockingWarning;

  /// For `insufficient`: "Faqat {available} ta qolgan — miqdorni kamaytiring".
  final int? insufficientAvailable;

  /// One-tap fix: the quantity to set (`max_quantity`).
  final int? fixQuantity;

  /// "Narx o‘zgardi (avval …)".
  final int? previousPrice;

  /// Gold "AKSIYA" badge + "Cashback hisoblanmaydi".
  final bool showPromo;

  /// "Ko‘proq kerak bo‘lsa, sotuvchi bilan bog‘laning".
  final bool showMaxHint;
}

/// Why the "To‘lash" bar is disabled, or null when the cart can be paid.
/// [settings] is null while the public settings are not loaded yet.
Tr? payBlockReason(Cart cart, PublicSettings? settings) {
  if (settings != null && !settings.onlineSalesEnabled) {
    return CartText.salesOff;
  }
  if (settings != null && settings.paymentProviders.isEmpty) {
    return CartText.noPayments;
  }
  if (cart.hasProblems) return CartText.fixProblems;
  return null;
}

/// True when the "To‘lash" button can be tapped.
bool canPay(Cart cart, PublicSettings? settings) =>
    settings != null &&
    cart.items.isNotEmpty &&
    cart.itemsSubtotal > 0 &&
    payBlockReason(cart, settings) == null;
