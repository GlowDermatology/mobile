import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:glow_derma/app/theme/gd_theme.dart';
import 'package:glow_derma/core/format/money.dart';
import 'package:glow_derma/core/i18n/tr.dart';
import 'package:glow_derma/core/network/api_exception.dart';
import 'package:glow_derma/core/network/json.dart';
import 'package:glow_derma/core/widgets/gd_widgets.dart';
import 'package:glow_derma/features/auth/application/session_controller.dart';
import 'package:glow_derma/features/cart/application/cart_controller.dart';
import 'package:glow_derma/features/cart/data/cart_models.dart';
import 'package:glow_derma/features/checkout/data/checkout_api.dart';
import 'package:glow_derma/features/checkout/presentation/checkout_screen.dart';
import 'package:glow_derma/features/checkout/presentation/delivery_options.dart';
import 'package:glow_derma/features/profile/data/addresses_api.dart';
import 'package:glow_derma/features/settings/data/public_settings.dart';

import 'delivery_flow_test.dart'
    show pinnedAnswer, unpinnedAnswer, withStandard;

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

/// The released (BTS-only) answer: no options.
DeliveryQuote _released(Map<String, Object?> body) {
  final delivery = body['fulfilment'] == 'delivery';
  final fee = delivery ? 25000 : 0;
  final cashback = body['cashback_to_use']! as int;
  final used = cashback > 48600 ? 48600 : cashback;
  return DeliveryQuote.fromJson({
    'fulfilment': body['fulfilment'],
    'delivery_fee': fee,
    'items_subtotal': 808000,
    'cashback_max': 48600,
    'cashback_to_use': used,
    'expected_total': 808000 + fee - used,
  }, addressId: body['address_id'] as int?);
}

/// The local backend's answers: Standard by default, Express when asked;
/// address 13 has no pin.
Json yandexAnswer(Map<String, Object?> body) {
  if (body['address_id'] == 13) return unpinnedAnswer();
  if (body['delivery_provider'] == 'yandex' &&
      body['delivery_method'] == 'express') {
    return {
      ...pinnedAnswer(),
      'delivery_fee': 51000,
      'expected_total': 236000,
      'method': 'express',
      'quote_id': '4847f532-59b0-47ab-a0f9-fab683dcef75',
    };
  }
  return pinnedAnswer();
}

class _FakeApi implements CheckoutApi {
  _FakeApi({this.answer, this.onCheckout});

  final Json Function(Map<String, Object?> body)? answer;
  final Future<int> Function(int call, Map<String, Object?> body)? onCheckout;
  final calculations = <Map<String, Object?>>[];
  final checkouts = <Map<String, Object?>>[];
  final keys = <String>[];

  @override
  Future<DeliveryQuote> calculate(Map<String, Object?> body) async {
    calculations.add(body);
    final answer = this.answer;
    if (answer == null || body['fulfilment'] != 'delivery') {
      return _released(body);
    }
    return DeliveryQuote.fromJson(
      answer(body),
      addressId: body['address_id'] as int?,
    );
  }

  @override
  Future<int> checkout(
    Map<String, Object?> body, {
    required String idempotencyKey,
  }) async {
    checkouts.add(body);
    keys.add(idempotencyKey);
    return onCheckout?.call(checkouts.length, body) ?? 10248;
  }
}

/// Every delivery quote is refused (`delivery_unavailable`).
class _FakeApiRefusing extends _FakeApi {
  int calls = 0;

  @override
  Future<DeliveryQuote> calculate(Map<String, Object?> body) async {
    calls++;
    calculations.add(body);
    Json refused(String method, String label) => {
      'provider': 'yandex',
      'method': method,
      'label': label,
      'available': false,
      'unavailable_reason': 'provider_unavailable',
    };
    throw ApiException(
      status: 409,
      code: 'delivery_unavailable',
      message: 'Hozir yetkazib bo‘lmaydi',
      details: {
        'options': [
          refused('standard', 'Yandex Standart'),
          {
            'provider': 'bts',
            'method': null,
            'label': 'BTS pochta',
            'available': false,
            'unavailable_reason': 'out_of_zone',
          },
        ],
      },
    );
  }
}

Cart _cart({int cashback = 60000}) => Cart.fromJson({
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
  'cashback': {'available': cashback, 'max_usable_pickup': 48600},
});

Address _address(
  int id, {
  String label = 'Uy',
  bool region = true,
  bool pin = true,
  bool isDefault = true,
}) => Address.fromJson({
  'id': id,
  'label': label,
  'text': 'Chilonzor 9',
  'region_code': region ? '10' : '',
  'city_code': region ? '1001' : '',
  'is_default': isDefault,
  'latitude': pin ? '41.285000' : null,
  'longitude': pin ? '69.204000' : null,
});

const _settings = PublicSettings({
  'payment_providers': ['click', 'payme'],
  'online_sales_enabled': true,
  'fulfilment_methods': ['delivery', 'pickup'],
  'delivery': {
    'providers': ['yandex', 'bts'],
  },
  'pickup_address': 'Toshkent, Bunyodkor 12',
  'reservation_minutes': 15,
});

/// Lets the debounced quote go out and land.
Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

Future<void> _pumpCheckout(
  WidgetTester tester,
  _FakeApi api, {
  required List<Address> Function() addresses,
  Cart? cart,
  PublicSettings settings = _settings,
  Address? formResult,
}) async {
  tester.view.physicalSize = const Size(390, 3200) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/checkout',
    routes: [
      GoRoute(path: '/checkout', builder: (_, _) => const CheckoutScreen()),
      GoRoute(
        path: '/checkout/address',
        builder: (context, s) => Scaffold(
          body: TextButton(
            onPressed: () => context.pop(formResult),
            child: Text('form ${s.uri.queryParameters['id']}'),
          ),
        ),
      ),
      GoRoute(
        path: '/pay/:id',
        builder: (_, s) => Text('pay ${s.pathParameters['id']}'),
      ),
      GoRoute(path: '/cart', builder: (_, _) => const Text('cart page')),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(_SignedIn.new),
        cartProvider.overrideWith(() => _FixedCart(cart ?? _cart())),
        checkoutApiProvider.overrideWithValue(api),
        addressesProvider.overrideWith((ref) async => addresses()),
        publicSettingsProvider.overrideWith((ref) async => settings),
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
  await settle(tester);
}

Finder _option(String key) =>
    find.bySemanticsIdentifier('checkout.option.$key');
Finder _inOption(String key, Finder f) =>
    find.descendant(of: _option(key), matching: f);
Finder get _place => find.bySemanticsIdentifier('checkout.place');

void main() {
  testWidgets('recalculates on every change and posts the last quote', (
    tester,
  ) async {
    final api = _FakeApi();
    await _pumpCheckout(
      tester,
      api,
      addresses: () => [
        _address(7, label: 'Eski', region: false, isDefault: false),
        _address(12),
      ],
      settings: const PublicSettings({
        'payment_providers': ['click', 'payme'],
        'online_sales_enabled': true,
        'fulfilment_methods': ['delivery', 'pickup'],
        'pickup_address': 'Toshkent, Bunyodkor 12',
        'reservation_minutes': 15,
      }),
    );

    // Delivery with the default usable address is preselected; one request.
    expect(api.calculations, [
      {
        'fulfilment': 'delivery',
        'address_id': 12,
        'cashback_to_use': 0,
        'with_options': true,
      },
    ]);
    expect(find.text('Yetkazib berish'), findsWidgets);
    expect(find.text('Narx va muddat manzilga qarab'), findsOneWidget);
    expect(find.text(formatMoney(833000)), findsOneWidget);
    expect(
      find.text('Viloyat va tuman ko‘rsatilmagan — manzilni tahrirlang'),
      findsOneWidget,
    );
    expect(find.text('Xaritada belgilangan'), findsNWidgets(2));
    // No options in the answer: no carrier section.
    expect(find.text('Yetkazib berish usuli'), findsNothing);

    // Cashback switch: asks with the whole available balance, shows the server's numbers.
    await tester.tap(find.byType(Switch));
    await settle(tester);
    expect(api.calculations.last['cashback_to_use'], 60000);
    expect(find.text('−${formatMoney(48600)}'), findsOneWidget);
    expect(find.text(formatMoney(784400)), findsOneWidget);

    // Pickup.
    await tester.tap(find.text('Do‘kondan olib ketish'));
    await settle(tester);
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

  testWidgets('a burst of changes makes one request', (tester) async {
    final api = _FakeApi();
    await _pumpCheckout(tester, api, addresses: () => [_address(12)]);
    expect(api.calculations, hasLength(1));
    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(Switch));
    await settle(tester);
    expect(api.calculations, hasLength(2));
    expect(api.calculations.last['cashback_to_use'], 60000);
  });

  testWidgets('without a usable address the checkout starts on pickup', (
    tester,
  ) async {
    final api = _FakeApi();
    await _pumpCheckout(
      tester,
      api,
      cart: _cart(cashback: 0),
      addresses: () => [_address(7, label: 'Eski', region: false)],
    );
    expect(api.calculations, [
      {'fulfilment': 'pickup', 'address_id': null, 'cashback_to_use': 0},
    ]);
    expect(find.text(formatMoney(808000)), findsWidgets);
  });

  testWidgets('an unknown provider is skipped: the order goes out with Uzum', (
    tester,
  ) async {
    final api = _FakeApi();
    await _pumpCheckout(
      tester,
      api,
      cart: _cart(cashback: 0),
      addresses: () => [_address(7, label: 'Eski', region: false)],
      settings: const PublicSettings({
        'payment_providers': ['octo', 'uzum'],
        'online_sales_enabled': true,
        'fulfilment_methods': ['delivery', 'pickup'],
        'pickup_address': 'Toshkent, Bunyodkor 12',
        'reservation_minutes': 15,
      }),
    );
    await tester.tap(find.textContaining('Buyurtma berish'));
    await tester.pumpAndSettle();
    expect(api.checkouts.single['payment_provider'], 'uzum');
    expect(find.text('pay 10248'), findsOneWidget);
  });

  testWidgets('only unknown providers: no online payment, nothing is placed', (
    tester,
  ) async {
    final api = _FakeApi();
    await _pumpCheckout(
      tester,
      api,
      cart: _cart(cashback: 0),
      addresses: () => [_address(7, label: 'Eski', region: false)],
      settings: const PublicSettings({
        'payment_providers': ['octo'],
        'online_sales_enabled': true,
        'fulfilment_methods': ['delivery', 'pickup'],
        'pickup_address': 'Toshkent, Bunyodkor 12',
        'reservation_minutes': 15,
      }),
    );
    expect(find.text('Onlayn to‘lov hozircha mavjud emas.'), findsOneWidget);
    await tester.tap(find.textContaining('Buyurtma berish'));
    await tester.pumpAndSettle();
    expect(api.checkouts, isEmpty);
  });

  testWidgets('lists the carrier options with labels, prices and windows', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final api = _FakeApi(answer: yandexAnswer);
    await _pumpCheckout(tester, api, addresses: () => [_address(12)]);

    expect(find.text('Yetkazib berish usuli'), findsOneWidget);
    expect(
      _inOption('yandex.standard', find.text('Yandex Standart')),
      findsOneWidget,
    );
    expect(
      _inOption('yandex.standard', find.text(formatMoney(40000))),
      findsOneWidget,
    );
    expect(
      _inOption('yandex.standard', find.textContaining('21:18–23:18')),
      findsOneWidget,
    );
    expect(
      _inOption('yandex.express', find.text(formatMoney(51000))),
      findsOneWidget,
    );
    expect(
      _inOption('yandex.express', find.textContaining('20:48–21:48')),
      findsOneWidget,
    );
    expect(_inOption('bts', find.text('BTS pochta')), findsOneWidget);
    expect(_inOption('bts', find.text(formatMoney(25000))), findsOneWidget);
    expect(
      tester
          .getSemantics(_option('yandex.standard'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    // Summary: the selected option under the fee, its total.
    expect(find.text('Yandex Standart'), findsNWidgets(2));
    expect(find.text(formatMoney(225000)), findsOneWidget);
    expect(
      find.text('Buyurtma berish · ${formatMoney(225000)}'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('tapping Express asks for it; placing sends its quote id', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final api = _FakeApi(answer: yandexAnswer);
    await _pumpCheckout(tester, api, addresses: () => [_address(12)]);

    await tester.tap(_option('yandex.express'));
    await tester.pump();
    // The pick shows at once; its numbers are being calculated.
    expect(
      tester.getSemantics(_option('yandex.express')).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(find.text('Hisoblanmoqda…'), findsNWidgets(2));
    await settle(tester);
    expect(api.calculations.last, {
      'fulfilment': 'delivery',
      'address_id': 12,
      'cashback_to_use': 0,
      'with_options': true,
      'delivery_provider': 'yandex',
      'delivery_method': 'express',
    });
    expect(find.text(formatMoney(236000)), findsOneWidget);
    expect(find.text('Yandex Ekspress'), findsNWidgets(2));

    await tester.tap(_place);
    await tester.pumpAndSettle();
    expect(api.checkouts.single, {
      'fulfilment': 'delivery',
      'address_id': 12,
      'payment_provider': 'click',
      'cashback_to_use': 0,
      'expected_total': 236000,
      'customer_note': '',
      'delivery_quote_id': '4847f532-59b0-47ab-a0f9-fab683dcef75',
    });
    expect(find.text('pay 10248'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('an address without a pin offers to pin it', (tester) async {
    final handle = tester.ensureSemantics();
    final api = _FakeApi(answer: yandexAnswer);
    var pinned = false;
    await _pumpCheckout(
      tester,
      api,
      addresses: () => [_address(13, pin: pinned)],
      formResult: _address(13),
    );

    expect(
      _inOption('yandex.standard', find.text('Mavjud emas')),
      findsOneWidget,
    );
    expect(
      _inOption(
        'yandex.express',
        find.text('Kuryer uchun manzil xaritada belgilanmagan.'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(_option('bts')).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      find.text('Xaritada belgilanmagan — kuryer uchun nuqta qo‘ying'),
      findsOneWidget,
    );
    final action = find.bySemanticsIdentifier(
      'checkout.option.yandex.standard.action',
    );
    expect(action, findsOneWidget);
    expect(find.text('Xaritada belgilash'), findsNWidgets(2));

    // The BTS window is unknown: its total is placed as it is.
    expect(find.text(formatMoney(210000)), findsOneWidget);

    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('form 13'), findsOneWidget);
    pinned = true;
    final before = api.calculations.length;
    await tester.tap(find.text('form 13'));
    await settle(tester);
    expect(api.calculations.length, before + 1);
    expect(find.text('Xaritada belgilangan'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('quote_expired with an identical re-quote places again once', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final api = _FakeApi(
      answer: yandexAnswer,
      onCheckout: (call, body) async {
        if (call == 1) {
          throw const ApiException(
            status: 409,
            code: 'quote_expired',
            message: 'Narx muddati tugadi',
          );
        }
        return 10248;
      },
    );
    await _pumpCheckout(tester, api, addresses: () => [_address(12)]);
    final quotes = api.calculations.length;

    await tester.tap(_place);
    await settle(tester);
    expect(api.calculations.length, quotes + 1);
    expect(api.calculations.last['delivery_provider'], 'yandex');
    expect(api.calculations.last['delivery_method'], 'standard');
    expect(api.checkouts, hasLength(2));
    expect(api.checkouts.map((b) => b['delivery_quote_id']).toSet(), {
      '7191dc8f-788d-4a1f-aa55-55ee83fdfb1a',
    });
    expect(api.keys.toSet(), hasLength(2));
    expect(find.text('pay 10248'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('quote_expired twice stops and asks', (tester) async {
    final handle = tester.ensureSemantics();
    final api = _FakeApi(
      answer: yandexAnswer,
      onCheckout: (call, body) async => throw const ApiException(
        status: 409,
        code: 'quote_expired',
        message: '',
      ),
    );
    await _pumpCheckout(tester, api, addresses: () => [_address(12)]);
    await tester.tap(_place);
    await settle(tester);
    expect(api.checkouts, hasLength(2));
    expect(find.bySemanticsIdentifier('checkout.notice'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a new delivery price shows a notice and needs a second tap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var raised = false;
    final api = _FakeApi(
      answer: (body) => raised
          ? withStandard(pinnedAnswer(), fee: 45000, total: 230000)
          : yandexAnswer(body),
      onCheckout: (call, body) async {
        if (call == 1) {
          raised = true;
          throw ApiException(
            status: 409,
            code: 'price_changed',
            message: 'Narx o‘zgardi',
            details: {
              'delivery_fee': 45000,
              'options': withStandard(
                pinnedAnswer(),
                fee: 45000,
                total: 230000,
              )['options'],
            },
          );
        }
        return 10248;
      },
    );
    await _pumpCheckout(tester, api, addresses: () => [_address(12)]);

    await tester.tap(_place);
    await settle(tester);
    expect(api.checkouts, hasLength(1));
    expect(
      find.text(deliveryPriceChangedText(40000, 45000, AppLanguage.uz)),
      findsOneWidget,
    );
    expect(find.text('Yangi narx bilan buyurtma berish'), findsOneWidget);
    expect(find.text(formatMoney(230000)), findsOneWidget);

    // The first tap confirms the new price; nothing is placed yet.
    await tester.tap(_place);
    await tester.pumpAndSettle();
    expect(api.checkouts, hasLength(1));
    expect(find.bySemanticsIdentifier('checkout.notice'), findsNothing);
    expect(
      find.text('Buyurtma berish · ${formatMoney(230000)}'),
      findsOneWidget,
    );

    await tester.tap(_place);
    await tester.pumpAndSettle();
    expect(api.checkouts, hasLength(2));
    expect(api.checkouts.last['expected_total'], 230000);
    expect(
      api.checkouts.last['delivery_quote_id'],
      '7191dc8f-788d-4a1f-aa55-55ee83fdfb1a',
    );
    expect(find.text('pay 10248'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('delivery_unavailable lists the refused options', (tester) async {
    final handle = tester.ensureSemantics();
    final api = _FakeApiRefusing();
    await _pumpCheckout(tester, api, addresses: () => [_address(12)]);
    expect(find.text('Yetkazib berish usuli'), findsOneWidget);
    expect(
      _inOption(
        'yandex.standard',
        find.text('Yetkazib berish xizmati hozir javob bermayapti.'),
      ),
      findsOneWidget,
    );
    expect(find.text('Hozir yetkazib bo‘lmaydi'), findsOneWidget);
    final retry = find.bySemanticsIdentifier(
      'checkout.option.yandex.standard.action',
    );
    expect(find.text('Qayta hisoblash'), findsOneWidget);
    expect(tester.widget<GdButton>(find.byType(GdButton)).onPressed, isNull);
    await tester.tap(retry);
    await settle(tester);
    expect(api.calls, 2);
    handle.dispose();
  });

  testWidgets('open_order_exists goes to the cart', (tester) async {
    final api = _FakeApi(
      onCheckout: (call, body) async => throw const ApiException(
        status: 409,
        code: 'open_order_exists',
        message: 'To‘lanmagan buyurtma bor',
        details: {'order_id': 5},
      ),
    );
    await _pumpCheckout(tester, api, addresses: () => [_address(12)]);
    await tester.tap(find.textContaining('Buyurtma berish'));
    await tester.pumpAndSettle();
    expect(find.text('cart page'), findsOneWidget);
  });
}
