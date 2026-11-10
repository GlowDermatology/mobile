import 'package:flutter/material.dart' hide Page;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/app/providers.dart';
import 'package:glow_derma/app/theme/gd_theme.dart';
import 'package:glow_derma/core/i18n/tr.dart';
import 'package:glow_derma/core/network/json.dart';
import 'package:glow_derma/core/network/page.dart';
import 'package:glow_derma/features/appointments/data/appointment_models.dart';
import 'package:glow_derma/features/appointments/data/appointments_api.dart';
import 'package:glow_derma/features/settings/data/public_settings.dart';
import 'package:go_router/go_router.dart';

Json specialistJson({
  int id = 1,
  String name = 'Nodira Rahimova',
  String role = 'dermatologist',
  String roleLabel = 'Dermatolog',
  List<Json>? services,
}) => {
  'id': id,
  'name': name,
  'role': role,
  'role_label': roleLabel,
  'photo_url': null,
  'bio': '',
  'qualifications': '',
  'experience_years': null,
  'location': {
    'id': 1,
    'name': 'Glow Derma klinikasi',
    'address': 'Toshkent, Chilonzor',
    'phone': '+998712000000',
    'latitude': null,
    'longitude': null,
  },
  'services':
      services ??
      [
        {
          'id': 1,
          'name': 'Dermatolog konsultatsiyasi',
          'short_name': 'Konsultatsiya',
          'duration_min': 30,
          'price': 150000,
        },
        {
          'id': 2,
          'name': 'Qayta ko‘rik',
          'short_name': 'Qayta ko‘rik',
          'duration_min': 20,
          'price': 100000,
        },
      ],
  'slot_step_min': 30,
};

/// A `slots/` answer for [date]; [free] are "HH:MM" start times.
Json slotsJson(
  String date, {
  String? start = '09:00',
  String? end = '12:00',
  List<String> free = const [],
  int duration = 30,
  int price = 150000,
}) => {
  'date': date,
  'duration_min': duration,
  'price': price,
  'slot_step_min': 30,
  'working_hours': start == null ? null : {'start': start, 'end': end},
  'slots': [
    for (final f in free)
      {'start': f, 'end': '', 'start_at': '${date}T$f:00+05:00'},
  ],
};

Json appointmentJson({
  int id = 41,
  String status = 'requested',
  String label = 'Tasdiqlanishi kutilmoqda',
  bool canCancel = true,
}) => {
  'id': id,
  'status': status,
  'status_label': label,
  'specialist': {
    'id': 1,
    'name': 'Nodira Rahimova',
    'role': 'dermatologist',
    'role_label': 'Dermatolog',
    'photo_url': null,
  },
  'service': {
    'id': 1,
    'name': 'Dermatolog konsultatsiyasi',
    'short_name': 'Konsultatsiya',
  },
  'location': {
    'name': 'Glow Derma klinikasi',
    'address': 'Toshkent, Chilonzor',
    'phone': '+998712000000',
  },
  'start': '2026-10-27T10:30:00+05:00',
  'end': '2026-10-27T11:00:00+05:00',
  'duration_min': 30,
  'price': 150000,
  'note': null,
  'requested_at': '2026-10-26T12:00:00+05:00',
  'confirmed_at': null,
  'cancelled_at': null,
  'cancelled_by': null,
  'can_cancel': canCancel,
};

/// In-memory [AppointmentsApi].
class FakeAppointmentsApi implements AppointmentsApi {
  FakeAppointmentsApi({
    List<Json>? specialists,
    Json Function(int specialistId, String date, int serviceId)? slots,
    Map<int, Json>? appointments,
  }) : _specialists = specialists ?? [specialistJson()],
       _slots = slots ?? ((_, date, _) => slotsJson(date, free: ['09:00'])),
       appointments = appointments ?? {41: appointmentJson()};

  final List<Json> _specialists;
  final Json Function(int, String, int) _slots;
  final Map<int, Json> appointments;
  final slotCalls = <String>[];
  final booked = <Map<String, Object?>>[];
  final cancelled = <int>[];
  Object? bookError;

  @override
  Future<List<Specialist>> specialists() async =>
      _specialists.map(Specialist.fromJson).toList();

  @override
  Future<Specialist> specialist(int id) async =>
      Specialist.fromJson(_specialists.firstWhere((s) => s['id'] == id));

  @override
  Future<List<ServiceInfo>> services() async => [
    ServiceInfo.fromJson(const {
      'id': 1,
      'name': 'Dermatolog konsultatsiyasi',
      'description': 'Teri holatini ko‘rik',
      'specialist_ids': [1],
    }),
  ];

  @override
  Future<SlotsDay> slots(
    int specialistId, {
    required String date,
    required int serviceId,
  }) async {
    slotCalls.add('$specialistId/$date/$serviceId');
    return SlotsDay.fromJson(_slots(specialistId, date, serviceId));
  }

  @override
  Future<Appointment> book({
    required int specialistId,
    required int serviceId,
    required String start,
    String? note,
    required String idempotencyKey,
  }) async {
    final e = bookError;
    if (e != null) throw e;
    booked.add({
      'specialist_id': specialistId,
      'service_id': serviceId,
      'start': start,
      'key': idempotencyKey,
    });
    appointments[77] = appointmentJson(id: 77);
    return Appointment.fromJson(appointments[77]!);
  }

  @override
  Future<Page<Appointment>> list(
    AppointmentScope scope, {
    int page = 1,
  }) async => Page(
    items: scope == AppointmentScope.upcoming
        ? appointments.values.map(Appointment.fromJson).toList()
        : const [],
    count: appointments.length,
    page: 1,
    pageCount: 1,
  );

  @override
  Future<Appointment> detail(int id) async =>
      Appointment.fromJson(appointments[id]!);

  @override
  Future<Appointment> cancel(
    int id, {
    String? reason,
    required String idempotencyKey,
  }) async {
    cancelled.add(id);
    appointments[id] = {
      ...appointments[id]!,
      'status': 'cancelled',
      'status_label': 'Bekor qilingan',
      'can_cancel': false,
    };
    return Appointment.fromJson(appointments[id]!);
  }
}

/// Pumps [initial] of a small router holding the appointments routes.
Future<GoRouter> pumpApp(
  WidgetTester tester,
  FakeAppointmentsApi api, {
  required String initial,
  required List<RouteBase> routes,
  double height = 844,
}) async {
  tester.view.physicalSize = Size(390, height) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: initial, routes: routes);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        languageProvider.overrideWith(_Uz.new),
        appointmentsApiProvider.overrideWithValue(api),
        publicSettingsProvider.overrideWith(
          (ref) async =>
              const PublicSettings({'booking_policy': '24 soat oldin'}),
        ),
      ],
      child: MaterialApp.router(
        theme: buildTheme(Brightness.light),
        locale: const Locale('uz'),
        supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
  return router;
}

/// Unmounts the app so cached providers cancel their timers.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

class _Uz extends LanguageController {
  @override
  AppLanguage build() => AppLanguage.uz;
}
