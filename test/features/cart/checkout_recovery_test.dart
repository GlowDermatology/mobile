import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/app/theme/gd_theme.dart';
import 'package:glow_derma/core/format/money.dart';
import 'package:glow_derma/core/network/api_exception.dart';
import 'package:glow_derma/core/network/json.dart';
import 'package:glow_derma/features/auth/application/session_controller.dart';
import 'package:glow_derma/features/cart/application/cart_controller.dart';
import 'package:glow_derma/features/cart/data/cart_models.dart';
import 'package:glow_derma/features/cart/presentation/cart_line_view.dart';
import 'package:glow_derma/features/cart/presentation/cart_screen.dart';
import 'package:glow_derma/features/cart/presentation/cart_text.dart';
import 'package:glow_derma/features/cart/presentation/checkout_recovery_card.dart';
import 'package:glow_derma/features/orders/data/order_models.dart';
import 'package:glow_derma/features/orders/data/orders_api.dart';
import 'package:glow_derma/features/settings/data/public_settings.dart';
import 'package:go_router/go_router.dart';

import '../orders/fakes.dart';

const _settings = PublicSettings({
  'payment_providers': ['click', 'payme'],
  'online_sales_enabled': true,
  'fulfilment_methods': ['delivery', 'pickup'],
});

Json _line(int id, String name) => {
  'product_id': id,
  'name': name,
  'volume': '50 ml',
  'main_image_url': null,
  'unit_price': 312000,
  'promo': false,
  'quantity': 1,
  'line_total': 312000,
  'available': 5,
  'max_quantity': 5,
  'max_reached': false,
  'status': 'ok',
  'price_changed': false,
  'previous_price': null,
};

/// The cart right after checkout (local backend): no lines, the unpaid
/// order in `checkout_order`.
Json _cartJson({Json? order, List<Json> items = const []}) => {
  'items': items,
  'item_count': items.length,
  'quantity_total': items.length,
  'items_subtotal': 312000 * items.length,
  'promo_subtotal': 0,
  'has_problems': false,
  'cashback': {'available': 0, 'max_usable_pickup': 0},
  'last_change': null,
  'checkout_order': order,
};

Json _cancelled({String reason = 'customer_request'}) => orderJson(
  status: 'cancelled',
  statusLabel: 'Bekor qilindi',
  paymentStatus: 'pending',
  reorder: true,
  cancellation: {'reason': reason, 'label': 'Bekor qilindi'},
);

class _SignedIn extends SessionController {
  @override
  AuthState build() => const AuthState(signedIn: true);
}

class _SignedOut extends SessionController {
  @override
  AuthState build() => const AuthState(signedIn: false);
}

/// The real controller (so [CartController.restoreUnpaid] runs) over a
/// fixed first cart; reloads are counted and answer [next] when set.
class _Cart extends CartController {
  _Cart(this.initial);
  final Cart initial;
  Cart? next;
  var reloads = 0;

  @override
  Future<Cart> build() async => initial;

  @override
  Future<void> reload() async {
    reloads++;
    if (next != null) state = AsyncData(next!);
  }
}

Finder _byId(String id) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.identifier == id,
);

Future<_Cart> _pump(
  WidgetTester tester,
  Cart cart,
  FakeOrdersApi api, {
  List<String>? visited,
}) async {
  final controller = _Cart(cart);
  tester.view.physicalSize = const Size(390, 2400) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/cart',
    routes: [
      GoRoute(path: '/cart', builder: (_, _) => const CartScreen()),
      GoRoute(
        path: '/pay/:id',
        builder: (_, s) {
          visited?.add(s.uri.path);
          return const Scaffold(body: Text('pay screen'));
        },
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (_, s) {
          visited?.add(s.uri.path);
          return const Scaffold(body: Text('order screen'));
        },
      ),
      GoRoute(path: '/checkout', builder: (_, _) => const Text('checkout')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(_SignedIn.new),
        cartProvider.overrideWith(() => controller),
        ordersApiProvider.overrideWithValue(api),
        publicSettingsProvider.overrideWith((ref) async => _settings),
      ],
      child: MaterialApp.router(
        theme: buildTheme(Brightness.light),
        locale: const Locale('uz'),
        supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return controller;
}

void main() {
  group('recoveryPhase', () {
    final now = DateTime.now();

    test('pending while payable', () {
      expect(recoveryPhase(detail(awaitingJson()), now), RecoveryPhase.pending);
    });

    test('confirming while a provider transaction is in flight', () {
      expect(
        recoveryPhase(detail(awaitingJson(inProgress: true)), now),
        RecoveryPhase.confirming,
      );
      // Even past the deadline: the provider's answer decides.
      expect(
        recoveryPhase(
          detail(awaitingJson(inProgress: true, left: -Duration.zero)),
          now.add(const Duration(hours: 1)),
        ),
        RecoveryPhase.confirming,
      );
    });

    test('expired once pay_by passed, or cancelled for it', () {
      final order = detail(awaitingJson(left: const Duration(minutes: 1)));
      expect(
        recoveryPhase(order, now.add(const Duration(minutes: 2))),
        RecoveryPhase.expired,
      );
      expect(
        recoveryPhase(order, order.payBy!),
        RecoveryPhase.expired,
        reason: 'pay_by itself is too late',
      );
      expect(
        recoveryPhase(detail(_cancelled(reason: 'reservation_expired')), now),
        RecoveryPhase.expired,
      );
    });

    test('cancelled by the customer', () {
      expect(recoveryPhase(detail(_cancelled()), now), RecoveryPhase.cancelled);
    });
  });

  group('pay bar', () {
    test('blocked while an order waits for payment', () {
      final cart = Cart.fromJson(
        _cartJson(order: awaitingJson(), items: [_line(4, 'Krem')]),
      );
      expect(cart.hasUnpaidOrder, isTrue);
      expect(payBlockReason(cart, _settings), CartText.recoveryResolveFirst);
      expect(canPay(cart, _settings), isFalse);
    });

    test('an expired or cancelled checkout does not block', () {
      final cart = Cart.fromJson(
        _cartJson(order: _cancelled(), items: [_line(4, 'Krem')]),
      );
      expect(payBlockReason(cart, _settings), isNull);
      expect(canPay(cart, _settings), isTrue);
    });
  });

  test('restoreUnpaid: reorder with cancel_unpaid, one key per intent, '
      'and the answer replaces the cart', () async {
    final api = FakeOrdersApi()
      ..reorderResult = Cart.fromJson(_cartJson(items: [_line(4, 'Krem')]));
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(_SignedOut.new),
        ordersApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    await container.read(cartProvider.future);
    final cart = await container
        .read(cartProvider.notifier)
        .restoreUnpaid(10248);
    expect(api.reorderCalls, hasLength(1));
    expect(api.reorderCalls.single.$1, 10248);
    expect(api.reorderCalls.single.$3, isTrue);
    expect(container.read(cartProvider).value, same(cart));
    expect(cart.items.single.productId, 4);

    // A new intent gets a new key.
    await container.read(cartProvider.notifier).restoreUnpaid(10248);
    expect(api.reorderCalls[1].$2, isNot(api.reorderCalls[0].$2));
  });

  group('CheckoutRecoveryCard in the cart', () {
    testWidgets('right after checkout: the unpaid order replaces the empty '
        'state', (tester) async {
      final visited = <String>[];
      await _pump(
        tester,
        Cart.fromJson(_cartJson(order: awaitingJson())),
        FakeOrdersApi(),
        visited: visited,
      );
      expect(_byId('cart.recovery'), findsOneWidget);
      expect(find.text('Savat hozircha bo‘sh'), findsNothing);
      expect(find.text('To‘lov kutilmoqda'), findsOneWidget);
      expect(find.text('Buyurtma tafsilotlari · №10248'), findsOneWidget);
      expect(find.text('Seramidli namlantiruvchi krem'), findsOneWidget);
      expect(find.text('2 × ${formatMoney(128000)}'), findsOneWidget);
      expect(find.text(formatMoney(256000)), findsOneWidget);
      expect(find.text('Yetkazib berish'), findsOneWidget);
      expect(find.text(formatMoney(-48600)), findsOneWidget);
      expect(find.text(formatMoney(784400)), findsOneWidget);
      expect(find.text('Mahsulotlarni tahrirlash'), findsOneWidget);
      expect(
        find.textContaining('Tahrirlash to‘lanmagan buyurtmani'),
        findsOneWidget,
      );
      // No pay bar without lines.
      expect(_byId('cart.pay'), findsNothing);

      await tester.tap(_byId('cart.recovery.pay'));
      await tester.pumpAndSettle();
      expect(visited, ['/pay/10248']);
    });

    testWidgets('the details link opens the order', (tester) async {
      final visited = <String>[];
      await _pump(
        tester,
        Cart.fromJson(_cartJson(order: awaitingJson())),
        FakeOrdersApi(),
        visited: visited,
      );
      await tester.tap(_byId('cart.recovery.details'));
      await tester.pumpAndSettle();
      expect(visited, ['/orders/10248']);
    });

    testWidgets('edit: reorder with cancel_unpaid and the cart is replaced', (
      tester,
    ) async {
      final api = FakeOrdersApi()
        ..reorderResult = Cart.fromJson(
          _cartJson(items: [_line(4, 'Seramidli krem'), _line(5, 'Ko‘pik')]),
        );
      final controller = await _pump(
        tester,
        Cart.fromJson(_cartJson(order: awaitingJson())),
        api,
      );
      await tester.tap(_byId('cart.recovery.restore'));
      await tester.pump();
      await tester.pump();
      expect(api.reorderCalls.single.$1, 10248);
      expect(api.reorderCalls.single.$3, isTrue);
      expect(controller.state.value!.items, hasLength(2));
      expect(
        find.text(
          'Mahsulotlar savatga qaytarildi. Narx va miqdorlarni tekshiring.',
        ),
        findsOneWidget,
      );
      expect(_byId('cart.recovery'), findsNothing);
      expect(find.text('Seramidli krem'), findsOneWidget);
      expect(find.text('To‘lash'), findsOneWidget);
    });

    testWidgets('a refused edit shows the server message', (tester) async {
      final api = FakeOrdersApi()
        ..reorderError = const ApiException(
          status: 409,
          code: 'cart_full',
          message: 'Savat to‘lgan.',
        );
      final controller = await _pump(
        tester,
        Cart.fromJson(_cartJson(order: awaitingJson())),
        api,
      );
      final before = controller.reloads;
      await tester.tap(_byId('cart.recovery.restore'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Savat to‘lgan.'), findsOneWidget);
      expect(controller.reloads, before + 1);
      expect(_byId('cart.recovery'), findsOneWidget);
    });

    testWidgets('confirming: no pay, no edit; refresh reloads', (tester) async {
      final controller = await _pump(
        tester,
        Cart.fromJson(_cartJson(order: awaitingJson(inProgress: true))),
        FakeOrdersApi(),
      );
      expect(find.text('To‘lov tasdiqlanishi kutilmoqda'), findsOneWidget);
      expect(_byId('cart.recovery.pay'), findsNothing);
      expect(_byId('cart.recovery.restore'), findsNothing);
      final before = controller.reloads;
      await tester.tap(_byId('cart.recovery.refresh'));
      await tester.pump();
      expect(controller.reloads, before + 1);
    });

    testWidgets('cancelled: restore only', (tester) async {
      await _pump(
        tester,
        Cart.fromJson(_cartJson(order: _cancelled())),
        FakeOrdersApi(),
      );
      expect(find.text('To‘lanmagan buyurtma bekor qilingan'), findsOneWidget);
      expect(_byId('cart.recovery.pay'), findsNothing);
      expect(find.text('Mahsulotlarni savatga qaytarish'), findsOneWidget);
      expect(
        find.textContaining('Tahrirlash to‘lanmagan buyurtmani'),
        findsNothing,
      );
    });

    testWidgets('the phase turns expired when the time runs out', (
      tester,
    ) async {
      await _pump(
        tester,
        Cart.fromJson(
          _cartJson(order: awaitingJson(left: const Duration(seconds: 3))),
        ),
        FakeOrdersApi(),
      );
      expect(find.text('To‘lov kutilmoqda'), findsOneWidget);
      expect(_byId('cart.recovery.pay'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Band qilish muddati tugadi'), findsOneWidget);
      expect(_byId('cart.recovery.pay'), findsNothing);
      expect(find.text('Mahsulotlarni savatga qaytarish'), findsOneWidget);
    });

    testWidgets('lines added afterwards sit under their heading and the pay '
        'bar is blocked', (tester) async {
      await _pump(
        tester,
        Cart.fromJson(
          _cartJson(order: awaitingJson(), items: [_line(7, 'Toner')]),
        ),
        FakeOrdersApi(),
      );
      expect(_byId('cart.recovery'), findsOneWidget);
      expect(find.text('Keyin qo‘shilgan mahsulotlar'), findsOneWidget);
      expect(find.text('Toner'), findsOneWidget);
      expect(
        find.text(
          'Yangi buyurtma berish uchun avval yuqoridagi to‘lovni davom '
          'ettiring yoki mahsulotlarni tahrirlang.',
        ),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('To‘lash'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('polling', () {
    testWidgets('every 5 s while an order waits for payment', (tester) async {
      final controller = await _pump(
        tester,
        Cart.fromJson(_cartJson(order: awaitingJson())),
        FakeOrdersApi(),
      );
      final start = controller.reloads;
      await tester.pump(const Duration(seconds: 5));
      expect(controller.reloads, start + 1);
      await tester.pump(const Duration(seconds: 10));
      expect(controller.reloads, start + 3);

      // Paid: the order leaves the cart and the polling stops.
      controller.next = Cart.fromJson(_cartJson());
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      final after = controller.reloads;
      await tester.pump(const Duration(seconds: 30));
      expect(controller.reloads, after);
      expect(find.text('Savat hozircha bo‘sh'), findsOneWidget);
    });

    testWidgets('not in the background; reloads on resume', (tester) async {
      final controller = await _pump(
        tester,
        Cart.fromJson(_cartJson(order: awaitingJson())),
        FakeOrdersApi(),
      );
      final start = controller.reloads;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 30));
      expect(controller.reloads, start);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(controller.reloads, start + 1);
      await tester.pump(const Duration(seconds: 5));
      expect(controller.reloads, start + 2);
    });

    testWidgets('no polling without an unpaid order', (tester) async {
      final controller = await _pump(
        tester,
        Cart.fromJson(_cartJson(items: [_line(4, 'Krem')])),
        FakeOrdersApi(),
      );
      final start = controller.reloads;
      await tester.pump(const Duration(seconds: 30));
      expect(controller.reloads, start);
    });

    testWidgets('not while the cart tab is hidden', (tester) async {
      final controller = _Cart(Cart.fromJson(_cartJson(order: awaitingJson())));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(_SignedIn.new),
            cartProvider.overrideWith(() => controller),
            ordersApiProvider.overrideWithValue(FakeOrdersApi()),
            publicSettingsProvider.overrideWith((ref) async => _settings),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: const TickerMode(enabled: false, child: CartScreen()),
          ),
        ),
      );
      await tester.pump();
      final start = controller.reloads;
      await tester.pump(const Duration(seconds: 30));
      expect(controller.reloads, start);
    });
  });

  test('OrderStatus of the fixture', () {
    expect(detail(awaitingJson()).status, OrderStatus.awaitingPayment);
  });
}
