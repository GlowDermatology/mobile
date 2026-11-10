import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/app/theme/gd_theme.dart';
import 'package:glow_derma/core/format/money.dart';
import 'package:glow_derma/features/auth/application/session_controller.dart';
import 'package:glow_derma/features/cart/application/cart_controller.dart';
import 'package:glow_derma/features/cart/data/cart_models.dart';
import 'package:glow_derma/features/cart/presentation/cart_screen.dart';
import 'package:glow_derma/features/settings/data/public_settings.dart';

class _SignedIn extends SessionController {
  @override
  AuthState build() => const AuthState(signedIn: true);
}

class _FixedCart extends CartController {
  _FixedCart(this.cart);
  final Cart cart;
  final removed = <List<int>>[];
  final quantities = <(int, int)>[];

  @override
  Future<Cart> setQuantity(int productId, int quantity) async {
    quantities.add((productId, quantity));
    return cart;
  }

  @override
  Future<Cart> build() async => cart;

  @override
  Future<void> remove(Iterable<int> productIds) async =>
      removed.add(productIds.toList());

  @override
  Future<void> reload() async {}
}

Map<String, Object?> _line(
  int id,
  String name, {
  String status = 'ok',
  bool promo = false,
  int quantity = 1,
  int available = 5,
  int max = 5,
}) => {
  'product_id': id,
  'name': name,
  'volume': '50 ml',
  'main_image_url': null,
  'unit_price': 312000,
  'promo': promo,
  'quantity': quantity,
  'line_total': 312000 * quantity,
  'available': available,
  'max_quantity': max,
  'max_reached': false,
  'status': status,
  'price_changed': false,
  'previous_price': null,
};

Future<_FixedCart> _pump(WidgetTester tester, Cart cart) async {
  final controller = _FixedCart(cart);
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(_SignedIn.new),
        cartProvider.overrideWith(() => controller),
        publicSettingsProvider.overrideWith(
          (ref) async => const PublicSettings({
            'payment_providers': ['click', 'payme'],
            'online_sales_enabled': true,
            'fulfilment_methods': ['delivery', 'pickup'],
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
        home: const CartScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('renders lines by status and the pay total', (tester) async {
    final cart = Cart.fromJson({
      'items': [
        _line(4, 'Seramidli krem'),
        _line(2, 'Quyoshdan himoya kremi', promo: true),
        _line(
          9,
          'Niatsinamidli toner',
          status: 'out_of_stock',
          available: 0,
          max: 0,
        ),
      ],
      'item_count': 3,
      'quantity_total': 3,
      'items_subtotal': 784400,
      'promo_subtotal': 0,
      'has_problems': true,
      'cashback': {'available': 0, 'max_usable_pickup': 0},
    });
    await _pump(tester, cart);

    expect(find.text('Savat'), findsOneWidget);
    expect(find.text('3 ta mahsulot'), findsOneWidget);
    expect(find.text('Hammasini tanlash'), findsOneWidget);
    expect(find.text('AKSIYA'), findsOneWidget);
    expect(find.text('Cashback hisoblanmaydi'), findsOneWidget);
    expect(find.text('Tugagan — buyurtmaga kirmaydi'), findsOneWidget);
    expect(find.text('To‘lash'), findsOneWidget);
    expect(find.text(formatMoney(784400)), findsOneWidget);
    // has_problems: the bar explains why it is disabled.
    expect(
      find.text('Buyurtma berish uchun belgilangan mahsulotlarni tuzating.'),
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

  testWidgets('select all shows the bulk remove action', (tester) async {
    final cart = Cart.fromJson({
      'items': [_line(4, 'Seramidli krem'), _line(3, 'Ko‘pik')],
      'item_count': 2,
      'quantity_total': 2,
      'items_subtotal': 624000,
      'has_problems': false,
      'cashback': {'available': 0},
    });
    final controller = await _pump(tester, cart);
    expect(find.textContaining('O‘chirish'), findsNothing);

    await tester.tap(find.text('Hammasini tanlash'));
    await tester.pumpAndSettle();
    expect(find.text('O‘chirish (2)'), findsOneWidget);

    await tester.tap(find.text('O‘chirish (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Olib tashlash'));
    await tester.pumpAndSettle();
    expect(controller.removed, [
      [4, 3],
    ]);
  });

  testWidgets('empty cart offers the catalog', (tester) async {
    await _pump(tester, Cart.empty);
    expect(find.text('Savat hozircha bo‘sh'), findsOneWidget);
    expect(find.text('Katalogga o‘tish'), findsOneWidget);
  });

  testWidgets(
    'stepper: plus sets quantity+1, disabled at max; minus at 1 removes after confirmation',
    (tester) async {
      final cart = Cart.fromJson({
        'items': [
          _line(4, 'Seramidli krem', quantity: 2),
          _line(3, 'Ko‘pik', quantity: 1, max: 1),
        ],
        'item_count': 2,
        'quantity_total': 3,
        'items_subtotal': 936000,
        'has_problems': false,
        'cashback': {'available': 0},
      });
      final controller = await _pump(tester, cart);
      Finder byId(String id) => find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == id,
      );
      expect(byId('cart.line.4.plus'), findsOneWidget);

      await tester.tap(byId('cart.line.4.plus'));
      await tester.pumpAndSettle();
      expect(controller.quantities, [(4, 3)]);

      // Line 3 is at its max: plus does nothing.
      await tester.tap(byId('cart.line.3.plus'));
      await tester.pumpAndSettle();
      expect(controller.quantities, [(4, 3)]);

      await tester.tap(byId('cart.line.3.minus'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Olib tashlash'));
      await tester.pumpAndSettle();
      expect(controller.removed, [
        [3],
      ]);
    },
  );
}
