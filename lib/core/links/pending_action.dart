import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Something a guest wanted to do before being asked to sign in ("add this
/// product to the cart"). Replayed once after the sign-in succeeds.
sealed class PendingAction {
  const PendingAction();
}

class PendingAddToCart extends PendingAction {
  const PendingAddToCart(this.productId);
  final int productId;
}

class PendingActionController extends Notifier<PendingAction?> {
  @override
  PendingAction? build() => null;
  void set(PendingAction action) => state = action;
  PendingAction? take() {
    final a = state;
    state = null;
    return a;
  }
}

final pendingActionProvider = NotifierProvider<PendingActionController, PendingAction?>(PendingActionController.new);
