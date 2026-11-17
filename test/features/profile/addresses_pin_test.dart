import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/features/profile/data/addresses_api.dart';
import 'package:glow_derma/features/profile/presentation/addresses_screen.dart';

import 'settings_screen_test.dart' show app, overrides, tall;

void main() {
  Address a(int id, String label, {bool isDefault = false, bool pin = false}) =>
      Address.fromJson({
        'id': id,
        'label': label,
        'text': 'Chilonzor 12',
        'region_code': '',
        'city_code': '',
        'comment': '',
        'latitude': pin ? 41.285431 : null,
        'longitude': pin ? 69.203512 : null,
        'is_default': isDefault,
      });

  testWidgets('addresses: pin note under each address and the edit action', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(
      app(const AddressesScreen(), [
        ...overrides(signedIn: true),
        addressesProvider.overrideWith(
          (ref) async => [a(1, 'Ish'), a(2, 'Uy', isDefault: true, pin: true)],
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Xaritada belgilangan'), findsOneWidget);
    expect(
      find.text('Xaritada belgilanmagan — kuryer uchun nuqta qo‘ying'),
      findsOneWidget,
    );

    // "Ish" (no pin) is listed second.
    await tester.tap(find.byIcon(Icons.more_vert_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('Tahrirlash'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == 'addresses.edit',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Tahrirlash'));
    await tester.pumpAndSettle();
    expect(find.text('page /checkout/address?id=1'), findsOneWidget);
  });
}
