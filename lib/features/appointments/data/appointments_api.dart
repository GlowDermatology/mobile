import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../../core/network/page.dart';
import 'appointment_models.dart';

/// Specialists, services, free times and appointments (contract §2.11).
class AppointmentsApi {
  AppointmentsApi(this._api);
  final ApiClient _api;

  static const pageSize = 20;

  Future<List<Specialist>> specialists() async =>
      asJsonList(asJson(await _api.get('specialists/'))['results'])
          .map(Specialist.fromJson)
          .toList();

  Future<Specialist> specialist(int id) async =>
      Specialist.fromJson(asJson(await _api.get('specialists/$id/')));

  Future<List<ServiceInfo>> services() async =>
      asJsonList(asJson(await _api.get('services/'))['results'])
          .map(ServiceInfo.fromJson)
          .toList();

  /// Free start times of [specialistId] for [serviceId] on [date] ("YYYY-MM-DD").
  Future<SlotsDay> slots(
    int specialistId, {
    required String date,
    required int serviceId,
  }) async => SlotsDay.fromJson(
    asJson(
      await _api.get(
        'specialists/$specialistId/slots/',
        query: {'date': date, 'service_id': serviceId},
      ),
    ),
  );

  Future<Appointment> book({
    required int specialistId,
    required int serviceId,
    required String start,
    String? note,
    required String idempotencyKey,
  }) async => Appointment.fromJson(
    asJson(
      await _api.post(
        'appointments/',
        body: {
          'specialist_id': specialistId,
          'service_id': serviceId,
          'start': start,
          'note': note,
        },
        idempotencyKey: idempotencyKey,
      ),
    ),
  );

  Future<Page<Appointment>> list(
    AppointmentScope scope, {
    int page = 1,
  }) async => Page.fromJson(
    asJson(
      await _api.get(
        'me/appointments/',
        query: {'scope': scope.code, 'page': page, 'page_size': pageSize},
      ),
    ),
    Appointment.fromJson,
  );

  Future<Appointment> detail(int id) async =>
      Appointment.fromJson(asJson(await _api.get('me/appointments/$id/')));

  Future<Appointment> cancel(
    int id, {
    String? reason,
    required String idempotencyKey,
  }) async => Appointment.fromJson(
    asJson(
      await _api.post(
        'appointments/$id/cancel/',
        body: {'reason': reason},
        idempotencyKey: idempotencyKey,
      ),
    ),
  );
}

final appointmentsApiProvider = Provider<AppointmentsApi>(
  (ref) => AppointmentsApi(ref.watch(apiClientProvider)),
);
