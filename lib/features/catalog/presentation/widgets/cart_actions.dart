import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/links/pending_action.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/gd_widgets.dart';
import '../../../auth/application/session_controller.dart';
import '../../../auth/presentation/consent_screen.dart';
import '../../../cart/application/cart_controller.dart';
import '../../../cart/data/cart_models.dart';
import '../catalog_text.dart';

/// "Savatga qo‘shish" from a card or the product page. Guests are sent to
/// sign in and the add is replayed afterwards. Returns true when the product
/// was added.
Future<bool> addProductToCart(
  BuildContext context,
  WidgetRef ref,
  int productId,
) async {
  if (!ref.read(sessionProvider).signedIn) {
    ref.read(pendingActionProvider.notifier).set(PendingAddToCart(productId));
    showSnack(context, CatalogText.signInToAdd.of(context));
    goSignIn(context);
    return false;
  }
  final cart = await runCartWrite(
    context,
    () => ref.read(cartProvider.notifier).add(productId),
  );
  return cart != null;
}

/// The +/− stepper: absolute quantity, 0 removes the line.
Future<bool> setCartQuantity(
  BuildContext context,
  WidgetRef ref,
  int productId,
  int quantity,
) async {
  final cart = await runCartWrite(
    context,
    () => ref.read(cartProvider.notifier).setQuantity(productId, quantity),
  );
  return cart != null;
}

/// Runs a cart write with the generic 409 handling (consent, phone), shows
/// the "max reached" note and any error. Returns the new cart, or null.
Future<Cart?> runCartWrite(
  BuildContext context,
  Future<Cart> Function() write,
) async {
  Future<Cart?> attempt({required bool canRetry}) async {
    try {
      final cart = await write();
      tick();
      if (cart.lastChangeMaxReached && context.mounted) {
        showSnack(context, CatalogText.maxReached.of(context));
      }
      return cart;
    } on ApiException catch (e) {
      if (!context.mounted) return null;
      if (canRetry && e.code == 'terms_update_required') {
        if (await askConsent(context) && context.mounted) {
          return attempt(canRetry: false);
        }
        return null;
      }
      if (canRetry && e.code == 'phone_required') {
        final attached = await context.push<bool>('/settings/phone') ?? false;
        if (attached && context.mounted) return attempt(canRetry: false);
        return null;
      }
      showError(context, e);
      return null;
    } on Object catch (e) {
      if (context.mounted) showError(context, e);
      return null;
    }
  }

  return attempt(canRetry: true);
}
