import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/app/providers.dart';
import 'package:glow_derma/core/network/api_exception.dart';
import 'package:glow_derma/features/auth/data/auth_api.dart';
import 'package:glow_derma/features/auth/data/auth_models.dart';
import 'package:glow_derma/features/profile/presentation/change_password_screen.dart';
import 'package:glow_derma/features/profile/presentation/delete_account_screen.dart';

import 'settings_screen_test.dart' show app, overrides, malika;

class FakeAuthApi implements AuthApi {
  final calls = <String>[];
  Object? error;

  @override
  Future<Me> changePassword({
    required String current,
    required String password,
    required String idempotencyKey,
  }) async {
    calls.add('password:$current:$password:${idempotencyKey.isNotEmpty}');
    if (error != null) throw error!;
    return malika;
  }

  @override
  Future<void> deleteAccount({String? password}) async {
    calls.add('delete:$password');
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('change password: client rules before any request', (
    tester,
  ) async {
    final api = FakeAuthApi();
    await tester.pumpWidget(
      app(const ChangePasswordScreen(), [
        ...overrides(signedIn: true),
        authApiProvider.overrideWithValue(api),
      ]),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Kamida 8 ta belgi; faqat raqamlardan iborat bo‘lmasin.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).last, '12345678');
    await tester.tap(find.text('Parolni saqlash'));
    await tester.pumpAndSettle();
    expect(find.text('Maydonni to‘ldiring.'), findsOneWidget);
    expect(
      find.text('Parol faqat raqamlardan iborat bo‘lmasin.'),
      findsOneWidget,
    );
    expect(api.calls, isEmpty);
  });

  testWidgets('change password: server field error shown inline', (
    tester,
  ) async {
    final api = FakeAuthApi()
      ..error = const ApiException(
        status: 400,
        code: 'validation_error',
        message: 'Maydonlarni tekshiring.',
        fieldErrors: {'current_password': 'Parol noto‘g‘ri.'},
      );
    await tester.pumpWidget(
      app(const ChangePasswordScreen(), [
        ...overrides(signedIn: true),
        authApiProvider.overrideWithValue(api),
      ]),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'wrong-one');
    await tester.enterText(find.byType(TextField).last, 'Glowderma-2027');
    await tester.tap(find.text('Parolni saqlash'));
    await tester.pumpAndSettle();
    expect(api.calls, ['password:wrong-one:Glowderma-2027:true']);
    expect(find.text('Parol noto‘g‘ri.'), findsOneWidget);
  });

  testWidgets('delete account: confirm, then wrong password inline', (
    tester,
  ) async {
    final api = FakeAuthApi()
      ..error = const ApiException(
        status: 400,
        code: 'validation_error',
        message: 'Maydonlarni tekshiring.',
        fieldErrors: {'password': 'Parol noto‘g‘ri.'},
      );
    await tester.pumpWidget(
      app(const DeleteAccountScreen(), [
        ...overrides(signedIn: true),
        authApiProvider.overrideWithValue(api),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hisobni o‘chirish'), findsNWidgets(2)); // header + button

    await tester.enterText(find.byType(TextField), 'nope-nope');
    await tester.tap(find.text('Hisobni o‘chirish').last);
    await tester.pumpAndSettle();
    expect(find.text('Hisobingizni o‘chirasizmi?'), findsOneWidget);
    await tester.tap(find.text('Ha, hisobni o‘chirish'));
    await tester.pumpAndSettle();
    expect(api.calls, ['delete:nope-nope']);
    expect(find.text('Parol noto‘g‘ri.'), findsOneWidget);
  });

  testWidgets('change password: save stays above the keyboard', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(const ChangePasswordScreen(), [
        ...overrides(signedIn: true),
        authApiProvider.overrideWithValue(FakeAuthApi()),
      ]),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('Parolni saqlash')).bottom,
      lessThanOrEqualTo(844 - 300),
    );
  });
}
