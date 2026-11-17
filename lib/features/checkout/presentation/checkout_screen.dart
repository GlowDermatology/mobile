import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/format/money.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/json.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../auth/presentation/consent_screen.dart';
import '../../cart/application/cart_controller.dart';
import '../../cart/data/cart_models.dart';
import '../../profile/data/addresses_api.dart';
import '../../profile/presentation/address_pin_note.dart';
import '../../settings/data/public_settings.dart';
import '../application/delivery_flow.dart';
import '../data/checkout_api.dart';
import 'checkout_text.dart';
import 'checkout_widgets.dart';
import 'delivery_options.dart';

/// Checkout (contract §2.6–§2.7.1). Every change asks `delivery/calculate/`
/// again (debounced: the server throttles quotes); the screen shows the
/// server's numbers and sends the selected option's `expected_total` back
/// unchanged. A home delivery lists the carrier options (Yandex Standard /
/// Express, BTS); a Yandex quote runs out, so it is asked again when it does,
/// and any change of price waits for the customer to confirm it.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  static const _intent = 'checkout';
  static const _debounceDelay = Duration(milliseconds: 300);

  final _note = TextEditingController();
  late final AppLifecycleListener _lifecycle;

  String? _fulfilment;
  int? _addressId;
  bool _addressPicked = false;
  bool _useCashback = false;

  DeliveryQuote? _quote;
  Object? _quoteError;
  bool _calculating = false;
  int _seq = 0;
  Timer? _debounce;
  Completer<void>? _debounced;

  /// The customer's carrier pick (null = the server's default).
  DeliveryChoice? _preferred;

  /// A re-quote for a newly picked option is on its way.
  bool _switching = false;

  /// The options a `delivery_unavailable` answer listed (all refused).
  List<DeliveryOption>? _refusedOptions;

  /// The inputs of the last quote, to tell a silent re-quote from a change.
  Map<String, Object?>? _quoteBody;

  /// When the last quote arrived (the ETA labels and the expiry use it).
  DateTime? _receivedAt;
  DateTime? _deadline;
  Timer? _requoteTimer;

  /// A changed price or option the customer has to confirm.
  String? _notice;
  bool _confirmPrice = false;

  bool _placing = false;
  bool _left = false;

  /// `delivery_unavailable`: the server's message ('' = the generic text).
  String? _deliveryError;
  String? _addressError;
  String? _noteError;
  String? _cashbackError;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _debounce?.cancel();
    _requoteTimer?.cancel();
    _note.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- state

  List<String> _methods(PublicSettings s) {
    final m = s.offeredFulfilments;
    return m.isEmpty ? const [Fulfilment.pickup] : m;
  }

  /// Picks the defaults once the settings / addresses are known; called from
  /// build, so it only assigns fields and schedules the first calculation.
  void _ensureDefaults(
    PublicSettings? settings,
    AsyncValue<List<Address>> addressesAsync,
  ) {
    final addresses = addressesAsync.value;
    var changed = false;
    if (!_addressPicked && addresses != null) {
      _addressPicked = true;
      final usable = addresses.where((a) => a.hasRegion).toList();
      final preferred =
          usable.where((a) => a.isDefault).firstOrNull ?? usable.firstOrNull;
      _addressId = preferred?.id;
      changed = true;
    }
    // The method is chosen once the addresses are known: delivery only when a
    // usable address exists, else pickup (when the shop offers it).
    if (_fulfilment == null &&
        settings != null &&
        (addresses != null || addressesAsync.hasError)) {
      final methods = _methods(settings);
      _fulfilment =
          methods.contains(Fulfilment.delivery) &&
              _addressId == null &&
              methods.contains(Fulfilment.pickup)
          ? Fulfilment.pickup
          : methods.first;
      changed = true;
    }
    if (changed) Future.microtask(_recalc);
  }

  Cart? get _cart => ref.read(cartProvider).value;

  /// Asks for a new quote after a short pause, so a burst of changes makes
  /// one request; completes when that request has landed.
  Future<void> _recalc() {
    if (!mounted || _left) return Future.value();
    _debounce?.cancel();
    final done = _debounced ??= Completer<void>();
    // Anything still on its way is now stale.
    _seq++;
    if (!_calculating) setState(() => _calculating = true);
    _debounce = Timer(_debounceDelay, () => unawaited(_quoteNow()));
    return done.future;
  }

  /// Asks `delivery/calculate/` at once; only the newest request lands.
  /// [choice] overrides the preference (a re-quote of the option the order
  /// was placed with). A [silent] re-quote of unchanged inputs (the quote ran
  /// out) tells the customer when the terms moved. Answers the fresh quote,
  /// or null when it was refused or superseded.
  Future<DeliveryQuote?> _quoteNow({
    bool silent = false,
    DeliveryChoice? choice,
  }) async {
    _debounce?.cancel();
    final waiting = _debounced;
    _debounced = null;
    try {
      return await _request(silent: silent, choice: choice);
    } finally {
      waiting?.complete();
    }
  }

  Future<DeliveryQuote?> _request({
    required bool silent,
    DeliveryChoice? choice,
  }) async {
    if (!mounted || _left) return null;
    final fulfilment = _fulfilment;
    final cart = _cart;
    if (fulfilment == null || cart == null) {
      setState(() => _calculating = false);
      return null;
    }
    if (fulfilment == Fulfilment.delivery && _addressId == null) {
      // Wait for the address list before asking (it picks the default).
      _requoteTimer?.cancel();
      setState(() {
        _seq++;
        _quote = null;
        _quoteError = null;
        _refusedOptions = null;
        _calculating = false;
        _switching = false;
        _deadline = null;
      });
      return null;
    }
    final body = buildCalculateBody(
      fulfilment: fulfilment,
      addressId: _addressId,
      useCashback: _useCashback,
      cashbackAvailable: cart.cashbackAvailable,
      preferred: choice ?? _preferred,
    );
    final seq = ++_seq;
    setState(() {
      _calculating = true;
      _quoteError = null;
      _deliveryError = null;
      _addressError = null;
      _cashbackError = null;
    });
    try {
      final quote = await ref.read(checkoutApiProvider).calculate(body);
      if (!mounted || seq != _seq) return null;
      final previous = _quote;
      final sameInputs = mapEquals(_quoteBody, body);
      final receivedAt = DateTime.now();
      setState(() {
        _quote = quote;
        _quoteBody = body;
        _refusedOptions = null;
        _calculating = false;
        _switching = false;
        _receivedAt = receivedAt;
        if (silent && sameInputs && previous != null) {
          final outcome = compareQuotes(seenTerms(previous), quote);
          final text = requoteNotice(outcome, context.language);
          if (text != null) {
            _notice = text;
            _confirmPrice = outcome is! RequoteNone;
          }
        }
      });
      _scheduleRequote(quote, receivedAt);
      return quote;
    } on Object catch (e) {
      if (!mounted || seq != _seq) return null;
      _requoteTimer?.cancel();
      setState(() {
        _quote = null;
        _quoteBody = null;
        _deadline = null;
        _refusedOptions = null;
        _calculating = false;
        _switching = false;
      });
      if (e is ApiException) {
        if (e.code == 'cart_empty') {
          _backToCart(e.message);
          return null;
        }
        final conflict = readDeliveryConflict(e);
        if (conflict is DeliveryUnavailable) {
          setState(() {
            _refusedOptions = conflict.options ?? const [];
            _deliveryError = e.message;
          });
          return null;
        }
        final addressError =
            e.fieldErrors['address_id'] ??
            e.fieldErrors['region_code'] ??
            e.fieldErrors['city_code'];
        if (addressError != null) {
          setState(() => _addressError = addressError);
          return null;
        }
      }
      setState(() => _quoteError = e);
      return null;
    }
  }

  /// A Yandex quote lives a few minutes: ask again as soon as it runs out.
  void _scheduleRequote(DeliveryQuote quote, DateTime receivedAt) {
    _requoteTimer?.cancel();
    final deadline = quote.fulfilment == Fulfilment.delivery
        ? requoteAt(quote, receivedAt)
        : null;
    _deadline = deadline;
    if (deadline == null) return;
    final wait = deadline.difference(DateTime.now());
    _requoteTimer = Timer(wait.isNegative ? Duration.zero : wait, _requote);
  }

  void _requote() {
    if (!mounted || _left || _placing) return;
    unawaited(_quoteNow(silent: true));
  }

  /// Back from the background after the quote ran out: ask again at once.
  void _onResume() {
    if (_quote != null && quoteExpired(_deadline, DateTime.now())) _requote();
  }

  void _resetPrompt() {
    _notice = null;
    _confirmPrice = false;
  }

  void _setFulfilment(String value) {
    if (value == _fulfilment) return;
    setState(() {
      _fulfilment = value;
      _resetPrompt();
    });
    unawaited(_recalc());
  }

  void _setAddress(int id) {
    if (id == _addressId) return;
    setState(() {
      _addressId = id;
      _resetPrompt();
    });
    unawaited(_recalc());
  }

  void _setCashback(bool value) {
    setState(() {
      _useCashback = value;
      _resetPrompt();
    });
    unawaited(_recalc());
  }

  void _choose(DeliveryChoice choice) {
    final shown = displayedChoice(_quote, _preferred, pending: _switching);
    if (sameChoice(choice, shown)) return;
    setState(() {
      _preferred = choice;
      _switching = true;
      _resetPrompt();
    });
    unawaited(_recalc());
  }

  Future<void> _addAddress() async {
    final created = await context.push<Address>('/checkout/address');
    if (!mounted || created == null) return;
    ref.invalidate(addressesProvider);
    setState(() {
      _addressPicked = true;
      if (created.hasRegion) _addressId = created.id;
      _resetPrompt();
    });
    await _recalc();
  }

  /// Opens the selected address in the form (to pin it on the map or to add
  /// its region); the form pops the updated address.
  Future<void> _fixAddress() async {
    final id = _addressId;
    if (id == null) return;
    final updated = await context.push<Address>('/checkout/address?id=$id');
    if (!mounted) return;
    ref.invalidate(addressesProvider);
    setState(() {
      if (updated != null && updated.hasRegion) _addressId = updated.id;
      _resetPrompt();
    });
    await _recalc();
  }

  void _retryQuote() {
    setState(_resetPrompt);
    unawaited(_recalc());
  }

  void _backToCart([String? message]) {
    if (_left) return;
    _left = true;
    if (message != null && message.isNotEmpty) showSnack(context, message);
    unawaited(ref.read(cartProvider.notifier).reload());
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/cart');
    }
  }

  /// An unpaid order blocks a new checkout; the cart shows it and its actions.
  void _goToCart([String? message]) {
    if (_left) return;
    _left = true;
    if (message != null && message.isNotEmpty) showSnack(context, message);
    unawaited(ref.read(cartProvider.notifier).reload());
    context.go('/cart');
  }

  // ---------------------------------------------------------------- place

  Future<void> _place({bool retried = false, bool requoted = false}) async {
    final quote = _quote;
    final settings = ref.read(publicSettingsProvider).value;
    if (quote == null || settings == null || _calculating || _placing) return;
    if (!placeable(quote)) return;
    if (_note.text.trim().length > 300) return;
    if (_confirmPrice) {
      // The customer has seen the new terms: the next tap places.
      setState(_resetPrompt);
      return;
    }
    var current = quote;
    if (quote.fulfilment == Fulfilment.delivery &&
        quoteExpired(_deadline, DateTime.now())) {
      // The quote ran out while the screen sat open: ask again first.
      final fresh = await _quoteNow(choice: quote.choice ?? _preferred);
      if (!mounted || fresh == null) return;
      final outcome = compareQuotes(seenTerms(quote), fresh);
      if (outcome is! RequoteSame) return _showOutcome(outcome);
      current = fresh;
    }
    final keys = ref.read(idempotencyProvider);
    final body = buildCheckoutBody(
      quote: current,
      paymentProviders: settings.paymentProviders,
      note: _note.text,
    );
    setState(() {
      _placing = true;
      _notice = null;
      _noteError = null;
      _cashbackError = null;
    });
    try {
      final orderId = await ref
          .read(checkoutApiProvider)
          .checkout(body, idempotencyKey: keys.keyFor(_intent));
      keys.done(_intent);
      if (!mounted) return;
      _left = true;
      _requoteTimer?.cancel();
      final cart = ref.read(cartProvider.notifier);
      context.pushReplacement('/pay/$orderId');
      unawaited(cart.reload());
    } on ApiException catch (e) {
      if (!e.isNetwork) keys.done(_intent);
      if (!mounted) return;
      setState(() => _placing = false);
      await _handlePlaceError(
        e,
        placed: current,
        retried: retried,
        requoted: requoted,
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      showError(context, e);
    }
  }

  void _showOutcome(RequoteOutcome outcome) {
    setState(() {
      _notice =
          requoteNotice(outcome, context.language) ??
          CheckoutText.quoteExpired.of(context);
      _confirmPrice = outcome is! RequoteNone;
    });
  }

  Future<void> _handlePlaceError(
    ApiException e, {
    required DeliveryQuote placed,
    required bool retried,
    required bool requoted,
  }) async {
    final conflict = readDeliveryConflict(e);
    if (conflict != null) {
      return _handleDeliveryConflict(e, conflict, placed, requoted: requoted);
    }
    switch (e.code) {
      case 'terms_update_required':
        if (!retried && await askConsent(context) && mounted) {
          return _place(retried: true, requoted: requoted);
        }
        return;
      case 'phone_required':
        if (!retried &&
            await context.push<bool>('/settings/phone') == true &&
            mounted) {
          return _place(retried: true, requoted: requoted);
        }
        return;
      case 'price_changed':
        // The items or the cashback moved: a fresh cart, a fresh quote.
        final cartJson = e.details['cart'];
        if (cartJson is Map) {
          ref
              .read(cartProvider.notifier)
              .replace(Cart.fromJson(asJson(cartJson)));
        } else {
          await ref.read(cartProvider.notifier).reload();
        }
        if (!mounted) return;
        showSnack(context, e.displayMessage);
        setState(() {
          _notice = CheckoutText.priceChanged.of(context);
          _confirmPrice = true;
        });
        return _recalc();
      case 'OUT_OF_STOCK':
        unawaited(ref.read(cartProvider.notifier).reload());
        return _showStockProblems(e);
      case 'open_order_exists':
        return _goToCart(e.displayMessage);
      case 'cart_empty':
        return _backToCart(e.displayMessage);
    }
    final address =
        e.fieldErrors['address_id'] ??
        e.fieldErrors['region_code'] ??
        e.fieldErrors['city_code'];
    final note = e.fieldErrors['customer_note'];
    final cashback = e.fieldErrors['cashback_to_use'];
    if (address != null || note != null || cashback != null) {
      setState(() {
        _addressError = address;
        _noteError = note;
        _cashbackError = cashback;
      });
      if (cashback != null) {
        await ref.read(cartProvider.notifier).reload();
        await _recalc();
        if (mounted) setState(() => _cashbackError = cashback);
      }
      return;
    }
    showError(context, e);
  }

  /// A delivery refusal: the options are asked for again. An expired quote
  /// is re-quoted silently once and, when nothing changed, placed again at
  /// once; anything else waits for the customer to confirm the new terms.
  Future<void> _handleDeliveryConflict(
    ApiException e,
    DeliveryConflict conflict,
    DeliveryQuote placed, {
    required bool requoted,
  }) async {
    final choice = placed.choice ?? _preferred;
    switch (conflict) {
      case DeliveryPriceChanged(:final fee, :final options):
        final lang = context.language;
        setState(() {
          _notice = fee != null
              ? deliveryPriceChangedText(placed.deliveryFee, fee, lang)
              : CheckoutText.quoteExpired.of(context);
          _confirmPrice = true;
          if (options != null) _quote = _withOptions(placed, options);
        });
        await _quoteNow(choice: choice);
      case QuoteExpired():
        final fresh = await _quoteNow(choice: choice);
        if (!mounted || fresh == null) return;
        final outcome = compareQuotes(seenTerms(placed), fresh);
        if (outcome is RequoteSame && !requoted) {
          return _place(requoted: true);
        }
        _showOutcome(outcome);
      case DeliveryUnavailable():
        setState(() {
          _notice = e.message.isNotEmpty
              ? e.message
              : DeliveryText.none.of(context);
          _confirmPrice = false;
        });
        await _quoteNow(choice: choice);
    }
  }

  static DeliveryQuote _withOptions(
    DeliveryQuote q,
    List<DeliveryOption> options,
  ) => DeliveryQuote(
    fulfilment: q.fulfilment,
    deliveryFee: q.deliveryFee,
    pickupAddress: q.pickupAddress,
    itemsSubtotal: q.itemsSubtotal,
    cashbackMax: q.cashbackMax,
    cashbackToUse: q.cashbackToUse,
    expectedTotal: q.expectedTotal,
    addressId: q.addressId,
    provider: q.provider,
    method: q.method,
    quoteId: q.quoteId,
    quoteExpiresAt: q.quoteExpiresAt,
    quotedAt: q.quotedAt,
    options: options,
  );

  Future<void> _showStockProblems(ApiException e) async {
    final lines = StockProblem.listFrom(e.details);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final t = context.gdText;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              GdSpace.page,
              0,
              GdSpace.page,
              16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  e.message.isNotEmpty
                      ? e.message
                      : CheckoutText.outOfStockTitle.of(context),
                  style: t.heading,
                ),
                const SizedBox(height: 12),
                for (final l in lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 20,
                          color: context.gd.warning,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.name, style: t.label),
                              Text(
                                CheckoutText.outOfStockLine.fmt(context, {
                                  'requested': l.requested,
                                  'available': l.available,
                                }),
                                style: t.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                GdButton(
                  label: CheckoutText.backToCart.of(context),
                  semanticsId: 'checkout.backToCart',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (mounted) _backToCart();
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(publicSettingsProvider);
    final cartAsync = ref.watch(cartProvider);
    final addressesAsync = ref.watch(addressesProvider);
    final settings = settingsAsync.value;
    final cart = cartAsync.value;

    ref.listen(cartProvider, (prev, next) {
      final a = prev?.value;
      final b = next.value;
      if (b == null || _left) return;
      if (b.hasUnpaidOrder && !_placing) return _goToCart();
      if (a == null ||
          a.itemsSubtotal != b.itemsSubtotal ||
          a.quantityTotal != b.quantityTotal ||
          a.itemCount != b.itemCount ||
          a.cashbackAvailable != b.cashbackAvailable) {
        unawaited(_recalc());
      }
    });

    // An order already waits for payment: the cart shows it (as the website
    // redirects).
    if (cart != null && cart.hasUnpaidOrder && !_left && !_placing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goToCart();
      });
    }

    if (cart != null) _ensureDefaults(settings, addressesAsync);

    final Widget body;
    if (settings == null || cart == null) {
      final error = settingsAsync.error ?? cartAsync.error;
      body = error != null
          ? GdErrorView(
              error: error,
              onRetry: () {
                ref.invalidate(publicSettingsProvider);
                ref.invalidate(cartProvider);
              },
            )
          : const GdLoading();
    } else if (cart.items.isEmpty && !_placing) {
      body = GdEmptyView(
        icon: Icons.shopping_bag_outlined,
        title: CheckoutText.emptyCart.of(context),
        action: SizedBox(
          width: 220,
          child: GdButton(
            label: CheckoutText.backToCart.of(context),
            onPressed: () => context.go('/cart'),
          ),
        ),
      );
    } else {
      body = _content(context, settings, cart, addressesAsync);
    }

    final quote = _quote;
    final ready =
        quote != null &&
        !_calculating &&
        placeable(quote) &&
        settings != null &&
        settings.onlineSalesEnabled &&
        settings.paymentProviders.isNotEmpty;
    final String label;
    if (_confirmPrice) {
      label = CheckoutText.confirmNewPrice.of(context);
    } else if (quote == null || _switchingShown) {
      label = CheckoutText.placeOrder.of(context);
    } else {
      label =
          '${CheckoutText.placeOrder.of(context)} · ${formatMoney(quote.selectedTotal, language: context.language)}';
    }
    return Scaffold(
      appBar: GdHeader(title: CheckoutText.title.of(context)),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: body,
      ),
      bottomNavigationBar:
          settings == null || cart == null || cart.items.isEmpty
          ? null
          : GdBottomBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_notice != null) ...[
                    _NoticeBox(text: _notice!),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: GdButton(
                      label: label,
                      semanticsId: 'checkout.place',
                      loading: _placing,
                      onPressed: ready ? _place : null,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// The option on screen is not the quoted one yet (its re-quote is on the
  /// way): its fee and total are not known.
  bool get _switchingShown =>
      _switching &&
      !sameChoice(
        displayedChoice(_quote, _preferred, pending: _switching),
        _quote?.choice,
      );

  Widget _content(
    BuildContext context,
    PublicSettings settings,
    Cart cart,
    AsyncValue<List<Address>> addresses,
  ) {
    final c = context.gd;
    final t = context.gdText;
    final methods = _methods(settings);
    final delivery = _fulfilment == Fulfilment.delivery;
    final quote = _quote;
    final options = !delivery || _addressId == null
        ? const <DeliveryOption>[]
        : quote != null
        ? (quote.fulfilment == Fulfilment.delivery
              ? quote.options
              : const <DeliveryOption>[])
        : (_refusedOptions ?? const <DeliveryOption>[]);
    final deliveryError = _deliveryError == null || _notice != null
        ? null
        : (_deliveryError!.isNotEmpty
              ? _deliveryError!
              : DeliveryText.none.of(context));
    final address = addresses.value
        ?.where((a) => a.id == _addressId)
        .firstOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(GdSpace.page, 4, GdSpace.page, 28),
      children: [
        _ItemsStrip(cart: cart),

        // Olish usuli
        CheckoutSection(
          title: CheckoutText.fulfilmentTitle.of(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (methods.contains(Fulfilment.delivery)) ...[
                GdOptionCard(
                  selected: delivery,
                  icon: Icons.local_shipping_outlined,
                  title: CheckoutText.delivery.of(context),
                  subtitle: CheckoutText.deliveryHint.of(context),
                  semanticsId: 'checkout.delivery',
                  onTap: () => _setFulfilment(Fulfilment.delivery),
                ),
                const SizedBox(height: 10),
              ],
              if (methods.contains(Fulfilment.pickup))
                GdOptionCard(
                  selected: _fulfilment == Fulfilment.pickup,
                  icon: Icons.storefront_outlined,
                  title: CheckoutText.pickup.of(context),
                  subtitle: settings.pickupAddress,
                  trailing: Text(
                    CheckoutText.free.of(context),
                    style: t.caption.copyWith(
                      color: c.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  semanticsId: 'checkout.pickup',
                  onTap: () => _setFulfilment(Fulfilment.pickup),
                ),
              if (deliveryError != null && options.isEmpty)
                InlineError(deliveryError),
            ],
          ),
        ),

        // Manzil
        if (delivery)
          CheckoutSection(
            title: CheckoutText.addressTitle.of(context),
            child: _addressPicker(context, addresses),
          ),

        // Yetkazib berish usuli
        if (delivery && options.isNotEmpty)
          CheckoutSection(
            title: DeliveryText.title.of(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DeliveryOptionsList(
                  options: options,
                  chosen: displayedChoice(
                    quote,
                    _preferred,
                    pending: _switching,
                  ),
                  address: address,
                  pending: _calculating,
                  now: _receivedAt,
                  onChoose: _choose,
                  onFixAddress: _fixAddress,
                  onRetry: _retryQuote,
                ),
                if (deliveryError != null) InlineError(deliveryError),
              ],
            ),
          ),

        // Cashback
        _cashbackCard(context, cart),

        // Izoh
        Padding(
          padding: const EdgeInsets.only(top: 22),
          child: Semantics(
            identifier: 'checkout.note',
            textField: true,
            child: TextField(
              controller: _note,
              maxLength: 300,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_noteError != null) setState(() => _noteError = null);
              },
              decoration: InputDecoration(
                labelText: CheckoutText.noteLabel.of(context),
                hintText: CheckoutText.notePlaceholder.of(context),
                errorText: _noteError,
                alignLabelWithHint: true,
              ),
            ),
          ),
        ),

        // Summary
        const SizedBox(height: 14),
        _summaryCard(context),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.schedule_rounded, size: 16, color: c.inkMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                CheckoutText.reservation.fmt(context, {
                  'minutes': settings.reservationMinutes,
                }),
                style: t.caption,
              ),
            ),
          ],
        ),
        if (settings.paymentProviders.isEmpty)
          InlineError(_noPayments.of(context)),
        if (!settings.onlineSalesEnabled) InlineError(_salesOff.of(context)),
      ],
    );
  }

  static const _noPayments = Tr(
    'Onlayn to‘lov hozircha mavjud emas.',
    'Онлайн-оплата пока недоступна.',
    'Online payment is not available yet.',
  );
  static const _salesOff = Tr(
    'Onlayn buyurtma vaqtincha mavjud emas. Mahsulotlarni do‘konimizdan xarid qilishingiz mumkin.',
    'Онлайн-заказ временно недоступен. Товары можно купить в нашем магазине.',
    'Online ordering is temporarily unavailable. You can buy these products in our store.',
  );

  Widget _addressPicker(
    BuildContext context,
    AsyncValue<List<Address>> addresses,
  ) {
    final c = context.gd;
    final t = context.gdText;
    final list = addresses.value;
    final children = <Widget>[];
    if (list == null) {
      children.add(
        addresses.hasError
            ? GdErrorView(
                error: addresses.error!,
                onRetry: () => ref.invalidate(addressesProvider),
              )
            : const GdLoading(),
      );
    } else if (list.isEmpty) {
      children.add(Text(CheckoutText.noAddress.of(context), style: t.bodySm));
    } else {
      for (final a in list) {
        final usable = a.hasRegion;
        final title = a.label.isNotEmpty
            ? a.label
            : CheckoutText.addressFallback.of(context);
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GdOptionCard(
              selected: usable && _addressId == a.id,
              dimmed: !usable,
              icon: Icons.location_on_outlined,
              title: title,
              subtitle: [
                a.text,
                if (a.comment.isNotEmpty) a.comment,
              ].join('\n'),
              trailing: a.isDefault
                  ? GdStatusChip(
                      label: CheckoutText.defaultAddress.of(context),
                      tone: GdTone.gold,
                      dot: false,
                    )
                  : null,
              semanticsId: 'checkout.address.${a.id}',
              onTap: usable
                  ? () => _setAddress(a.id)
                  : () => context.push('/settings/addresses'),
              footer: Padding(
                padding: const EdgeInsets.only(top: 8, left: 58),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AddressPinNote(address: a),
                    if (!usable)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_location_alt_outlined,
                              size: 18,
                              color: c.warning,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                CheckoutText.addressNoRegion.of(context),
                                style: t.caption.copyWith(color: c.warning),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      if (_addressId == null && list.any((a) => a.hasRegion)) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              CheckoutText.chooseAddress.of(context),
              style: t.bodySm,
            ),
          ),
        );
      }
    }
    children.add(
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: GdOutlineButton(
          label: CheckoutText.addAddress.of(context),
          icon: Icons.add_rounded,
          semanticsId: 'checkout.addAddress',
          onPressed: _addAddress,
        ),
      ),
    );
    if (_addressError != null) children.add(InlineError(_addressError!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _cashbackCard(BuildContext context, Cart cart) {
    final c = context.gd;
    final t = context.gdText;
    final lang = context.language;
    final available = cart.cashbackAvailable;
    final canUse = available > 0;
    final quote = _quote;
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: GdCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.goldSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.savings_outlined,
                    size: 20,
                    color: c.goldInk,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        CheckoutText.cashbackTitle.of(context),
                        style: t.subheading,
                      ),
                      Text(
                        canUse
                            ? CheckoutText.cashbackAvailable.fmt(context, {
                                'amount': formatMoney(
                                  available,
                                  language: lang,
                                ),
                              })
                            : CheckoutText.cashbackNone.of(context),
                        style: t.bodySm,
                      ),
                    ],
                  ),
                ),
                Semantics(
                  identifier: 'checkout.cashback',
                  toggled: _useCashback,
                  child: Switch(
                    value: _useCashback && canUse,
                    onChanged: canUse ? _setCashback : null,
                  ),
                ),
              ],
            ),
            if (_useCashback &&
                canUse &&
                quote != null &&
                quote.cashbackMax < available)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 52),
                child: Text(
                  CheckoutText.cashbackMax.fmt(context, {
                    'amount': formatMoney(quote.cashbackMax, language: lang),
                  }),
                  style: t.caption,
                ),
              ),
            if (_cashbackError != null) InlineError(_cashbackError!),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context) {
    final c = context.gd;
    final t = context.gdText;
    final lang = context.language;
    final quote = _quote;
    final switching = _switchingShown;

    Widget row(
      String label,
      String value, {
      Color? color,
      String? id,
      String? caption,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.bodyMd.copyWith(color: c.inkMuted)),
                if (caption != null && caption.isNotEmpty)
                  Semantics(
                    identifier: id == null ? null : '$id.label',
                    child: Text(caption, style: t.caption),
                  ),
              ],
            ),
          ),
          Semantics(
            identifier: id,
            child: Text(
              value,
              style: t.label.copyWith(fontSize: 15, color: color ?? c.ink),
            ),
          ),
        ],
      ),
    );

    final Widget content;
    if (quote == null) {
      if (_quoteError != null) {
        content = Column(
          children: [
            Text(
              errorMessage(context, _quoteError!),
              textAlign: TextAlign.center,
              style: t.bodySm,
            ),
            const SizedBox(height: 10),
            GdOutlineButton(
              label: Strings.retry.of(context),
              onPressed: _recalc,
              semanticsId: 'checkout.recalc',
            ),
          ],
        );
      } else if (_calculating) {
        content = Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text(CheckoutText.calculating.of(context), style: t.bodySm),
            ],
          ),
        );
      } else {
        content = Text(
          _fulfilment == Fulfilment.delivery
              ? (_deliveryError != null
                    ? DeliveryText.none.of(context)
                    : CheckoutText.chooseAddress.of(context))
              : CheckoutText.calculating.of(context),
          style: t.bodySm,
        );
      }
    } else {
      final pickup = quote.fulfilment == Fulfilment.pickup;
      final free = pickup || quote.deliveryFee == 0;
      content = AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _calculating && !switching ? 0.45 : 1,
        child: Column(
          children: [
            row(
              CheckoutText.subtotal.of(context),
              formatMoney(quote.itemsSubtotal, language: lang),
              id: 'checkout.subtotal',
            ),
            row(
              CheckoutText.deliveryFee.of(context),
              switching
                  ? CheckoutText.calculating.of(context)
                  : free
                  ? CheckoutText.free.of(context)
                  : formatMoney(quote.deliveryFee, language: lang),
              color: !switching && free ? c.success : null,
              id: 'checkout.deliveryFee',
              caption: switching ? null : quote.selectedOption?.label,
            ),
            if (quote.cashbackToUse > 0)
              row(
                CheckoutText.cashbackDiscount.of(context),
                '−${formatMoney(quote.cashbackToUse, language: lang)}',
                color: c.goldInk,
                id: 'checkout.cashbackUsed',
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: c.line),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    CheckoutText.total.of(context),
                    style: t.subheading,
                  ),
                ),
                Semantics(
                  identifier: 'checkout.total',
                  child: Text(
                    switching
                        ? CheckoutText.calculating.of(context)
                        : formatMoney(quote.selectedTotal, language: lang),
                    style: switching ? t.bodySm : t.priceLg,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return GdCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  CheckoutText.summaryTitle.of(context),
                  style: t.heading,
                ),
              ),
              if (_calculating && quote != null)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          content,
        ],
      ),
    );
  }
}

/// A changed price or option the customer is asked to confirm.
class _NoticeBox extends StatelessWidget {
  const _NoticeBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    return Semantics(
      identifier: 'checkout.notice',
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: c.warningSoft,
          borderRadius: BorderRadius.circular(GdRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 18, color: c.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: context.gdText.bodySm.copyWith(color: c.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thumbnails of what is being ordered.
class _ItemsStrip extends StatelessWidget {
  const _ItemsStrip({required this.cart});
  final Cart cart;

  @override
  Widget build(BuildContext context) {
    final lines = cart.items
        .where((l) => l.status == CartLineStatus.ok)
        .toList();
    final shown = lines.take(4).toList();
    final extra = lines.length - shown.length;
    final c = context.gd;
    return GdCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.canPop() ? context.pop() : context.go('/cart'),
      child: Row(
        children: [
          for (final l in shown) ...[
            SizedBox.square(
              dimension: 48,
              child: GdImage(
                url: l.thumbUrl,
                fallbackUrl: l.imageUrl,
                seed: l.name,
                radius: GdRadius.sm,
                artSize: 30,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (extra > 0)
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.goldSoft,
                borderRadius: BorderRadius.circular(GdRadius.sm),
              ),
              child: Text('+$extra', style: context.gdText.label),
            ),
          const Spacer(),
          Text(
            CheckoutText.items.fmt(context, {'n': cart.quantityTotal}),
            style: context.gdText.caption,
          ),
          Icon(Icons.chevron_right_rounded, color: c.inkMuted),
        ],
      ),
    );
  }
}
