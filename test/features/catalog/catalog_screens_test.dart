import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/features/catalog/data/catalog_models.dart';
import 'package:glow_derma/features/catalog/presentation/catalog_list_screen.dart';
import 'package:glow_derma/features/catalog/presentation/home_screen.dart';

import 'fakes.dart';

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  final categories = [
    CatalogCategory.fromJson({
      'slug': 'serums',
      'name': 'Serumlar',
      'image_url': null,
      'product_count': 20,
    }),
    CatalogCategory.fromJson({
      'slug': 'cleansing',
      'name': 'Tozalash',
      'image_url': null,
      'product_count': 53,
    }),
  ];

  testWidgets('home shows banner, search, categories and popular products', (
    tester,
  ) async {
    phone(tester);
    final api =
        FakeCatalogApi(
            bannerList: [
              CatalogBanner.fromJson({
                'id': 3,
                'title': 'Kuzgi namlik to‘plami',
                'image_url': null,
                'link': {
                  'kind': 'category',
                  'product_id': null,
                  'category': {'slug': 'moisturizing'},
                  'url': null,
                },
              }),
            ],
            categoryList: categories,
          )
          ..pagesFor = (q, page) => q.promo
              ? pageOf([7], page: 1, pageCount: 1)
              : pageOf([1, 7, 2], page: 1, pageCount: 1);

    await tester.pumpWidget(
      testApp(
        const HomeScreen(),
        baseOverrides(signedIn: true, api: api, unread: 2),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Glow Derma'), findsOneWidget);
    expect(find.text('Kuzgi namlik to‘plami'), findsOneWidget);
    expect(find.text('Mahsulot qidirish'), findsOneWidget);
    expect(find.text('Hammasi'), findsOneWidget);
    expect(find.text('Serumlar'), findsOneWidget);
    expect(find.text('Mashhur mahsulotlar'), findsOneWidget);
    expect(find.byKey(const ValueKey('home.unread_dot')), findsOneWidget);
    expect(find.text('Gialuron kislotali serum'), findsWidgets);
  });

  testWidgets('home without unread has no dot', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      testApp(
        const HomeScreen(),
        baseOverrides(signedIn: false, api: FakeCatalogApi()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home.unread_dot')), findsNothing);
  });

  testWidgets('list: category title, debounced search, short query hint', (
    tester,
  ) async {
    phone(tester);
    final api = FakeCatalogApi(categoryList: categories)
      ..pagesFor = (q, page) => pageOf([1, 2, 3, 4], page: 1, pageCount: 1);
    await tester.pumpWidget(
      testApp(
        const CatalogListScreen(category: 'serums'),
        baseOverrides(api: api),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Serumlar'), findsWidgets); // title + chip
    expect(find.text('4 ta mahsulot'), findsOneWidget);
    expect(api.calls.single.$1, const ProductQuery(category: 'serums'));

    await tester.enterText(find.byType(TextField), 'k');
    await tester.pump();
    expect(find.text('Kamida 2 ta harf kiriting.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'krem');
    await tester.pump(const Duration(milliseconds: 200));
    expect(api.calls.where((c) => c.$1.effectiveSearch == 'krem'), isEmpty);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(
      api.calls.last.$1,
      const ProductQuery(search: 'krem', category: 'serums'),
    );
  });

  testWidgets('list: empty result offers to clear filters', (tester) async {
    phone(tester);
    final api = FakeCatalogApi(categoryList: categories);
    await tester.pumpWidget(
      testApp(const CatalogListScreen(search: 'zzzz'), baseOverrides(api: api)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hech narsa topilmadi'), findsOneWidget);
    await tester.tap(find.text('Filtrlarni tozalash'));
    await tester.pumpAndSettle();
    expect(api.calls.last.$1, const ProductQuery());
  });

  testWidgets(
    'list: loads the next page when the first does not fill the screen',
    (tester) async {
      phone(tester);
      final api = FakeCatalogApi()
        ..pagesFor = (q, page) => page == 1
            ? pageOf([1, 2], page: 1, pageCount: 2, count: 3)
            : pageOf([3], page: 2, pageCount: 2, count: 3);
      await tester.pumpWidget(
        testApp(const CatalogListScreen(promo: true), baseOverrides(api: api)),
      );
      await tester.pumpAndSettle();
      expect(api.calls.map((c) => c.$2), [1, 2]);
      expect(api.calls.every((c) => c.$1.promo), isTrue);
    },
  );
}
