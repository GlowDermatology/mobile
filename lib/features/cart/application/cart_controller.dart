import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/json.dart';
import '../../auth/application/session_controller.dart';
import '../data/cart_models.dart';

/// The server cart (contract §2.5). Every write answers the whole cart, which
/// replaces the state (and the tab badge). Quantity changes are applied
/// optimistically and rolled back when the server refuses them.
class CartController extends AsyncNotifier<Cart> {
  @override
  Future<Cart> build() async {
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    if (!signedIn) return Cart.empty;
    return _fetch();
  }

  Future<Cart> _fetch() async =>
      Cart.fromJson(asJson(await ref.read(apiClientProvider).get('cart/')));

  Future<void> reload() async {
    if (!ref.read(sessionProvider).signedIn) return;
    try {
      state = AsyncData(await _fetch());
    } on Object catch (e, st) {
      if (!state.hasValue) state = AsyncError(e, st);
    }
  }

  Cart get _current => state.value ?? Cart.empty;

  /// "Savatga qo‘shish": adds [quantity]. Returns the new cart; throws
  /// [ApiException] (`OUT_OF_STOCK`, `product_unavailable`, `cart_full`,
  /// `online_sales_unavailable`).
  Future<Cart> add(int productId, {int quantity = 1}) async {
    final keys = ref.read(idempotencyProvider);
    final intent = 'cart.add.$productId';
    try {
      final cart = Cart.fromJson(
        asJson(
          await ref
              .read(apiClientProvider)
              .post(
                'cart/items/',
                body: {'product_id': productId, 'quantity': quantity},
                idempotencyKey: keys.keyFor(intent),
              ),
        ),
      );
      keys.done(intent);
      state = AsyncData(cart);
      return cart;
    } on ApiException catch (e) {
      if (!e.isNetwork) keys.done(intent);
      rethrow;
    }
  }

  /// Sets an absolute quantity (retry-safe); 0 removes the line.
  Future<Cart> setQuantity(int productId, int quantity) async {
    final before = _current;
    state = AsyncData(before.withLineQuantity(productId, quantity));
    try {
      final api = ref.read(apiClientProvider);
      final json = quantity <= 0
          ? await api.delete('cart/items/$productId/')
          : await api.patch(
              'cart/items/$productId/',
              body: {'quantity': quantity},
            );
      final cart = Cart.fromJson(asJson(json));
      state = AsyncData(cart);
      return cart;
    } on Object {
      state = AsyncData(before);
      rethrow;
    }
  }

  Future<void> remove(Iterable<int> productIds) async {
    final ids = productIds.toList();
    if (ids.isEmpty) return;
    final before = _current;
    var preview = before;
    for (final id in ids) {
      preview = preview.withLineQuantity(id, 0);
    }
    state = AsyncData(preview);
    try {
      final json = await ref
          .read(apiClientProvider)
          .delete(
            'cart/items/',
            query: {'product_id': ids.map((e) => '$e').toList()},
          );
      state = AsyncData(Cart.fromJson(asJson(json)));
    } on Object {
      state = AsyncData(before);
      rethrow;
    }
  }

  /// Replace the state with a cart returned by another endpoint (reorder).
  void replace(Cart cart) => state = AsyncData(cart);
}

final cartProvider = AsyncNotifierProvider<CartController, Cart>(
  CartController.new,
);

/// Tab badge: number of lines.
final cartBadgeProvider = Provider<int>(
  (ref) => ref.watch(cartProvider).value?.itemCount ?? 0,
);
