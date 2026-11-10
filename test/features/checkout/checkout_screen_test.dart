import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:glow_derma/app/theme/gd_theme.dart';
import 'package:glow_derma/core/format/money.dart';
import 'package:glow_derma/features/auth/application/session_controller.dart';
import 'package:glow_derma/features/cart/application/cart_controller.dart';
import 'package:glow_derma/features/cart/data/cart_models.dart';
import 'package:glow_derma/features/checkout/data/checkout_api.dart';
import 'package:glow_derma/features/checkout/presentation/checkout_screen.dart';
import 'package:glow_derma/features/profile/data/addresses_api.dart';
import 'package:glow_derma/features/settings/data/public_settings.dart';

class _SignedIn extends SessionController {
  @override
  AuthState build() => const AuthState(signedIn: true);
}

class _FixedCart extends CartController {
  _FixedCart(this.cart);
  final Cart cart;
  @override
  Future<Cart> build() async => cart;
  @override
  Future<void> reload() async {}
}

class _FakeApi implements CheckoutApi {
  final calculations = <Map<String, Object?>>[];
  final checkouts = <Map<String, Object?>>[];
  final keys = <String>[];

  @override
  Future<DeliveryQuote> calculate(Map<String, Object?> body) async {
    calculations.add(body);
    final delivery = body['fulfilment'] == 'delivery';
    final fee = delivery ? 25000 : 0;
    final cashback = body['cashback_to_use']! as int;
    return DeliveryQuote.fromJson({
      'fulfilment': body['fulfilment'],
      'delivery_fee': fee,
      'items_subtotal': 808000,
      'cashback_max': 48600,
      'cashback_to_use': cashback > 48600 ? 48600 : cashback,
      'expected_total': 808000 + fee - (cashback > 48600 ? 48600 : cashback),
    }, addressId: body['address_id'] as int?);
  }

  @override
  Future<int> checkout(
    Map<String, Object?> body, {
    required String idempotencyKey,
  }) async {
    checkouts.add(body);
    keys.add(idempotencyKey);
    return 10248;
  }
}

void main() {
  testWidgets('recalculates on every change and posts the last quote', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final api = _FakeApi();
    final cart = Cart.fromJson({
      'items': [
        {
          'product_id': 4,
          'name': 'Krem',
          'volume': '50 ml',
          'unit_price': 404000,
          'quantity': 2,
          'line_total': 808000,
          'available': 5,
          'max_quantity': 5,
          'status': 'ok',
        },
      ],
      'item_count': 1,
      'quantity_total': 2,
      'items_subtotal': 808000,
      'has_problems': false,
      'cashback': {'available': 60000, 'max_usable_pickup': 48600},
    });
    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(path: '/checkout', builder: (_, _) => const CheckoutScreen()),
        GoRoute(
          path: '/pay/:id',
          builder: (_, s) => Text('pay ${s.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_SignedIn.new),
          cartProvider.overrideWith(() => _FixedCart(cart)),
          checkoutApiProvider.overrideWithValue(api),
          addressesProvider.overrideWith(
            (ref) async => [
              Address.fromJson({
                'id': 7,
                'label': 'Eski',
                'text': 'Eski manzil',
                'region_code': '',
                'city_code': '',
                'is_default': false,
              }),
              Address.fromJson({
                'id': 12,
                'label': 'Uy',
                'text': 'Chilonzor 9',
                'region_code': '10',
                'city_code': '1001',
                'is_default': true,
              }),
            ],
          ),
          publicSettingsProvider.overrideWith(
            (ref) async => const PublicSettings({
              'payment_providers': ['click', 'payme'],
              'online_sales_enabled': true,
              'fulfilment_methods': ['delivery', 'pickup'],
              'pickup_address': 'Toshkent, Bunyodkor 12',
              'reservation_minutes': 15,
            }),
          ),
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
    await tester.pumpAndSettle();

    // Delivery with the default usable address is preselected.
    expect(api.calculations.last, {
      'fulfilment': 'delivery',
      'address_id': 12,
      'cashback_to_use': 0,
    });
    expect(find.text(formatMoney(833000)), findsOneWidget);
    expect(
      find.text('Viloyat va tuman ko‘rsatilmagan — manzilni tahrirlang'),
      findsOneWidget,
    );

    // Cashback switch: asks with the whole available balance, shows the server's numbers.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(api.calculations.last['cashback_to_use'], 60000);
    expect(find.text('−${formatMoney(48600)}'), findsOneWidget);
    expect(find.text(formatMoney(784400)), findsOneWidget);

    // Pickup.
    await tester.tap(find.text('Do‘kondan olib ketish'));
    await tester.pumpAndSettle();
    expect(api.calculations.last, {
      'fulfilment': 'pickup',
      'address_id': null,
      'cashback_to_use': 60000,
    });

    await tester.enterText(find.byType(TextField), 'Soat 18:00 dan keyin');
    await tester.tap(find.textContaining('Buyurtma berish'));
    await tester.pumpAndSettle();
    expect(api.checkouts.single, {
      'fulfilment': 'pickup',
      'address_id': null,
      'payment_provider': 'click',
      'cashback_to_use': 48600,
      'expected_total': 759400,
      'customer_note': 'Soat 18:00 dan keyin',
    });
    expect(api.keys.single, isNotEmpty);
    expect(find.text('pay 10248'), findsOneWidget);
  });

  testWidgets('without a usable address the checkout starts on pickup', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final api = _FakeApi();
    final cart = Cart.fromJson({
      'items': [
        {
          'product_id': 4,
          'name': 'Krem',
          'volume': '50 ml',
          'unit_price': 404000,
          'quantity': 2,
          'line_total': 808000,
          'available': 5,
          'max_quantity': 5,
          'status': 'ok',
        },
      ],
      'item_count': 1,
      'quantity_total': 2,
      'items_subtotal': 808000,
      'has_problems': false,
      'cashback': {'available': 0},
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_SignedIn.new),
          cartProvider.overrideWith(() => _FixedCart(cart)),
          checkoutApiProvider.overrideWithValue(api),
          addressesProvider.overrideWith(
            (ref) async => [
              Address.fromJson({
                'id': 7,
                'label': 'Eski',
                'text': 'Eski manzil',
                'region_code': '',
                'city_code': '',
                'is_default': true,
              }),
            ],
          ),
          publicSettingsProvider.overrideWith(
            (ref) async => const PublicSettings({
              'payment_providers': ['click'],
              'online_sales_enabled': true,
              'fulfilment_methods': ['delivery', 'pickup'],
              'pickup_address': 'Toshkent, Bunyodkor 12',
              'reservation_minutes': 15,
            }),
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          locale: const Locale('uz'),
          supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const CheckoutScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.calculations, [
      {'fulfilment': 'pickup', 'address_id': null, 'cashback_to_use': 0},
    ]);
    expect(find.text(formatMoney(808000)), findsWidgets);
  });
}
