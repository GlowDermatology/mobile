import '../../../core/network/api_exception.dart';
import '../../../core/network/json.dart';
import '../data/checkout_api.dart';

// The checkout's delivery decisions, kept pure so they can be unit-tested
// (a port of the website's `features/shop/cart/delivery-flow.ts`): which
// option is selected and can be placed, what a refused option lets the
// customer do about it, how a re-quote compares with what the customer saw,
// and how a checkout refusal about delivery is read. Prices always come from
// the server; nothing here adds up a fee.

/// The option the page marks as chosen: the customer's pick while its
/// re-quote is on the way (so the radio follows the tap), else the server's
/// selection (its default, or the pick when it is available).
DeliveryChoice? displayedChoice(
  DeliveryQuote? quote,
  DeliveryChoice? preferred, {
  required bool pending,
}) {
  if (pending &&
      preferred != null &&
      quote != null &&
      (findOption(quote.options, preferred)?.available ?? false)) {
    return preferred;
  }
  return quote?.choice;
}

/// Whether checkout can be placed with this quote: pickup, an answer without
/// options (BTS), a BTS selection, or a Yandex selection with its quote id.
/// A delivery answer whose options are all unavailable cannot.
bool placeable(DeliveryQuote? quote) {
  if (quote == null) return false;
  if (quote.fulfilment == Fulfilment.pickup || quote.options.isEmpty) {
    return true;
  }
  if (quote.provider == DeliveryProvider.bts) return true;
  return quote.provider == DeliveryProvider.yandex && quote.quoteId != null;
}

/// What the customer can do about a refused option.
enum OptionAction { pin, edit, retry }

/// Why an option is refused (the server's reason, or `region_required` for a
/// BTS address without its region and district) and what the page offers.
typedef OptionProblem = ({String reason, OptionAction? action});

OptionProblem? optionProblem(
  DeliveryOption option, {
  required bool hasAddress,
  required bool addressHasRegion,
}) {
  if (option.available) return null;
  final reason = option.unavailableReason ?? 'not_configured';
  if (reason == 'coordinates_required') {
    return (reason: reason, action: hasAddress ? OptionAction.pin : null);
  }
  if (reason == 'out_of_zone' &&
      option.provider == DeliveryProvider.bts &&
      hasAddress &&
      !addressHasRegion) {
    return (reason: 'region_required', action: OptionAction.edit);
  }
  if (reason == 'provider_unavailable') {
    return (reason: reason, action: OptionAction.retry);
  }
  return (reason: reason, action: null);
}

/// What the customer saw when they pressed "place order".
typedef SeenTerms = ({
  DeliveryChoice? choice,
  int deliveryFee,
  int expectedTotal,
});

SeenTerms seenTerms(DeliveryQuote quote) => (
  choice: quote.choice,
  deliveryFee: quote.deliveryFee,
  expectedTotal: quote.selectedTotal,
);

extension SelectedTotal on DeliveryQuote {
  /// The total the summary shows and checkout sends: the selected option's.
  int get selectedTotal {
    final o = selectedOption;
    return o != null && o.available
        ? (o.expectedTotal ?? expectedTotal)
        : expectedTotal;
  }
}

sealed class RequoteOutcome {
  const RequoteOutcome();
}

/// Same option, fee and total: the order may go ahead with the fresh quote.
class RequoteSame extends RequoteOutcome {
  const RequoteSame();
}

/// Same option at another fee: show the new price and ask to confirm.
class RequoteFeeChanged extends RequoteOutcome {
  const RequoteFeeChanged(this.from, this.to);
  final int from;
  final int to;
}

/// Same fee, another total (items or cashback moved): ask to confirm.
class RequoteTotalChanged extends RequoteOutcome {
  const RequoteTotalChanged();
}

/// The chosen option is gone; the server selected another one.
class RequoteReplaced extends RequoteOutcome {
  const RequoteReplaced(this.label);
  final String label;
}

/// No option can take the order now.
class RequoteNone extends RequoteOutcome {
  const RequoteNone();
}

RequoteOutcome compareQuotes(SeenTerms seen, DeliveryQuote fresh) {
  if (fresh.fulfilment == Fulfilment.delivery &&
      fresh.options.isNotEmpty &&
      !placeable(fresh)) {
    return const RequoteNone();
  }
  if (!sameChoice(seen.choice, fresh.choice)) {
    return RequoteReplaced(
      findOption(fresh.options, fresh.choice)?.label ?? '',
    );
  }
  if (seen.deliveryFee != fresh.deliveryFee) {
    return RequoteFeeChanged(seen.deliveryFee, fresh.deliveryFee);
  }
  if (seen.expectedTotal != fresh.selectedTotal) {
    return const RequoteTotalChanged();
  }
  return const RequoteSame();
}

/// When a Yandex quote must be asked again: its lifetime measured on the
/// server's clock (`quote_expires_at − quoted_at`) after the moment it was
/// received, plus one second, so a wrong phone clock does not matter. Null
/// when the quote does not expire (BTS, pickup).
DateTime? requoteAt(DeliveryQuote quote, DateTime receivedAt) {
  final expires = quote.quoteExpiresAt;
  if (expires == null) return null;
  final quoted = quote.quotedAt;
  final expiry = quoted == null
      ? expires
      : receivedAt.add(expires.difference(quoted));
  return expiry.add(requoteGrace);
}

const requoteGrace = Duration(seconds: 1);

/// Whether a quote with this [requoteAt] deadline has run out at [now]
/// (checkout must ask again before placing).
bool quoteExpired(DateTime? deadline, DateTime now) =>
    deadline != null && !now.isBefore(deadline.subtract(requoteGrace));

/// A checkout refusal about delivery (contract §2.7.1).
sealed class DeliveryConflict {
  const DeliveryConflict(this.options);

  /// The fresh options the server sent with the refusal, if any.
  final List<DeliveryOption>? options;
}

/// 409 `price_changed` from a Yandex re-quote: the new fee and fresh options.
class DeliveryPriceChanged extends DeliveryConflict {
  const DeliveryPriceChanged(this.fee, super.options);
  final int? fee;
}

/// 409 `quote_expired`: re-quote silently once, then ask.
class QuoteExpired extends DeliveryConflict {
  const QuoteExpired(super.options);
}

/// 409 `delivery_unavailable`: nothing can take the order to this address now.
class DeliveryUnavailable extends DeliveryConflict {
  const DeliveryUnavailable(super.options);
}

/// Reads a delivery refusal; null for anything else (including the released
/// `price_changed` about items or cashback, which has no `options`).
DeliveryConflict? readDeliveryConflict(ApiException e) {
  final details = e.details;
  final options = details['options'] is List
      ? DeliveryOption.listFrom(details['options'])
      : null;
  switch (e.code) {
    case 'price_changed':
      return details.containsKey('options')
          ? DeliveryPriceChanged(asIntOrNull(details['delivery_fee']), options)
          : null;
    case 'quote_expired':
      return QuoteExpired(options);
    case 'delivery_unavailable':
      return DeliveryUnavailable(options);
    default:
      return null;
  }
}
