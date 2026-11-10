import '../../../core/network/json.dart';

/// Where a specialist receives (`Specialist.location`, `Appointment.location`).
class ClinicLocation {
  const ClinicLocation({
    this.id,
    required this.name,
    required this.address,
    required this.phone,
  });

  factory ClinicLocation.fromJson(Json json) => ClinicLocation(
    id: asIntOrNull(json['id']),
    name: asString(json['name']),
    address: asString(json['address']),
    phone: asString(json['phone']),
  );

  final int? id;
  final String name;
  final String address;
  final String phone;
}

/// A service as one specialist offers it (their own duration and price).
class SpecialistService {
  const SpecialistService({
    required this.id,
    required this.name,
    required this.shortName,
    required this.durationMin,
    required this.price,
  });

  factory SpecialistService.fromJson(Json json) => SpecialistService(
    id: asInt(json['id']),
    name: asString(json['name']),
    shortName: asString(json['short_name']),
    durationMin: asInt(json['duration_min']),
    price: asInt(json['price']),
  );

  final int id;
  final String name;
  final String shortName;
  final int durationMin;
  final int price;

  String get displayShortName => shortName.isNotEmpty ? shortName : name;
}

/// `GET specialists/` item (contract §2.11).
class Specialist {
  const Specialist({
    required this.id,
    required this.name,
    required this.role,
    required this.roleLabel,
    this.photoUrl,
    this.bio = '',
    this.qualifications = '',
    this.experienceYears,
    this.location,
    this.services = const [],
    this.slotStepMin = 30,
  });

  factory Specialist.fromJson(Json json) => Specialist(
    id: asInt(json['id']),
    name: asString(json['name']),
    role: asString(json['role']),
    roleLabel: asString(json['role_label']),
    photoUrl: asStringOrNull(json['photo_url']),
    bio: asString(json['bio']),
    qualifications: asString(json['qualifications']),
    experienceYears: asIntOrNull(json['experience_years']),
    location: json['location'] is Map
        ? ClinicLocation.fromJson(asJson(json['location']))
        : null,
    services: asJsonList(json['services'])
        .map(SpecialistService.fromJson)
        .toList(),
    slotStepMin: asInt(json['slot_step_min'], 30),
  );

  final int id;
  final String name;

  /// `dermatologist` | `cosmetologist`.
  final String role;
  final String roleLabel;
  final String? photoUrl;
  final String bio;
  final String qualifications;
  final int? experienceYears;
  final ClinicLocation? location;
  final List<SpecialistService> services;
  final int slotStepMin;

  /// "NR" for "Nodira Rahimova".
  String get initials => initialsOf(name);

  /// The cheapest service price ("100 000 so‘mdan"), or null without services.
  int? get minPrice => services.isEmpty
      ? null
      : services.map((s) => s.price).reduce((a, b) => a < b ? a : b);

  /// The shortest service (cheapest on a tie): used to find the next free time.
  SpecialistService? get shortestService {
    if (services.isEmpty) return null;
    return services.reduce((a, b) {
      if (a.durationMin != b.durationMin) {
        return a.durationMin <= b.durationMin ? a : b;
      }
      return a.price <= b.price ? a : b;
    });
  }
}

String initialsOf(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  final first = parts.first.characters1;
  final second = parts.length > 1 ? parts[1].characters1 : '';
  return (first + second).toUpperCase();
}

extension on String {
  String get characters1 => isEmpty ? '' : String.fromCharCode(runes.first);
}

/// `GET services/` item: the clinic-wide description of a service.
class ServiceInfo {
  const ServiceInfo({
    required this.id,
    required this.name,
    required this.description,
    this.specialistIds = const [],
  });

  factory ServiceInfo.fromJson(Json json) => ServiceInfo(
    id: asInt(json['id']),
    name: asString(json['name']),
    description: asString(json['description']),
    specialistIds:
        (json['specialist_ids'] is List
                ? json['specialist_ids'] as List
                : const [])
            .map(asInt)
            .toList(),
  );

  final int id;
  final String name;
  final String description;
  final List<int> specialistIds;
}

/// "HH:MM" → minutes after midnight (null when malformed).
int? parseClock(String value) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
  if (m == null) return null;
  return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
}

/// Minutes after midnight → "HH:MM".
String clockLabel(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// One free start time of `slots/`.
class Slot {
  const Slot({
    required this.start,
    required this.end,
    required this.startAt,
    this.startAtRaw = '',
  });

  factory Slot.fromJson(Json json) => Slot(
    start: asString(json['start']),
    end: asString(json['end']),
    startAt: asDate(json['start_at']),
    startAtRaw: asString(json['start_at']),
  );

  /// "09:00" (Tashkent wall clock).
  final String start;
  final String end;

  /// The exact instant to send back as `start` when booking.
  final DateTime? startAt;

  /// `start_at` exactly as the server sent it ("2026-10-28T09:00:00+05:00"):
  /// what `POST appointments/` takes back as `start`.
  final String startAtRaw;

  int? get startMinutes => parseClock(start);
}

/// `GET specialists/{id}/slots/?date=&service_id=`.
class SlotsDay {
  const SlotsDay({
    required this.date,
    required this.durationMin,
    required this.price,
    required this.slotStepMin,
    this.workStart,
    this.workEnd,
    this.slots = const [],
    this.raw = const {},
  });

  factory SlotsDay.fromJson(Json json) {
    final hours = json['working_hours'] is Map
        ? asJson(json['working_hours'])
        : null;
    return SlotsDay(
      date: asString(json['date']),
      durationMin: asInt(json['duration_min']),
      price: asInt(json['price']),
      slotStepMin: asInt(json['slot_step_min'], 30),
      workStart: hours == null ? null : parseClock(asString(hours['start'])),
      workEnd: hours == null ? null : parseClock(asString(hours['end'])),
      slots: asJsonList(json['slots']).map(Slot.fromJson).toList(),
      raw: json,
    );
  }

  /// "2026-10-28".
  final String date;
  final int durationMin;
  final int price;
  final int slotStepMin;

  /// Working hours in minutes after midnight; null when not working.
  final int? workStart;
  final int? workEnd;
  final List<Slot> slots;
  final Json raw;

  bool get working => workStart != null && workEnd != null;

  /// Nothing to book that day (not working, or every time taken).
  bool get closed => !working || slots.isEmpty;
}

/// Appointment statuses (`Appointment.status`).
abstract final class AppointmentStatus {
  static const requested = 'requested';
  static const confirmed = 'confirmed';
  static const rejected = 'rejected';
  static const attended = 'attended';
  static const cancelled = 'cancelled';
}

class AppointmentSpecialist {
  const AppointmentSpecialist({
    required this.id,
    required this.name,
    required this.roleLabel,
    this.photoUrl,
  });

  factory AppointmentSpecialist.fromJson(Json json) => AppointmentSpecialist(
    id: asInt(json['id']),
    name: asString(json['name']),
    roleLabel: asString(json['role_label']),
    photoUrl: asStringOrNull(json['photo_url']),
  );

  final int id;
  final String name;
  final String roleLabel;
  final String? photoUrl;
}

/// `Appointment` (contract §2.11).
class Appointment {
  const Appointment({
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.specialist,
    required this.serviceId,
    required this.serviceName,
    required this.serviceShortName,
    this.location,
    this.start,
    this.end,
    this.durationMin = 0,
    this.price = 0,
    this.note,
    this.cancelledBy,
    this.canCancel = false,
  });

  factory Appointment.fromJson(Json json) {
    final service = asJson(json['service']);
    return Appointment(
      id: asInt(json['id']),
      status: asString(json['status']),
      statusLabel: asString(json['status_label']),
      specialist: AppointmentSpecialist.fromJson(asJson(json['specialist'])),
      serviceId: asInt(service['id']),
      serviceName: asString(service['name']),
      serviceShortName: asString(service['short_name']),
      location: json['location'] is Map
          ? ClinicLocation.fromJson(asJson(json['location']))
          : null,
      start: asDate(json['start']),
      end: asDate(json['end']),
      durationMin: asInt(json['duration_min']),
      price: asInt(json['price']),
      note: asStringOrNull(json['note']),
      cancelledBy: asStringOrNull(json['cancelled_by']),
      canCancel: asBool(json['can_cancel']),
    );
  }

  final int id;
  final String status;
  final String statusLabel;
  final AppointmentSpecialist specialist;
  final int serviceId;
  final String serviceName;
  final String serviceShortName;
  final ClinicLocation? location;
  final DateTime? start;
  final DateTime? end;
  final int durationMin;
  final int price;
  final String? note;
  final String? cancelledBy;
  final bool canCancel;
}

/// `GET me/appointments/?scope=`.
enum AppointmentScope {
  upcoming('upcoming'),
  past('past');

  const AppointmentScope(this.code);
  final String code;
}
