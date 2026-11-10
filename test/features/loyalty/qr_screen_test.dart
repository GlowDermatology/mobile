import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/core/format/money.dart';
import 'package:glow_derma/core/network/api_client.dart';
import 'package:glow_derma/core/network/api_exception.dart';
import 'package:glow_derma/core/network/page.dart';
import 'package:glow_derma/features/loyalty/data/cashback_summary.dart';
import 'package:glow_derma/features/loyalty/data/loyalty_api.dart';
import 'package:glow_derma/features/loyalty/data/loyalty_models.dart';
import 'package:glow_derma/features/loyalty/presentation/qr_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'harness.dart';

class _NoClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeLoyaltyApi extends LoyaltyApi {
  FakeLoyaltyApi({this.ledgerItems = const [], this.qrError})
    : super(_NoClient());
  final List<Map<String, dynamic>> ledgerItems;
  Object? qrError;
  int qrCalls = 0;

  @override
  Future<Page<LedgerItem>> ledger({int page = 1}) async => Page.fromJson({
    'count': ledgerItems.length,
    'page': 1,
    'page_size': 20,
    'page_count': 1,
    'results': ledgerItems,
  }, LedgerItem.fromJson);

  @override
  Future<QrToken> qr() async {
    qrCalls++;
    if (qrError != null) throw qrError!;
    return QrToken(
      token: 'GD1:token$qrCalls',
      expiresAt: null,
      ttlSeconds: 60,
      refreshInSeconds: 50,
    );
  }
}

class FakeEffects extends QrScreenEffects {
  int entered = 0, left = 0;
  @override
  Future<bool> enter() async {
    entered++;
    return true;
  }

  @override
  Future<void> leave() async => left++;
}

final _summary = CashbackSummary(const {
  'balance': 48600,
  'held': 0,
  'available': 48600,
  'tier': {'percent': '1.00', 'from': 0, 'to': 20000000},
  'next_tier': {
    'percent': '2.00',
    'from': 20000000,
    'remaining': 6420000,
    'progress': 0.679,
  },
  'tiers': [],
});

Map<String, dynamic> _ledger(int id, int amount, String source, String kind) =>
    {
      'id': id,
      'at': '2026-10-21T14:05:00+05:00',
      'kind': kind,
      'amount': amount,
      'balance_after': 0,
      'title': 'Title $id',
      'subtitle': 'Sub $id',
      'order_id': null,
      'source': source,
    };

/// Lets the test hide the screen like an inactive shell tab.
class _Tab extends StatefulWidget {
  const _Tab({super.key});
  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool visible = true;
  void set(bool v) => setState(() => visible = v);
  @override
  Widget build(BuildContext context) =>
      TickerMode(enabled: visible, child: const QrScreen());
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets(
    'shows the code, balance and ledger; hides it offstage and refetches when back',
    (tester) async {
      _tall(tester);
      final api = FakeLoyaltyApi(
        ledgerItems: [
          _ledger(1, 2310, 'store', 'credit'),
          _ledger(2, -20000, 'online', 'debit'),
        ],
      );
      final effects = FakeEffects();
      final tab = GlobalKey<_TabState>();
      await tester.pumpWidget(
        routerApp(_Tab(key: tab), [
          ...commonOverrides(),
          loyaltyApiProvider.overrideWithValue(api),
          qrScreenEffectsProvider.overrideWithValue(effects),
          cashbackSummaryProvider.overrideWith((ref) async => _summary),
        ]),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Mening QR kodim'), findsOneWidget);
      expect(find.text('Yorqinlik oshirildi'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Kod 50 soniyadan so‘ng yangilanadi'), findsOneWidget);
      expect(find.text(formatMoney(48600)), findsOneWidget);
      expect(find.text('1%'), findsOneWidget);
      expect(find.text('Cashback tarixi'), findsOneWidget);
      expect(find.text(formatSigned(2310)), findsOneWidget);
      expect(find.text(formatSigned(-20000)), findsOneWidget);
      expect(find.text('21-oktabr · Sub 1'), findsOneWidget);
      expect(effects.entered, 1);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Kod 49 soniyadan so‘ng yangilanadi'), findsOneWidget);

      tab.currentState!.set(false);
      await tester.pump();
      await tester.pump();
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Kod vaqtincha yashirildi'), findsOneWidget);
      expect(find.text('Yorqinlik oshirildi'), findsNothing);
      expect(effects.left, 1);

      tab.currentState!.set(true);
      await tester.pump();
      await tester.pump();
      expect(api.qrCalls, 2);
      expect(find.byType(QrImageView), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      expect(effects.left, 2);
    },
  );

  testWidgets('app pause hides the code; resume fetches a new one', (
    tester,
  ) async {
    _tall(tester);
    final api = FakeLoyaltyApi();
    await tester.pumpWidget(
      routerApp(const QrScreen(), [
        ...commonOverrides(),
        loyaltyApiProvider.overrideWithValue(api),
        qrScreenEffectsProvider.overrideWithValue(FakeEffects()),
        cashbackSummaryProvider.overrideWith((ref) async => _summary),
      ]),
    );
    await tester.pump();
    await tester.pump();
    expect(api.qrCalls, 1);
    expect(find.text('Hozircha cashback harakati yo‘q.'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(api.qrCalls, 2);
    expect(find.byType(QrImageView), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('phone_required opens the attach-phone screen', (tester) async {
    _tall(tester);
    final api = FakeLoyaltyApi(
      qrError: const ApiException(
        status: 409,
        code: 'phone_required',
        message: 'Telefon kerak',
      ),
    );
    await tester.pumpWidget(
      routerApp(const QrScreen(), [
        ...commonOverrides(),
        loyaltyApiProvider.overrideWithValue(api),
        qrScreenEffectsProvider.overrideWithValue(FakeEffects()),
        cashbackSummaryProvider.overrideWith((ref) async => _summary),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('page /settings/phone'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
