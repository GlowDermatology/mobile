import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/core/network/api_exception.dart';
import 'package:glow_derma/features/checkout/presentation/payment_screen.dart';
import 'package:glow_derma/features/orders/data/order_models.dart';
import 'package:glow_derma/features/orders/presentation/order_detail_screen.dart';
import 'package:glow_derma/features/orders/presentation/order_success_screen.dart';
import 'package:glow_derma/features/orders/presentation/orders_screen.dart';

import 'fakes.dart';

void main() {
  testWidgets('order detail: status, stepper, items, totals and reorder', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const OrderDetailScreen(orderId: 10248),
      FakeOrdersApi(details: {10248: detail(orderJson())}),
      height: 2000,
    );
    await tester.pumpAndSettle();

    expect(find.text('Buyurtma №10248'), findsOneWidget);
    expect(find.text('KURYERGA TOPSHIRILDI'), findsOneWidget);
    expect(find.text('BTS · 48213907'), findsOneWidget);
    expect(find.text('Kuryerda'), findsOneWidget);
    expect(find.text('BTS tasdiqlagach yangilanadi'), findsOneWidget);
    expect(find.text('Seramidli namlantiruvchi krem'), findsOneWidget);
    expect(find.text('1 × 240\u00a0000\u00a0so‘m · Aksiya'), findsOneWidget);
    expect(find.text('Cashback chegirmasi'), findsOneWidget);
    expect(find.text('−48\u00a0600\u00a0so‘m'), findsOneWidget);
    expect(find.text('To‘landi · Click'), findsOneWidget);
    expect(find.text('784\u00a0400\u00a0so‘m'), findsOneWidget);
    expect(find.text('+5\u00a0680\u00a0so‘m'), findsOneWidget);
    expect(find.text('Qayta buyurtma berish'), findsOneWidget);
    expect(find.text('Buyurtmani bekor qilish'), findsNothing);
  });

  testWidgets('order detail: unpaid order offers pay and cancel', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const OrderDetailScreen(orderId: 10248),
      FakeOrdersApi(details: {10248: detail(awaitingJson())}),
      height: 2000,
    );
    await tester.pumpAndSettle();
    expect(find.text('To‘lanadi'), findsOneWidget);
    expect(find.text('To‘lash'), findsOneWidget);
    expect(find.text('Buyurtmani bekor qilish'), findsOneWidget);
    expect(find.text('Qayta buyurtma berish'), findsNothing);
  });

  testWidgets('success screen', (tester) async {
    await pumpScreen(
      tester,
      const OrderSuccessScreen(orderId: 10248),
      FakeOrdersApi(
        details: {
          10248: detail(
            orderJson(status: 'processing', statusLabel: 'Jarayonda'),
          ),
        },
      ),
      height: 1400,
    );
    await tester.pumpAndSettle();
    expect(find.text('Buyurtmangiz qabul qilindi'), findsOneWidget);
    expect(find.text('JARAYONDA'), findsOneWidget);
    expect(find.text('To‘landi · Click'), findsOneWidget);
    expect(find.text('Cashback ishlatildi'), findsOneWidget);
    expect(find.text('Yetkazib berish'), findsOneWidget);
    expect(
      find.textContaining('cashback hisobingizga tushdi', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Buyurtmani kuzatish'), findsOneWidget);
    expect(find.text('Katalogga qaytish'), findsOneWidget);
  });

  testWidgets('success screen without earned cashback hides the box', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const OrderSuccessScreen(orderId: 10248),
      FakeOrdersApi(
        details: {
          10248: detail(
            orderJson(status: 'processing', earned: 0, earnedState: 'none'),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('cashback hisobingizga tushdi', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('payment screen: countdown, providers and the pay button', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const PaymentScreen(orderId: 10248),
      FakeOrdersApi(details: {10248: detail(awaitingJson())}),
      height: 1400,
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Mahsulotlar siz uchun band'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^1[34]:\d\d$')), findsOneWidget);
    expect(find.text('Click'), findsOneWidget);
    expect(find.text('Payme'), findsOneWidget);
    expect(find.text('Naqd pul'), findsOneWidget);
    expect(find.text('Click orqali to‘lash'), findsOneWidget);
    expect(find.text('Buyurtmani bekor qilish'), findsOneWidget);

    await tester.tap(find.text('Payme'));
    await tester.pump();
    expect(find.text('Payme orqali to‘lash'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'payment screen: payment_in_progress on a switch reverts the radio',
    (tester) async {
      final api = FakeOrdersApi(details: {10248: detail(awaitingJson())})
        ..payError = const ApiException(
          status: 409,
          code: 'payment_in_progress',
          message: 'To‘lov Click ilovasida jarayonda. Uni yakunlang yoki biroz kuting.',
          details: {'provider': 'click', 'order_id': 10248},
        );
      await pumpScreen(
        tester,
        const PaymentScreen(orderId: 10248),
        api,
        height: 1400,
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Payme'));
      await tester.pump();
      await tester.tap(find.text('Payme orqali to‘lash'));
      await tester.pump();
      await tester.pump();
      expect(api.payCalls.single.$1, 'payme');
      expect(find.text('Click orqali to‘lash'), findsOneWidget);
      expect(
        find.text(
          'To‘lov Click ilovasida jarayonda. Uni yakunlang yoki biroz kuting.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('payment screen: in progress replaces the countdown', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const PaymentScreen(orderId: 10248),
      FakeOrdersApi(details: {10248: detail(awaitingJson(inProgress: true))}),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('To‘lov tekshirilmoqda'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^1[34]:\d\d$')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('payment screen: expired order offers reorder', (tester) async {
    await pumpScreen(
      tester,
      const PaymentScreen(orderId: 10248),
      FakeOrdersApi(
        details: {
          10248: detail(
            awaitingJson(left: const Duration(minutes: -1), pay: false),
          ),
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('To‘lov muddati tugadi'), findsOneWidget);
    expect(find.text('Qayta buyurtma'), findsOneWidget);
    expect(find.text('Buyurtmalar'), findsOneWidget);
    expect(find.textContaining('orqali to‘lash'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('orders list renders cards and switches scope', (tester) async {
    final api = FakeOrdersApi(
      pages: {
        OrderScope.all: [
          summaryPage([10248, 10247], page: 1, pageCount: 1),
        ],
        OrderScope.cancelled: [summaryPage([], page: 1, pageCount: 1)],
      },
    );
    await pumpScreen(tester, const OrdersScreen(), api);
    await tester.pumpAndSettle();
    expect(find.text('№10248'), findsOneWidget);
    expect(find.text('№10247'), findsOneWidget);
    expect(find.text('Hammasi'), findsOneWidget);

    await tester.ensureVisible(find.text('Bekor qilingan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bekor qilingan'));
    await tester.pumpAndSettle();
    expect(find.text('Hozircha buyurtma yo‘q'), findsOneWidget);
    expect(api.listCalls.last, (OrderScope.cancelled, 1));
  });
}
