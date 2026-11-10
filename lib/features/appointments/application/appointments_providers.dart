import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/appointment_models.dart';
import '../data/appointments_api.dart';
import 'booking_logic.dart';

Duration? _noRetry(int _, Object _) => null;

/// Keeps an auto-dispose provider for [duration] after its first read.
void _cacheFor(Ref ref, Duration duration) {
  final link = ref.keepAlive();
  final timer = Timer(duration, link.close);
  ref.onDispose(timer.cancel);
}

/// `GET specialists/`.
final specialistsProvider = FutureProvider.autoDispose<List<Specialist>>((ref) {
  ref.watch(languageProvider);
  return ref.watch(appointmentsApiProvider).specialists();
}, retry: _noRetry);

/// `GET specialists/{id}/`.
final specialistProvider = FutureProvider.autoDispose.family<Specialist, int>((
  ref,
  id,
) {
  ref.watch(languageProvider);
  return ref.watch(appointmentsApiProvider).specialist(id);
}, retry: _noRetry);

/// `GET services/` by id (for descriptions on the booking screen).
final servicesProvider = FutureProvider.autoDispose<Map<int, ServiceInfo>>((
  ref,
) async {
  ref.watch(languageProvider);
  final list = await ref.watch(appointmentsApiProvider).services();
  return {for (final s in list) s.id: s};
}, retry: _noRetry);

typedef SlotsKey = ({int specialistId, int serviceId, String date});

/// Free times of one specialist, service and day; cached for a minute so the
/// date strip does not re-ask while scrolling.
final slotsProvider = FutureProvider.autoDispose.family<SlotsDay, SlotsKey>((
  ref,
  key,
) {
  _cacheFor(ref, const Duration(minutes: 1));
  return ref
      .watch(appointmentsApiProvider)
      .slots(key.specialistId, date: key.date, serviceId: key.serviceId);
}, retry: _noRetry);

/// The next free time of a specialist (shortest service, today … +6), or null
/// when the week is booked. Scans day by day, stops at the first hit, and is
/// kept for 5 minutes.
final nextSlotProvider = FutureProvider.autoDispose
    .family<DateTime?, ({int specialistId, int serviceId})>((ref, key) {
      _cacheFor(ref, const Duration(minutes: 5));
      final api = ref.watch(appointmentsApiProvider);
      return findNextSlot(
        now: clock.now(),
        fetch: (date) =>
            api.slots(key.specialistId, date: date, serviceId: key.serviceId),
      );
    }, retry: _noRetry);

/// One appointment, re-read whenever a screen opens it.
final appointmentProvider = FutureProvider.autoDispose.family<Appointment, int>(
  (ref, id) {
    ref.watch(languageProvider);
    return ref.watch(appointmentsApiProvider).detail(id);
  },
  retry: _noRetry,
);

/// The loaded pages of `GET me/appointments/` for one scope.
class AppointmentsListState {
  const AppointmentsListState({
    required this.items,
    required this.page,
    required this.pageCount,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<Appointment> items;
  final int page;
  final int pageCount;
  final bool loadingMore;
  final Object? loadMoreError;

  bool get hasMore => page < pageCount;

  AppointmentsListState append(
    List<Appointment> more, {
    required int page,
    required int pageCount,
  }) {
    final seen = {for (final a in items) a.id};
    return AppointmentsListState(
      items: [...items, ...more.where((a) => seen.add(a.id))],
      page: page,
      pageCount: pageCount,
    );
  }

  AppointmentsListState copyWith({
    bool? loadingMore,
    Object? Function()? loadMoreError,
  }) => AppointmentsListState(
    items: items,
    page: page,
    pageCount: pageCount,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreError: loadMoreError != null ? loadMoreError() : this.loadMoreError,
  );
}

class AppointmentsListController extends AsyncNotifier<AppointmentsListState> {
  AppointmentsListController(this.scope);
  final AppointmentScope scope;

  @override
  Future<AppointmentsListState> build() async {
    ref.watch(languageProvider);
    final page = await ref.watch(appointmentsApiProvider).list(scope);
    return AppointmentsListState(
      items: page.items,
      page: page.page,
      pageCount: page.pageCount,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        current.loadingMore ||
        !current.hasMore ||
        state.isLoading) {
      return;
    }
    state = AsyncData(
      current.copyWith(loadingMore: true, loadMoreError: () => null),
    );
    try {
      final page = await ref
          .read(appointmentsApiProvider)
          .list(scope, page: current.page + 1);
      if (!ref.mounted) return;
      state = AsyncData(
        current.append(page.items, page: page.page, pageCount: page.pageCount),
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreError: () => e),
      );
    }
  }
}

final appointmentsListProvider = AsyncNotifierProvider.autoDispose
    .family<
      AppointmentsListController,
      AppointmentsListState,
      AppointmentScope
    >(AppointmentsListController.new, retry: _noRetry);
