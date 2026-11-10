import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/gd_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/idempotency.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../auth/presentation/consent_screen.dart';
import '../../cart/application/cart_controller.dart';
import '../data/order_models.dart';
import '../data/orders_api.dart';
import 'orders_text.dart';

/// Runs [action], handling the generic 409s once: `terms_update_required`
/// (asks for consent, then retries) and `phone_required` (attaches a phone,
/// then retries). Any other error is rethrown.
Future<T> runGuarded<T>(
  BuildContext context,
  Future<T> Function() action, {
  bool retried = false,
}) async {
  try {
    return await action();
  } on ApiException catch (e) {
    if (retried || e.status != 409 || !context.mounted) rethrow;
    if (e.code == 'terms_update_required') {
      if (await askConsent(context) && context.mounted) {
        return runGuarded(context, action, retried: true);
      }
    } else if (e.code == 'phone_required') {
      if (await context.push<bool>('/settings/phone') == true &&
          context.mounted) {
        return runGuarded(context, action, retried: true);
      }
    }
    rethrow;
  }
}

/// Runs a POST with an `Idempotency-Key` for [intent]: the key is reused
/// when the same intent is retried after a network error and dropped after
/// any answer of the server.
Future<T> withIntentKey<T>(
  WidgetRef ref,
  String intent,
  Future<T> Function(String key) call,
) => withKey(ref.read(idempotencyProvider), intent, call);

/// [withIntentKey] on a given key store (pure, for tests).
Future<T> withKey<T>(
  IdempotencyKeys keys,
  String intent,
  Future<T> Function(String key) call,
) async {
  try {
    final result = await call(keys.keyFor(intent));
    keys.done(intent);
    return result;
  } on ApiException catch (e) {
    if (!e.isNetwork) keys.done(intent);
    rethrow;
  }
}

/// "Buyurtmani bekor qilasizmi?" confirmation.
Future<bool> confirmCancel(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        OrdersText.cancelTitle.of(context),
        style: context.gdText.heading,
      ),
      content: Text(
        OrdersText.cancelBody.of(context),
        style: context.gdText.bodyMd,
      ),
      actions: [
        Semantics(
          identifier: 'order.cancel.keep',
          button: true,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(OrdersText.cancelKeep.of(context)),
          ),
        ),
        Semantics(
          identifier: 'order.cancel.confirm',
          button: true,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.gd.danger),
            child: Text(OrdersText.cancelConfirm.of(context)),
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Confirms and cancels the order; answers the cancelled order, or null when
/// the customer changed their mind or the server refused (message shown).
Future<OrderDetail?> cancelOrder(
  BuildContext context,
  WidgetRef ref,
  int orderId,
) async {
  if (!await confirmCancel(context) || !context.mounted) return null;
  try {
    final order = await runGuarded(
      context,
      () => withIntentKey(
        ref,
        'cancel.$orderId',
        (key) =>
            ref.read(ordersApiProvider).cancel(orderId, idempotencyKey: key),
      ),
    );
    if (context.mounted) showSnack(context, OrdersText.cancelled.of(context));
    return order;
  } on Object catch (e) {
    if (context.mounted) showError(context, e);
    return null;
  }
}

/// Copies the order's lines back into the cart and opens it.
Future<bool> reorderOrder(
  BuildContext context,
  WidgetRef ref,
  int orderId,
) async {
  try {
    final cart = await runGuarded(
      context,
      () => withIntentKey(
        ref,
        'reorder.$orderId',
        (key) =>
            ref.read(ordersApiProvider).reorder(orderId, idempotencyKey: key),
      ),
    );
    ref.read(cartProvider.notifier).replace(cart);
    if (!context.mounted) return true;
    showSnack(context, OrdersText.reordered.of(context));
    context.go('/cart');
    return true;
  } on Object catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
}
