import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/app/theme/gd_theme.dart';
import 'package:glow_derma/core/format/geo.dart';
import 'package:glow_derma/core/network/api_client.dart';
import 'package:glow_derma/core/network/api_exception.dart';
import 'package:glow_derma/features/checkout/presentation/address_form_screen.dart';
import 'package:glow_derma/features/profile/data/addresses_api.dart';
import 'package:glow_derma/features/profile/presentation/address_map_picker.dart';
import 'package:go_router/go_router.dart';

class _NoClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeAddressesApi extends AddressesApi {
  FakeAddressesApi({this.error}) : super(_NoClient());
  Object? error;
  final updates = <(int, Map<String, Object?>)>[];
  final creates = <Map<String, Object?>>[];

  Address _saved(int id, Map<String, Object?> f) => Address.fromJson({
    'id': id,
    'label': f['label'] ?? '',
    'text': f['text'] ?? '',
    'region_code': f['region_code'] ?? '',
    'city_code': f['city_code'] ?? '',
    'comment': f['comment'] ?? '',
    'latitude': f['latitude'],
    'longitude': f['longitude'],
    'is_default': false,
  });

  @override
  Future<Address> update(int id, Map<String, Object?> fields) async {
    updates.add((id, fields));
    if (error != null) throw error!;
    return _saved(id, fields);
  }

  @override
  Future<Address> create({
    required String text,
    required String regionCode,
    required String cityCode,
    String label = '',
    String comment = '',
    bool isDefault = false,
    GeoPin? pin,
    required String idempotencyKey,
  }) async {
    final f = {
      'label': label,
      'text': text,
      'region_code': regionCode,
      'city_code': cityCode,
      'comment': comment,
      ...pinFields(pin),
    };
    creates.add(f);
    if (error != null) throw error!;
    return _saved(99, f);
  }
}

class FakeLocator extends DeviceLocator {
  const FakeLocator(this.result);
  final Object result;
  @override
  Future<GeoPin> locate() async {
    final r = result;
    if (r is GeoPin) return r;
    throw r;
  }
}

final saved = Address.fromJson({
  'id': 7,
  'label': 'Uy',
  'text': 'Chilonzor 9-kvartal, 12-uy',
  'region_code': '10',
  'city_code': '1001',
  'comment': '3-podyezd',
  'latitude': 41.285431,
  'longitude': 69.203512,
  'is_default': true,
});

final tashkent = Region.fromJson({
  'code': '10',
  'name': 'Toshkent shahri',
  'cities': [
    {'code': '1001', 'name': 'Chilonzor'},
  ],
});

/// Pushes the form from a home page and records what it pops.
class Harness {
  Object? popped;
  bool returned = false;

  Widget build(String location, List<Override> overrides) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  popped = await context.push<Object?>(location);
                  returned = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/checkout/address',
          builder: (_, s) => AddressFormScreen(
            addressId: int.tryParse(s.uri.queryParameters['id'] ?? ''),
          ),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        addressMapTilesProvider.overrideWithValue(false),
        ...overrides,
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: buildTheme(Brightness.light),
        locale: const Locale('uz'),
        supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<Harness> open(
  WidgetTester tester, {
  required String location,
  required FakeAddressesApi api,
  List<Region> regions = const [],
  List<Address> addresses = const [],
  DeviceLocator locator = const FakeLocator(LocateFailure(denied: false)),
}) async {
  tall(tester);
  final h = Harness();
  await tester.pumpWidget(
    h.build(location, [
      addressesApiProvider.overrideWithValue(api),
      addressesProvider.overrideWith((ref) async => addresses),
      regionsProvider.overrideWith((ref) async => regions),
      deviceLocatorProvider.overrideWithValue(locator),
    ]),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return h;
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.text('Saqlash'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('edit: prefills the address and PATCHes it with the pin', (
    tester,
  ) async {
    final api = FakeAddressesApi();
    final h = await open(
      tester,
      location: '/checkout/address?id=7',
      api: api,
      regions: [tashkent],
      addresses: [saved],
    );

    expect(find.text('Manzilni tahrirlash'), findsOneWidget);
    expect(find.text('Chilonzor 9-kvartal, 12-uy'), findsOneWidget);
    expect(find.text('3-podyezd'), findsOneWidget);
    expect(find.text('Toshkent shahri'), findsOneWidget);
    expect(find.text('Chilonzor'), findsOneWidget);
    expect(find.text('Xaritadagi nuqta'), findsOneWidget);
    expect(find.text('Tanlangan nuqta: 41.285431, 69.203512'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    // The BTS-only hint is gone.
    expect(find.text('BTS kuryeri manzilingizga olib boradi'), findsNothing);

    await save(tester);
    expect(api.updates, hasLength(1));
    final (id, fields) = api.updates.single;
    expect(id, 7);
    expect(fields, {
      'label': 'Uy',
      'text': 'Chilonzor 9-kvartal, 12-uy',
      'region_code': '10',
      'city_code': '1001',
      'comment': '3-podyezd',
      'latitude': 41.285431,
      'longitude': 69.203512,
    });
    expect(api.creates, isEmpty);
    expect(h.returned, isTrue);
    expect(h.popped, isA<Address>());
    expect((h.popped! as Address).pin, (
      latitude: 41.285431,
      longitude: 69.203512,
    ));
  });

  testWidgets('edit: clearing the pin sends nulls', (tester) async {
    final api = FakeAddressesApi();
    await open(
      tester,
      location: '/checkout/address?id=7',
      api: api,
      regions: [tashkent],
      addresses: [saved],
    );

    await tester.tap(find.text('Pinni olib tashlash'));
    await tester.pumpAndSettle();
    expect(find.text('Pin qo‘yilmagan'), findsOneWidget);
    expect(find.text('Pinni olib tashlash'), findsNothing);

    await save(tester);
    final fields = api.updates.single.$2;
    expect(fields.containsKey('latitude'), isTrue);
    expect(fields['latitude'], isNull);
    expect(fields.containsKey('longitude'), isTrue);
    expect(fields['longitude'], isNull);
  });

  testWidgets('create without regions: tap on the map sets the pin', (
    tester,
  ) async {
    final api = FakeAddressesApi();
    final h = await open(tester, location: '/checkout/address', api: api);

    expect(find.text('Yangi manzil'), findsOneWidget);
    // No BTS regions: no region/city fields, and the pin is what counts.
    expect(find.byKey(const ValueKey('address.region')), findsNothing);
    expect(
      find.text('Kuryer yetkazib berishi uchun xaritada nuqta belgilang.'),
      findsOneWidget,
    );
    expect(find.text('Pin qo‘yilmagan'), findsOneWidget);

    final map = find.byType(FlutterMap);
    await tester.tapAt(tester.getCenter(map) + const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final chosen = find.textContaining('Tanlangan nuqta: 41.311100, 69.');
    expect(chosen, findsOneWidget);
    expect(find.byKey(const ValueKey('address.map.marker')), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).at(1),
      'Yunusobod 4-kvartal, 7-uy',
    );
    await save(tester);
    expect(api.creates, hasLength(1));
    final f = api.creates.single;
    expect(f['text'], 'Yunusobod 4-kvartal, 7-uy');
    expect(f['region_code'], '');
    expect(f['city_code'], '');
    expect(f['latitude'], 41.3111);
    expect(f['longitude'], greaterThan(tashkentCentre.longitude));
    expect(f['longitude'], lessThan(69.4));
    expect(h.popped, isA<Address>());
  });

  testWidgets('create: "Xarita markaziga qo‘yish" pins the centre', (
    tester,
  ) async {
    final api = FakeAddressesApi();
    await open(tester, location: '/checkout/address', api: api);

    await tester.tap(find.text('Xarita markaziga qo‘yish'));
    await tester.pumpAndSettle();
    expect(find.text('Tanlangan nuqta: 41.311100, 69.279700'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'Mirobod 15-uy');
    await save(tester);
    expect(api.creates.single['latitude'], 41.3111);
    expect(api.creates.single['longitude'], 69.2797);
  });

  testWidgets('a long press drags the marker', (tester) async {
    final api = FakeAddressesApi();
    await open(
      tester,
      location: '/checkout/address?id=7',
      api: api,
      regions: [tashkent],
      addresses: [saved],
    );
    final marker = find.byKey(const ValueKey('address.map.marker'));
    final gesture = await tester.startGesture(tester.getCenter(marker));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Tanlangan nuqta: 41.285431, 69.203512'), findsNothing);

    await save(tester);
    final fields = api.updates.single.$2;
    expect(fields['latitude'], greaterThan(41.285431));
    expect(fields['longitude'], closeTo(69.203512, 1e-5));
  });

  testWidgets('create with regions still requires region and city', (
    tester,
  ) async {
    final api = FakeAddressesApi();
    await open(
      tester,
      location: '/checkout/address',
      api: api,
      regions: [tashkent],
    );
    expect(
      find.text(
        'Xaritani bosing yoki belgini suring: kuryer aynan shu nuqtaga keladi.',
      ),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).at(1), 'Mirobod 15-uy');
    await save(tester);
    expect(api.creates, isEmpty);
  });

  testWidgets('latlng_pair shows a message under the map', (tester) async {
    final api = FakeAddressesApi(
      error: const ApiException(
        status: 400,
        code: 'validation_error',
        message: '',
        fieldErrors: {'latitude': 'Joylashuvni qayta tanlang.'},
        fieldCodes: {'latitude': 'latlng_pair'},
      ),
    );
    final h = await open(
      tester,
      location: '/checkout/address?id=7',
      api: api,
      regions: [tashkent],
      addresses: [saved],
    );
    await save(tester);
    expect(h.returned, isFalse);
    expect(find.text('Xaritadagi nuqtani qayta belgilang.'), findsOneWidget);

    // A new pin clears it.
    await tester.tap(find.text('Xarita markaziga qo‘yish'));
    await tester.pumpAndSettle();
    expect(find.text('Xaritadagi nuqtani qayta belgilang.'), findsNothing);
  });

  testWidgets('locate: the device position becomes the pin', (tester) async {
    final api = FakeAddressesApi();
    await open(
      tester,
      location: '/checkout/address',
      api: api,
      locator: const FakeLocator((latitude: 41.338, longitude: 69.334)),
    );
    await tester.tap(find.text('Joylashuvimni aniqlash'));
    await tester.pumpAndSettle();
    expect(find.text('Tanlangan nuqta: 41.338000, 69.334000'), findsOneWidget);
  });

  testWidgets('locate: denied and failed show a note', (tester) async {
    final api = FakeAddressesApi();
    await open(
      tester,
      location: '/checkout/address',
      api: api,
      locator: const FakeLocator(LocateFailure(denied: true)),
    );
    await tester.tap(find.text('Joylashuvimni aniqlash'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Joylashuvga ruxsat berilmadi.'),
      findsOneWidget,
    );
    expect(find.text('Pin qo‘yilmagan'), findsOneWidget);
  });

  testWidgets('locate: other failures', (tester) async {
    final api = FakeAddressesApi();
    await open(tester, location: '/checkout/address', api: api);
    await tester.tap(find.text('Joylashuvimni aniqlash'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Joylashuvni aniqlab bo‘lmadi. Nuqtani xaritada o‘zingiz belgilang.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('semantics identifiers of the map', (tester) async {
    final api = FakeAddressesApi();
    await open(
      tester,
      location: '/checkout/address?id=7',
      api: api,
      regions: [tashkent],
      addresses: [saved],
    );
    for (final id in [
      'address.map',
      'address.map.center',
      'address.map.locate',
      'address.map.clear',
      'address.save',
      'address.region',
      'address.city',
      'address.text',
      'address.comment',
    ]) {
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.identifier == id,
        ),
        findsOneWidget,
        reason: id,
      );
    }
  });
}
