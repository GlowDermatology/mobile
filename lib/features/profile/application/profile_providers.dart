import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../../core/network/page.dart';
import '../../auth/application/session_controller.dart';

/// One open session of the customer — «Faol seanslar» (contract §2.2.10).
@immutable
class CustomerSession {
  const CustomerSession({
    required this.id,
    required this.device,
    required this.platform,
    required this.location,
    required this.createdAt,
    required this.updatedAt,
    required this.current,
  });

  factory CustomerSession.fromJson(Json j) => CustomerSession(
    id: asString(j['id']),
    device: asString(j['device']),
    platform: asStringOrNull(j['platform']),
    location: asString(j['location'], '—'),
    createdAt: asDate(j['created_at']),
    updatedAt: asDate(j['updated_at']),
    current: asBool(j['current']),
  );

  final String id;
  final String device;

  /// `ios` | `android` | `web` | null.
  final String? platform;

  /// "City, Region, CC", or "—" when unknown.
  final String location;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool current;

  bool get hasLocation => location.trim().isNotEmpty && location.trim() != '—';
}

/// `me/sessions/*`.
class SessionsApi {
  SessionsApi(this._api);
  final ApiClient _api;

  Future<Page<CustomerSession>> page({int page = 1}) async => Page.fromJson(
    asJson(
      await _api.get('me/sessions/', query: {'page_size': 20, 'page': page}),
    ),
    CustomerSession.fromJson,
  );

  /// `DELETE me/sessions/{id}/` → 204.
  Future<void> revoke(String id) => _api.delete('me/sessions/$id/');

  /// `POST me/sessions/revoke-others/` → number of sessions ended.
  Future<int> revokeOthers() async =>
      asInt(asJson(await _api.post('me/sessions/revoke-others/'))['revoked']);
}

final sessionsApiProvider = Provider<SessionsApi>(
  (ref) => SessionsApi(ref.watch(apiClientProvider)),
);

/// Every open session, the current one first (then most recently active).
final customerSessionsProvider =
    FutureProvider.autoDispose<List<CustomerSession>>((ref) async {
      if (!ref.watch(sessionProvider.select((s) => s.signedIn))) {
        return const [];
      }
      final api = ref.watch(sessionsApiProvider);
      final all = <CustomerSession>[];
      var page = 1;
      while (true) {
        final p = await api.page(page: page);
        all.addAll(p.items);
        if (!p.hasMore || page >= 10) break;
        page++;
      }
      return orderSessions(all);
    });

/// The current session first, the others in the server's order
/// (`updated_at` desc), without duplicates.
List<CustomerSession> orderSessions(List<CustomerSession> sessions) {
  final seen = <String>{};
  final unique = [
    for (final s in sessions)
      if (seen.add(s.id)) s,
  ];
  return [
    ...unique.where((s) => s.current),
    ...unique.where((s) => !s.current),
  ];
}

/// "12 ta" on «Buyurtmalar tarixi»: `GET me/orders/?page_size=10` → `count`.
/// Null for guests.
final ordersCountProvider = FutureProvider.autoDispose<int?>((ref) async {
  if (!ref.watch(sessionProvider.select((s) => s.signedIn))) return null;
  final j = asJson(
    await ref
        .watch(apiClientProvider)
        .get('me/orders/', query: {'page_size': 10}),
  );
  return asInt(j['count']);
});

/// "1 ta" on «Mening qabullarim»: upcoming appointments. Null for guests.
final upcomingAppointmentsCountProvider = FutureProvider.autoDispose<int?>((
  ref,
) async {
  if (!ref.watch(sessionProvider.select((s) => s.signedIn))) return null;
  final j = asJson(
    await ref
        .watch(apiClientProvider)
        .get('me/appointments/', query: {'scope': 'upcoming', 'page_size': 20}),
  );
  return asInt(j['count']);
});

/// The app version for the footer ("Glow Derma · 1.0.0"). Read from
/// [DeviceIdentity.appVersion], which the boot code took from
/// `PackageInfo.fromPlatform()` (guarded there, `1.0.0` by default).
final appVersionProvider = Provider<String>((ref) {
  try {
    return ref.watch(deviceProvider).appVersion;
  } on Object {
    return '1.0.0';
  }
});
