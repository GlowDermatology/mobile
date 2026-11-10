import 'package:flutter/material.dart' hide Page;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:glow_derma/app/providers.dart';
import 'package:glow_derma/app/theme/gd_theme.dart';
import 'package:glow_derma/core/i18n/tr.dart';
import 'package:glow_derma/core/network/api_exception.dart';
import 'package:glow_derma/core/network/page.dart';
import 'package:glow_derma/features/auth/application/session_controller.dart';
import 'package:glow_derma/features/cart/application/cart_controller.dart';
import 'package:glow_derma/features/cart/data/cart_models.dart';
import 'package:glow_derma/features/catalog/data/catalog_api.dart';
import 'package:glow_derma/features/catalog/data/catalog_models.dart';
import 'package:glow_derma/features/notifications/data/unread_count.dart';
import 'package:glow_derma/features/settings/data/public_settings.dart';

import 'catalog_models_test.dart' show cardJson;

/// In-memory catalog: [pages] keyed by page number.
class FakeCatalogApi implements CatalogApi {
  FakeCatalogApi({
    this.pages = const {},
    this.failPage,
    this.detail,
    this.bannerList = const [],
    this.categoryList = const [],
  });

  final List<CatalogBanner> bannerList;
  final List<CatalogCategory> categoryList;

  final Map<int, Page<ProductCard>> pages;
  int? failPage;
  Page<ProductCard>? Function(ProductQuery query, int page)? pagesFor;
  final ProductDetail? detail;
  final calls = <(ProductQuery, int)>[];

  @override
  Future<List<CatalogBanner>> banners() async => bannerList;

  @override
  Future<List<CatalogCategory>> categories() async => categoryList;

  @override
  Future<Page<ProductCard>> products(ProductQuery query, {int page = 1}) async {
    calls.add((query, page));
    if (page == failPage) {
      throw const ApiException(
        status: 500,
        code: 'server_error',
        message: 'Xato',
      );
    }
    return pagesFor?.call(query, page) ??
        pages[page] ??
        const Page(items: [], count: 0, page: 1, pageCount: 1);
  }

  @override
  Future<ProductDetail> product(int id) async =>
      detail ??
      (throw const ApiException(
        status: 404,
        code: 'not_found',
        message: 'Topilmadi',
      ));
}

Page<ProductCard> pageOf(
  List<int> ids, {
  required int page,
  required int pageCount,
  int? count,
}) => Page(
  items: [for (final id in ids) ProductCard.fromJson(cardJson(id: id))],
  count: count ?? ids.length,
  page: page,
  pageCount: pageCount,
);

class FakeLanguage extends LanguageController {
  @override
  AppLanguage build() => AppLanguage.uz;
}

class FakeSession extends SessionController {
  FakeSession(this._signedIn);
  final bool _signedIn;
  @override
  AuthState build() => AuthState(signedIn: _signedIn);
}

class FakeCart extends CartController {
  FakeCart(this.cart);
  final Cart cart;
  final calls = <(int, int)>[];

  @override
  Future<Cart> build() async => cart;

  @override
  Future<Cart> setQuantity(int productId, int quantity) async {
    calls.add((productId, quantity));
    final next = (state.value ?? cart).withLineQuantity(productId, quantity);
    state = AsyncData(next);
    return next;
  }
}

Cart cartWith(int productId, int quantity, {bool maxReached = false}) =>
    Cart.fromJson({
      'items': [
        {
          'product_id': productId,
          'name': 'Serum',
          'volume': '30 ml',
          'main_image_url': null,
          'unit_price': 185000,
          'promo': false,
          'quantity': quantity,
          'line_total': 185000 * quantity,
          'available': 12,
          'max_quantity': 10,
          'max_reached': maxReached,
          'status': 'ok',
          'price_changed': false,
          'previous_price': null,
        },
      ],
      'item_count': 1,
      'quantity_total': quantity,
      'items_subtotal': 185000 * quantity,
      'promo_subtotal': 0,
      'has_problems': false,
      'cashback': {'available': 0, 'max_usable_pickup': 0},
      'last_change': null,
    });

List<Override> baseOverrides({
  bool signedIn = true,
  Cart cart = Cart.empty,
  bool salesEnabled = true,
  CatalogApi? api,
  int unread = 0,
}) => [
  languageProvider.overrideWith(FakeLanguage.new),
  sessionProvider.overrideWith(() => FakeSession(signedIn)),
  cartProvider.overrideWith(() => FakeCart(cart)),
  publicSettingsProvider.overrideWith(
    (ref) async => PublicSettings({'online_sales_enabled': salesEnabled}),
  ),
  unreadCountProvider.overrideWith(() => FakeUnread(unread)),
  if (api != null) catalogApiProvider.overrideWithValue(api),
];

Widget testApp(Widget child, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: buildTheme(Brightness.light),
    locale: const Locale('uz'),
    supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  ),
);

class FakeUnread extends UnreadCountController {
  FakeUnread(this.value);
  final int value;
  @override
  int build() => value;
}
