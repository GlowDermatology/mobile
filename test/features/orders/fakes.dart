import 'package:flutter/material.dart' hide Page;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/app/providers.dart';
import 'package:glow_derma/app/theme/gd_theme.dart';
import 'package:glow_derma/core/i18n/tr.dart';
import 'package:glow_derma/core/network/json.dart';
import 'package:glow_derma/core/network/page.dart';
import 'package:glow_derma/features/auth/application/session_controller.dart';
import 'package:glow_derma/features/cart/data/cart_models.dart';
import 'package:glow_derma/features/orders/data/order_models.dart';
import 'package:glow_derma/features/orders/data/orders_api.dart';
import 'package:glow_derma/features/settings/data/public_settings.dart';

/// Order №10248 of the contract (§2.8, §4.1), as `GET me/orders/10248/` answers it.
Json orderJson({
  int id = 10248,
  String status = 'handed_to_courier',
  String statusLabel = 'Kuryerga topshirildi',
  String paymentStatus = 'paid',
  String provider = 'click',
  bool inProgress = false,
  String? inProgressLabel,
  String? payBy,
  bool pay = false,
  bool cancel = false,
  bool reorder = true,
  int earned = 5680,
  String earnedState = 'credited',
  Json? cancellation,
  List<Json>? progress,
  List<Json>? timeline,
}) => {
  'id': id,
  'created_at': '2026-10-23T14:02:00+05:00',
  'status': status,
  'status_label': statusLabel,
  'fulfilment': 'delivery',
  'total': 784400,
  'item_count': 3,
  'preview_images': ['https://example.com/a.webp', null],
  'payment': {
    'status': paymentStatus,
    'status_label': 'To‘langan',
    'provider': provider,
    'amount': 784400,
    'confirmed_at': paymentStatus == 'paid'
        ? '2026-10-23T14:05:00+05:00'
        : null,
    'in_progress': inProgress,
    'in_progress_label': inProgressLabel,
  },
  'pay_by': payBy,
  'tracking_number': '48213907',
  'fulfilment_label': 'Yetkazib berish',
  'items': [
    {
      'product_id': 4,
      'name': 'Seramidli namlantiruvchi krem',
      'image_url': null,
      'quantity': 1,
      'unit_price': 312000,
      'promo': false,
      'line_total': 312000,
    },
    {
      'product_id': 5,
      'name': 'Yumshoq tozalovchi ko‘pik',
      'image_url': null,
      'quantity': 2,
      'unit_price': 128000,
      'promo': false,
      'line_total': 256000,
    },
    {
      'product_id': 2,
      'name': 'Quyoshdan himoya kremi SPF 50',
      'image_url': null,
      'quantity': 1,
      'unit_price': 240000,
      'promo': true,
      'line_total': 240000,
    },
  ],
  'items_subtotal': 808000,
  'promo_subtotal': 240000,
  'delivery_fee': 25000,
  'cashback_used': 48600,
  'address': 'Toshkent, Chilonzor tumani, 9-kvartal, 12-uy, 45-xonadon',
  'address_comment': '3-podyezd',
  'pickup_address': null,
  'customer_note': null,
  'refund': null,
  'shipment': {
    'carrier': 'BTS',
    'tracking_number': '48213907',
    'tracking_url': null,
  },
  'cashback': {'used': 48600, 'earned': earned, 'earned_state': earnedState},
  'cancellation': cancellation,
  'progress':
      progress ??
      [
        {
          'step': 'placed',
          'label': 'Buyurtma berildi',
          'state': 'done',
          'at': '2026-10-23T14:02:00+05:00',
        },
        {
          'step': 'paid',
          'label': 'To‘lov qabul qilindi',
          'state': 'done',
          'at': '2026-10-23T14:05:00+05:00',
        },
        {
          'step': 'with_courier',
          'label': 'Kuryerda',
          'state': 'done',
          'at': '2026-10-23T16:40:00+05:00',
        },
        {
          'step': 'delivered',
          'label': 'Yetkazildi',
          'state': 'current',
          'at': null,
        },
      ],
  'timeline':
      timeline ??
      [
        {
          'type': 'handed_to_courier',
          'at': '2026-10-23T16:40:00+05:00',
          'title': 'Kuryerga topshirildi',
          'subtitle': 'BTS',
        },
        {
          'type': 'shipment_created',
          'at': '2026-10-23T14:06:00+05:00',
          'title': 'Yetkazib berish rasmiylashtirildi',
          'subtitle': 'BTS kuzatuv raqami: 48213907',
        },
        {
          'type': 'payment_confirmed',
          'at': '2026-10-23T14:05:00+05:00',
          'title': 'To‘lov qabul qilindi',
          'subtitle': 'Click orqali · cashback +5 680 so‘m',
        },
        {
          'type': 'order_created',
          'at': '2026-10-23T14:02:00+05:00',
          'title': 'Buyurtma berildi',
          'subtitle': '3 ta mahsulot · 784 400 so‘m',
        },
      ],
  'actions': {'pay': pay, 'cancel': cancel, 'reorder': reorder},
};

/// An order awaiting payment with [left] until `pay_by` (from the real clock).
Json awaitingJson({
  Duration left = const Duration(minutes: 14, seconds: 37),
  bool pay = true,
  bool inProgress = false,
  String provider = 'click',
}) => orderJson(
  status: 'awaiting_payment',
  statusLabel: 'To‘lov kutilmoqda',
  paymentStatus: 'pending',
  provider: provider,
  inProgress: inProgress,
  inProgressLabel: inProgress ? 'To‘lov tekshirilmoqda' : null,
  payBy: DateTime.now().add(left).toUtc().toIso8601String(),
  pay: pay,
  cancel: true,
  reorder: false,
  earned: 0,
  earnedState: 'none',
  progress: [
    {
      'step': 'placed',
      'label': 'Buyurtma berildi',
      'state': 'done',
      'at': '2026-10-23T14:02:00+05:00',
    },
    {
      'step': 'paid',
      'label': 'To‘lov qabul qilindi',
      'state': 'current',
      'at': null,
    },
    {
      'step': 'with_courier',
      'label': 'Kuryerda',
      'state': 'upcoming',
      'at': null,
    },
    {
      'step': 'delivered',
      'label': 'Yetkazildi',
      'state': 'upcoming',
      'at': null,
    },
  ],
  timeline: [
    {
      'type': 'order_created',
      'at': '2026-10-23T14:02:00+05:00',
      'title': 'Buyurtma berildi',
      'subtitle': '3 ta mahsulot · 784 400 so‘m',
    },
  ],
);

OrderDetail detail(Json j) => OrderDetail.fromJson(j);

/// In-memory [OrdersApi].
class FakeOrdersApi implements OrdersApi {
  FakeOrdersApi({this.details = const {}, this.pages = const {}});

  final Map<int, OrderDetail> details;

  /// scope → pages (1-based list index + 1).
  final Map<OrderScope, List<Page<OrderSummary>>> pages;
  final listCalls = <(OrderScope, int)>[];
  Object? listError;
  final cancelled = <int>[];

  @override
  Future<Page<OrderSummary>> list(OrderScope scope, {int page = 1}) async {
    listCalls.add((scope, page));
    final e = listError;
    if (e != null) throw e;
    return pages[scope]![page - 1];
  }

  @override
  Future<OrderDetail> detail(int id) async => details[id]!;

  /// Thrown by [pay] when set (e.g. a 409 `payment_in_progress`).
  Object? payError;
  final payCalls = <(String?, String)>[];

  @override
  Future<PayResult> pay(
    int id,
    String? provider, {
    required String idempotencyKey,
  }) async {
    payCalls.add((provider, idempotencyKey));
    final e = payError;
    if (e != null) throw e;
    return PayResult(
      orderId: id,
      provider: provider ?? 'click',
      amount: 0,
      payBy: null,
      webUrl: 'https://example.com/pay',
    );
  }

  @override
  Future<OrderDetail> cancel(int id, {required String idempotencyKey}) async {
    cancelled.add(id);
    return details[id]!;
  }

  @override
  Future<Cart> reorder(int id, {required String idempotencyKey}) async =>
      Cart.fromJson(const {});

  @override
  Future<void> simulatePayment(
    int id, {
    String outcome = 'success',
    String? provider,
  }) async {}
}

Page<OrderSummary> summaryPage(
  List<int> ids, {
  required int page,
  required int pageCount,
}) => Page(
  items: [for (final id in ids) OrderSummary.fromJson(orderJson(id: id))],
  count: pageCount * 10,
  page: page,
  pageCount: pageCount,
);

class _Uz extends LanguageController {
  @override
  AppLanguage build() => AppLanguage.uz;
}

class _SignedIn extends SessionController {
  @override
  AuthState build() => const AuthState(signedIn: true);
}

/// Pumps [screen] on a 390-wide phone; [height] > 844 shows long pages whole.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen,
  FakeOrdersApi api, {
  double height = 844,
}) async {
  tester.view.physicalSize = Size(390, height) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(_SignedIn.new),
        languageProvider.overrideWith(_Uz.new),
        ordersApiProvider.overrideWithValue(api),
        publicSettingsProvider.overrideWith(
          (ref) async => const PublicSettings({
            'payment_providers': ['click', 'payme'],
            'online_sales_enabled': true,
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
        home: screen,
      ),
    ),
  );
}
