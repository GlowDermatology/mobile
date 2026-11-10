import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/core/format/dates.dart';
import 'package:glow_derma/core/i18n/tr.dart';
import 'package:glow_derma/core/widgets/gd_widgets.dart';
import 'package:glow_derma/features/appointments/application/booking_logic.dart';
import 'package:glow_derma/features/appointments/data/appointment_models.dart';
import 'package:glow_derma/features/appointments/presentation/appointment_widgets.dart';

import 'fakes.dart';

void main() {
  // Sunday 25 Oct 2026, 23:30 in Tashkent (18:30 UTC).
  final lateSunday = DateTime.parse('2026-10-25T23:30:00+05:00');
  // Monday 26 Oct 2026, 08:00 in Tashkent.
  final monday = DateTime.parse('2026-10-26T08:00:00+05:00');

  group('dateStrip', () {
    test('starts on the Tashkent day, whatever UTC says', () {
      final days = dateStrip(lateSunday);
      expect(days, hasLength(30));
      expect(isoDate(days.first), '2026-10-25');
      expect(isoDate(days[1]), '2026-10-26');
      expect(weekdayShort(days.first, AppLanguage.uz), 'Ya');
      expect(weekdayShort(days[1], AppLanguage.uz), 'Du');
    });

    test('crosses month ends and keeps consecutive dates', () {
      final days = dateStrip(monday);
      expect(isoDate(days.last), '2026-11-24');
      for (var i = 1; i < days.length; i++) {
        expect(days[i].difference(days[i - 1]).inDays, 1);
      }
      expect(dateStrip(monday, days: 7).map(isoDate).last, '2026-11-01');
    });
  });

  group('buildTimeGrid', () {
    test('working hours + step + free slots → enabled / taken chips', () {
      final day = SlotsDay.fromJson(
        slotsJson(
          '2026-10-27',
          start: '09:00',
          end: '12:00',
          free: ['09:00', '10:00', '10:30', '11:00'],
        ),
      );
      final grid = buildTimeGrid(day);
      expect(grid.map((c) => c.toString()).toList(), [
        '09:00',
        '09:30x',
        '10:00',
        '10:30',
        '11:00',
        '11:30x',
      ]);
      expect(grid[2].slot!.startAtRaw, '2026-10-27T10:00:00+05:00');
    });

    test('a start whose service would end after the hours is not offered', () {
      final day = SlotsDay.fromJson(
        slotsJson('2026-10-27', start: '09:00', end: '11:00', duration: 75),
      );
      expect(buildTimeGrid(day).map((c) => c.label), ['09:00', '09:30']);
    });

    test('not working → no chips; off-grid free slot is still shown', () {
      expect(
        buildTimeGrid(SlotsDay.fromJson(slotsJson('2026-10-27', start: null))),
        isEmpty,
      );
      final day = SlotsDay.fromJson(
        slotsJson('2026-10-27', start: '09:00', end: '10:00', free: ['09:15']),
      );
      expect(buildTimeGrid(day).map((c) => c.toString()), [
        '09:00x',
        '09:15',
        '09:30x',
      ]);
    });

    test('closed day', () {
      expect(
        SlotsDay.fromJson(slotsJson('2026-10-27', start: null)).closed,
        isTrue,
      );
      expect(SlotsDay.fromJson(slotsJson('2026-10-27')).closed, isTrue);
      expect(
        SlotsDay.fromJson(slotsJson('2026-10-27', free: ['09:00'])).closed,
        isFalse,
      );
    });
  });

  group('findNextSlot', () {
    test('scans day by day and stops at the first free time', () async {
      final asked = <String>[];
      final found = await findNextSlot(
        now: monday,
        fetch: (date) async {
          asked.add(date);
          return SlotsDay.fromJson(
            date == '2026-10-28'
                ? slotsJson(date, free: ['09:00', '09:30'])
                : slotsJson(date, start: null),
          );
        },
      );
      expect(asked, ['2026-10-26', '2026-10-27', '2026-10-28']);
      expect(found, DateTime.parse('2026-10-28T09:00:00+05:00'));
    });

    test('null after a booked week (7 days asked)', () async {
      var calls = 0;
      final found = await findNextSlot(
        now: monday,
        fetch: (date) async {
          calls++;
          return SlotsDay.fromJson(slotsJson(date));
        },
      );
      expect(found, isNull);
      expect(calls, 7);
    });
  });

  test('nextSlotLabel: today, tomorrow, later', () {
    expect(
      nextSlotLabel(
        DateTime.parse('2026-10-26T17:00:00+05:00'),
        monday,
        AppLanguage.uz,
      ),
      'Bugun, 17:00',
    );
    expect(
      nextSlotLabel(
        DateTime.parse('2026-10-27T09:00:00+05:00'),
        monday,
        AppLanguage.uz,
      ),
      'Ertaga, 09:00',
    );
    expect(
      nextSlotLabel(
        DateTime.parse('2026-11-02T09:00:00+05:00'),
        monday,
        AppLanguage.uz,
      ),
      'Du, 2-noyabr · 09:00',
    );
    expect(
      nextSlotLabel(
        DateTime.parse('2026-10-26T09:00:00+05:00'),
        lateSunday,
        AppLanguage.ru,
      ),
      'Завтра, 09:00',
    );
  });

  test('status tone mapping', () {
    expect(appointmentTone('requested'), GdTone.warning);
    expect(appointmentTone('confirmed'), GdTone.success);
    expect(appointmentTone('attended'), GdTone.success);
    expect(appointmentTone('rejected'), GdTone.danger);
    expect(appointmentTone('cancelled'), GdTone.neutral);
    expect(appointmentTone('something_new'), GdTone.neutral);
  });

  group('models', () {
    test('specialist: initials, min price, shortest service, filter', () {
      final nodira = Specialist.fromJson(specialistJson());
      final dilnoza = Specialist.fromJson(
        specialistJson(
          id: 3,
          name: 'Dilnoza Yusupova',
          role: 'cosmetologist',
          roleLabel: 'Kosmetolog',
        ),
      );
      expect(nodira.initials, 'NR');
      expect(nodira.minPrice, 100000);
      expect(nodira.shortestService!.id, 2);
      expect(nodira.location!.name, 'Glow Derma klinikasi');
      expect(servicesSummary(nodira), 'Konsultatsiya, Qayta ko‘rik');
      expect(
        filterSpecialists([
          nodira,
          dilnoza,
        ], SpecialistFilter.cosmetologist).single.id,
        3,
      );
      expect(
        filterSpecialists([nodira, dilnoza], SpecialistFilter.all),
        hasLength(2),
      );
      expect(
        Specialist.fromJson(specialistJson(services: [])).shortestService,
        isNull,
      );
    });

    test('appointment + time range', () {
      final a = Appointment.fromJson(appointmentJson());
      expect(a.specialist.id, 1);
      expect(a.serviceName, 'Dermatolog konsultatsiyasi');
      expect(a.canCancel, isTrue);
      expect(
        formatAppointmentTime(a, AppLanguage.uz),
        'Se, 27-oktabr · 10:30–11:00',
      );
    });
  });
}
