import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/core/format/dates.dart';
import 'package:glow_derma/core/i18n/tr.dart';
import 'package:glow_derma/core/network/api_exception.dart';
import 'package:glow_derma/features/appointments/application/booking_logic.dart';
import 'package:glow_derma/features/appointments/presentation/appointment_screen.dart';
import 'package:glow_derma/features/appointments/presentation/appointments_screen.dart';
import 'package:glow_derma/features/appointments/presentation/booking_screen.dart';
import 'package:glow_derma/features/appointments/presentation/specialists_screen.dart';
import 'package:go_router/go_router.dart';

import 'fakes.dart';

List<RouteBase> _routes() => [
  GoRoute(path: '/specialists', builder: (_, _) => const SpecialistsScreen()),
  GoRoute(
    path: '/specialists/:id/book',
    builder: (_, s) => BookingScreen(
      specialistId: int.parse(s.pathParameters['id']!),
      rescheduleFrom: int.tryParse(s.uri.queryParameters['reschedule'] ?? ''),
    ),
  ),
  GoRoute(path: '/appointments', builder: (_, _) => const AppointmentsScreen()),
  GoRoute(
    path: '/appointments/:id',
    builder: (_, s) => AppointmentScreen(
      id: int.parse(s.pathParameters['id']!),
      created: s.uri.queryParameters['created'] == '1',
    ),
  ),
  GoRoute(
    path: '/catalog',
    builder: (_, _) => const Scaffold(body: Text('CATALOG')),
  ),
];

void main() {
  final days = dateStrip(DateTime.now());
  final today = isoDate(days[0]);
  final tomorrow = isoDate(days[1]);

  testWidgets('specialists: cards, filter, next free time and busy week', (
    tester,
  ) async {
    final api = FakeAppointmentsApi(
      specialists: [
        specialistJson(),
        specialistJson(
          id: 4,
          name: 'Madina Sobirova',
          role: 'cosmetologist',
          roleLabel: 'Kosmetolog',
          services: [
            {
              'id': 5,
              'name': 'Massaj',
              'short_name': 'Massaj',
              'duration_min': 60,
              'price': 180000,
            },
          ],
        ),
      ],
      slots: (id, date, _) => id == 1 && date == tomorrow
          ? slotsJson(date, free: ['09:00'])
          : slotsJson(date, start: null),
    );
    await pumpApp(tester, api, initial: '/specialists', routes: _routes());
    await tester.pumpAndSettle();

    expect(find.text('Mutaxassislar'), findsOneWidget);
    expect(find.text('Nodira Rahimova'), findsOneWidget);
    expect(
      find.text('Dermatolog · Konsultatsiya, Qayta ko‘rik'),
      findsOneWidget,
    );
    expect(find.text('2 xizmat · 100 000 so‘mdan'), findsOneWidget);
    expect(find.text('Ertaga, 09:00'), findsOneWidget);
    expect(find.text('Bu hafta band'), findsOneWidget);
    // Nodira: shortest service (id 2) searched until the first hit.
    expect(api.slotCalls.where((c) => c.startsWith('1/')), [
      '1/$today/2',
      '1/$tomorrow/2',
    ]);
    expect(api.slotCalls.where((c) => c.startsWith('4/')), hasLength(7));

    await tester.ensureVisible(find.text('Kosmetologlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kosmetologlar'));
    await tester.pumpAndSettle();
    expect(find.text('Nodira Rahimova'), findsNothing);
    expect(find.text('Madina Sobirova'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'booking: closed day is skipped, taken times struck, books and opens the request',
    (tester) async {
      final api = FakeAppointmentsApi(
        slots: (_, date, _) => date == today
            ? slotsJson(date, start: null)
            : slotsJson(date, free: ['09:00', '10:00', '10:30', '11:00']),
      );
      final router = await pumpApp(
        tester,
        api,
        initial: '/specialists/1/book',
        routes: _routes(),
        height: 1100,
      );
      await tester.pumpAndSettle();

      expect(find.text('Qabulga yozilish'), findsOneWidget);
      expect(find.text('Dermatolog · Glow Derma klinikasi'), findsOneWidget);
      expect(find.text('30 daqiqa · Teri holatini ko‘rik'), findsOneWidget);
      expect(find.text('20 daqiqa'), findsOneWidget);
      // Today has no hours: the selection moved on to tomorrow.
      expect(find.text('09:30'), findsOneWidget);
      final struck = tester.widget<Text>(find.text('09:30'));
      expect(struck.style?.decoration, TextDecoration.lineThrough);
      expect(find.text('Vaqtni tanlang'), findsOneWidget);

      await tester.tap(find.text('10:30'));
      await tester.pump();
      final start = DateTime.parse('${tomorrow}T10:30:00+05:00');
      expect(
        find.text('${formatSlot(start, AppLanguage.uz)} · 30 daqiqa'),
        findsOneWidget,
      );

      await tester.tap(find.text('Bron qilish'));
      await tester.pumpAndSettle();
      expect(api.booked.single['start'], '${tomorrow}T10:30:00+05:00');
      expect(api.booked.single['service_id'], 1);
      expect(router.state.uri.toString(), '/appointments/77?created=1');
      expect(find.text('So‘rovingiz yuborildi'), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets('appointment: details, policy, cancel with confirmation', (
    tester,
  ) async {
    final api = FakeAppointmentsApi();
    await pumpApp(
      tester,
      api,
      initial: '/appointments/41',
      routes: _routes(),
      height: 1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('TASDIQLANISHI KUTILMOQDA'), findsOneWidget);
    expect(find.text('Se, 27-oktabr · 10:30–11:00'), findsOneWidget);
    expect(find.text('Toshkent, Chilonzor'), findsOneWidget);
    expect(
      find.text('Bekor qilish va ko‘chirish shartlari: 24 soat oldin'),
      findsOneWidget,
    );
    expect(find.text('Vaqtni o‘zgartirish'), findsOneWidget);
    expect(find.text('So‘rovingiz yuborildi'), findsNothing);

    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ha, bekor qilish'));
    await tester.pumpAndSettle();
    expect(api.cancelled, [41]);
    expect(find.text('BEKOR QILINGAN'), findsOneWidget);
    expect(find.text('Vaqtni o‘zgartirish'), findsNothing);
    await unmount(tester);
  });

  testWidgets('appointments list: upcoming card, empty past tab', (
    tester,
  ) async {
    final api = FakeAppointmentsApi();
    await pumpApp(tester, api, initial: '/appointments', routes: _routes());
    await tester.pumpAndSettle();
    expect(find.text('Mening qabullarim'), findsOneWidget);
    expect(find.text('Nodira Rahimova'), findsOneWidget);
    await tester.tap(find.text('O‘tgan'));
    await tester.pumpAndSettle();
    expect(find.text('O‘tgan qabullar yo‘q.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Mutaxassislar'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'booking: reschedule preselects the old service, cancels it after booking; slot_taken reloads',
    (tester) async {
      final api =
          FakeAppointmentsApi(
              slots: (_, date, _) => slotsJson(date, free: ['09:00', '10:00']),
            )
            ..appointments[41] = {
              ...appointmentJson(),
              'service': {
                'id': 2,
                'name': 'Qayta ko‘rik',
                'short_name': 'Qayta ko‘rik',
              },
            };
      final router = await pumpApp(
        tester,
        api,
        initial: '/specialists/1/book?reschedule=41',
        routes: _routes(),
        height: 1100,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Yangi vaqtni tanlang — eski qabul bekor qilinadi.'),
        findsOneWidget,
      );

      api.bookError = const ApiException(
        status: 409,
        code: 'slot_taken',
        message: 'Bu vaqt band bo‘lib qoldi. Boshqa vaqtni tanlang.',
      );
      await tester.tap(find.text('10:00'));
      await tester.pump();
      final callsBefore = api.slotCalls.length;
      await tester.tap(find.text('Bron qilish'));
      await tester.pumpAndSettle();
      expect(
        find.text('Bu vaqt band bo‘lib qoldi. Boshqa vaqtni tanlang.'),
        findsOneWidget,
      );
      expect(api.slotCalls.length, greaterThan(callsBefore));
      expect(find.text('Vaqtni tanlang'), findsOneWidget);

      api.bookError = null;
      await tester.tap(find.text('10:00'));
      await tester.pump();
      await tester.tap(find.text('Bron qilish'));
      await tester.pumpAndSettle();
      expect(api.booked.single['service_id'], 2);
      expect(api.cancelled, [41]);
      expect(router.state.uri.toString(), '/appointments/77?created=1');
      await unmount(tester);
    },
  );
}
