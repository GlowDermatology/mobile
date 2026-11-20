import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../application/appointments_providers.dart';
import '../application/booking_logic.dart';
import '../data/appointment_models.dart';
import '../data/appointments_api.dart';
import 'appointment_actions.dart';
import 'appointment_widgets.dart';
import 'appointments_text.dart';

/// "Qabulga yozilish" (PDF p.13): clinic, service, day, free time, then
/// `POST appointments/`. With [rescheduleFrom] the old appointment is
/// cancelled once the new one is booked.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({
    super.key,
    required this.specialistId,
    this.rescheduleFrom,
  });
  final int specialistId;

  /// Appointment being moved: it is cancelled once the new one is booked.
  final int? rescheduleFrom;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  static const _dayChipWidth = 58.0;
  static const _dayChipGap = 8.0;

  late final List<DateTime> _days = dateStrip(clock.now());
  final _dayScroll = ScrollController();

  int? _locationId;
  int? _serviceId;
  late DateTime _day = _days.first;
  ({SlotsKey key, Slot value})? _selectedSlot;
  bool _submitting = false;

  /// Until the customer picks a day, a closed day moves the selection on.
  bool _autoAdvance = true;

  @override
  void dispose() {
    _dayScroll.dispose();
    super.dispose();
  }

  SlotsKey _key(int locationId, int serviceId, DateTime day) => (
    specialistId: widget.specialistId,
    serviceId: serviceId,
    locationId: locationId,
    date: isoDate(day),
  );

  ClinicLocation? _location(Specialist specialist, Appointment? rescheduled) {
    if (specialist.locations.length == 1) return specialist.locations.single;
    final id = _locationId ?? rescheduled?.location.id;
    for (final location in specialist.locations) {
      if (location.id == id) return location;
    }
    return null;
  }

  SpecialistService? _service(Specialist specialist, Appointment? rescheduled) {
    if (specialist.services.isEmpty) return null;
    final id = _serviceId ?? rescheduled?.serviceId;
    return specialist.services.firstWhere(
      (e) => e.id == id,
      orElse: () => specialist.services.first,
    );
  }

  void _selectLocation(int id) {
    setState(() {
      _locationId = id;
      _day = _days.first;
      _selectedSlot = null;
      _autoAdvance = true;
    });
    if (_dayScroll.hasClients) _dayScroll.jumpTo(0);
  }

  Slot? _slotFor(SlotsKey key) =>
      _selectedSlot?.key == key ? _selectedSlot?.value : null;

  void _selectDay(DateTime day, {bool byUser = true}) {
    setState(() {
      _day = day;
      _selectedSlot = null;
      if (byUser) _autoAdvance = false;
    });
    final index = _days.indexOf(day);
    if (!byUser && index >= 0 && _dayScroll.hasClients) {
      final target = (index * (_dayChipWidth + _dayChipGap) - 40).clamp(
        0.0,
        _dayScroll.position.maxScrollExtent,
      );
      _dayScroll.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(specialistProvider(widget.specialistId));
    final rescheduleFrom = widget.rescheduleFrom;
    final rescheduled = rescheduleFrom == null
        ? null
        : ref.watch(appointmentProvider(rescheduleFrom)).value;
    final specialist = async.value;
    final location = specialist == null
        ? null
        : _location(specialist, rescheduled);
    final service = specialist == null
        ? null
        : _service(specialist, rescheduled);
    return Scaffold(
      appBar: GdHeader(title: AppointmentsText.bookingTitle.of(context)),
      body: switch (async) {
        AsyncValue(value: final Specialist s) => _body(
          context,
          s,
          location,
          service,
        ),
        AsyncError(:final error) => GdErrorView(
          error: error,
          onRetry: () =>
              ref.invalidate(specialistProvider(widget.specialistId)),
        ),
        _ => const GdLoading(),
      },
      bottomNavigationBar: location == null || service == null
          ? null
          : _bottom(context, location, service),
    );
  }

  Widget _body(
    BuildContext context,
    Specialist s,
    ClinicLocation? location,
    SpecialistService? service,
  ) {
    final c = context.gd;
    final t = context.gdText;
    final descriptions = ref.watch(servicesProvider).value ?? const {};
    return ListView(
      padding: const EdgeInsets.fromLTRB(GdSpace.page, 4, GdSpace.page, 24),
      children: [
        Row(
          children: [
            SpecialistAvatar(
              name: s.name,
              photoUrl: s.photoUrl,
              photoThumbUrl: s.photoThumbUrl,
              size: 54,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: t.subheading),
                  Text(
                    s.roleLabel,
                    style: t.bodySm.copyWith(color: c.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (widget.rescheduleFrom != null) ...[
          const SizedBox(height: 14),
          _Note(
            icon: Icons.update_rounded,
            text: AppointmentsText.rescheduleHint.of(context),
          ),
        ],
        const SizedBox(height: 22),
        _Label(AppointmentsText.clinic.of(context)),
        if (s.locations.isEmpty)
          Text(AppointmentsText.noClinics.of(context), style: t.bodyMd)
        else
          for (final clinic in s.locations) ...[
            _ClinicCard(
              clinic: clinic,
              selected: clinic.id == location?.id,
              onTap: s.locations.length > 1 && !_submitting
                  ? () {
                      if (clinic.id != location?.id) _selectLocation(clinic.id);
                    }
                  : null,
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 12),
        _Label(AppointmentsText.service.of(context)),
        if (service == null)
          Text(AppointmentsText.noServices.of(context), style: t.bodyMd)
        else
          for (final svc in s.services) ...[
            _ServiceCard(
              service: svc,
              description: descriptions[svc.id]?.description ?? '',
              selected: svc.id == service.id,
              onTap: () => setState(() {
                _serviceId = svc.id;
                _selectedSlot = null;
              }),
            ),
            const SizedBox(height: 10),
          ],
        if (location != null && service != null) ...[
          const SizedBox(height: 12),
          _Label(AppointmentsText.date.of(context)),
          SizedBox(
            height: 74,
            child: ListView.separated(
              controller: _dayScroll,
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: _days.length,
              separatorBuilder: (_, _) => const SizedBox(width: _dayChipGap),
              itemBuilder: (context, i) {
                final day = _days[i];
                return _DayChip(
                  day: day,
                  slotsKey: _key(location.id, service.id, day),
                  selected: day == _day,
                  width: _dayChipWidth,
                  onTap: () => _selectDay(day),
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          _Label(AppointmentsText.freeTime.of(context)),
          _times(context, location, service),
          const SizedBox(height: 18),
          _Note(
            icon: Icons.info_outline_rounded,
            text: AppointmentsText.bookingNote.of(context),
          ),
        ],
      ],
    );
  }

  Widget _times(
    BuildContext context,
    ClinicLocation location,
    SpecialistService service,
  ) {
    final activeDay = _day;
    final activeLocationId = _locationId;
    final activeServiceId = _serviceId;
    final key = _key(location.id, service.id, activeDay);
    final selected = _slotFor(key);
    final async = ref.watch(slotsProvider(key));
    switch (async) {
      case AsyncValue(value: final SlotsDay day):
        if (day.closed && _autoAdvance) {
          final next = _days.indexOf(_day) + 1;
          if (next < _days.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted &&
                  _autoAdvance &&
                  _day == activeDay &&
                  _locationId == activeLocationId &&
                  _serviceId == activeServiceId) {
                _selectDay(_days[next], byUser: false);
              }
            });
          }
        } else if (!day.closed && _autoAdvance) {
          _autoAdvance = false;
        }
        final chips = buildTimeGrid(day);
        if (day.slots.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              (day.working
                      ? AppointmentsText.noSlots
                      : AppointmentsText.notWorking)
                  .of(context),
              style: context.gdText.bodyMd.copyWith(color: context.gd.inkMuted),
            ),
          );
        }
        return GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.85,
          children: chips.map((chip) {
            final slot = chip.slot;
            return _TimeChipView(
              chip: chip,
              selected: slot != null && selected?.startAtRaw == slot.startAtRaw,
              onTap: slot == null || !chip.enabled
                  ? null
                  : () =>
                        setState(() => _selectedSlot = (key: key, value: slot)),
            );
          }).toList(),
        );
      case AsyncError(:final error):
        return GdErrorView(
          error: error,
          onRetry: () => ref.invalidate(slotsProvider(key)),
        );
      default:
        return const SizedBox(height: 120, child: GdLoading());
    }
  }

  Widget _bottom(
    BuildContext context,
    ClinicLocation location,
    SpecialistService service,
  ) {
    final lang = context.language;
    final t = context.gdText;
    final slotsKey = _key(location.id, service.id, _day);
    final day = ref.watch(slotsProvider(slotsKey)).value;
    final slot = _slotFor(slotsKey);
    final price = day?.price ?? service.price;
    final duration = day?.durationMin ?? service.durationMin;
    final start = slot?.startAt;
    final summary = start == null
        ? AppointmentsText.chooseTime.of(context)
        : '${weekdayShort(start, lang)}, ${formatDayMonth(start, lang)} · ${formatTime(start)} · ${AppointmentsText.minutes.fmt(context, {'n': duration})}';
    return GdBottomBar(
      top: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  summary,
                  style: t.bodySm.copyWith(color: context.gd.inkMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(formatMoney(price, language: lang), style: t.price),
            ],
          ),
          if (start != null)
            Text(
              [
                location.name,
                location.address,
              ].where((part) => part.isNotEmpty).join(' · '),
              style: t.bodySm.copyWith(color: context.gd.inkMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: GdButton(
          label: AppointmentsText.book.of(context),
          loading: _submitting,
          semanticsId: 'booking.submit',
          onPressed: slot == null ? null : () => _book(slotsKey, slot),
        ),
      ),
    );
  }

  Future<void> _book(SlotsKey slotsKey, Slot slot) async {
    // Captured up front: the customer may leave the screen while the request
    // runs, and a disposed widget's `ref` can no longer be used.
    final container = ProviderScope.containerOf(context, listen: false);
    final api = container.read(appointmentsApiProvider);
    final keys = container.read(idempotencyProvider);
    final from = widget.rescheduleFrom;
    setState(() => _submitting = true);
    try {
      final created = await runGuarded(
        context,
        () => withIntentKey(
          keys,
          'appointment.book:${slotsKey.specialistId}:${slotsKey.serviceId}:${slotsKey.locationId}:${slot.startAtRaw}',
          (key) => api.book(
            specialistId: slotsKey.specialistId,
            serviceId: slotsKey.serviceId,
            locationId: slotsKey.locationId,
            start: slot.startAtRaw,
            idempotencyKey: key,
          ),
        ),
      );
      if (from != null) {
        try {
          await withIntentKey(
            keys,
            'appointment.cancel:$from',
            (key) => api.cancel(from, idempotencyKey: key),
          );
        } on Object catch (e) {
          if (mounted) {
            showSnack(
              context,
              AppointmentsText.rescheduleCancelFailed.fmt(context, {
                'message': errorMessage(context, e),
              }),
            );
          }
        }
        container.invalidate(appointmentProvider(from));
      }
      container
        ..invalidate(appointmentsListProvider)
        ..invalidate(nextSlotProvider)
        ..invalidate(slotsProvider);
      if (!mounted) return;
      context.go('/appointments/${created.id}?created=1');
    } on ApiException catch (e) {
      if (e.code == 'slot_taken' ||
          e.fieldCodes['start'] == 'slot_unavailable') {
        container.invalidate(slotsProvider(slotsKey));
        if (mounted && _selectedSlot?.key == slotsKey) {
          setState(() => _selectedSlot = null);
        }
      }
      if (mounted) showSnack(context, bookingErrorMessage(context, e));
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _ClinicCard extends StatelessWidget {
  const _ClinicCard({
    required this.clinic,
    required this.selected,
    required this.onTap,
  });

  final ClinicLocation clinic;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final t = context.gdText;
    return Semantics(
      identifier: 'booking.clinic.${clinic.id}',
      button: onTap != null,
      selected: selected,
      child: GdCard(
        border: Border.all(color: selected ? c.goldInk : c.line),
        color: selected ? c.goldSoft : c.surfaceRaised,
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.location_on_outlined, size: 20, color: c.goldInk),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(clinic.name, style: t.label),
                  if (clinic.address.isNotEmpty)
                    Text(clinic.address, style: t.bodySm),
                  if (selected && clinic.directions.isNotEmpty)
                    Text(
                      clinic.directions,
                      style: t.bodySm.copyWith(color: c.inkMuted),
                    ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? c.goldInk : c.inkMuted,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: context.gdText.subheading.copyWith(fontSize: 16)),
  );
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(icon, size: 18, color: context.gd.goldInk),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: context.gdText.bodySm.copyWith(color: context.gd.inkMuted),
        ),
      ),
    ],
  );
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.description,
    required this.selected,
    required this.onTap,
  });
  final SpecialistService service;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final t = context.gdText;
    final radius = BorderRadius.circular(GdRadius.md);
    return Semantics(
      identifier: 'booking.service.${service.id}',
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? c.goldSoft : c.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? c.gold : c.lineStrong,
            width: selected ? 1.6 : 1.2,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        style: t.label.copyWith(fontSize: 15, color: c.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          AppointmentsText.minutes.fmt(context, {
                            'n': service.durationMin,
                          }),
                          if (description.trim().isNotEmpty) description.trim(),
                        ].join(' · '),
                        style: t.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  formatMoney(service.price, language: context.language),
                  style: t.price,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Du / 26": filled gold when selected, faded when the day has no free time.
class _DayChip extends ConsumerWidget {
  const _DayChip({
    required this.day,
    required this.slotsKey,
    required this.selected,
    required this.width,
    required this.onTap,
  });
  final DateTime day;
  final SlotsKey slotsKey;
  final bool selected;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gd;
    final t = context.gdText;
    final closed = ref.watch(slotsProvider(slotsKey)).value?.closed ?? false;
    final radius = BorderRadius.circular(GdRadius.md);
    final fg = selected
        ? c.onGold
        : (closed ? c.inkMuted.withValues(alpha: 0.7) : c.ink);
    return Semantics(
      identifier: 'booking.date.${slotsKey.date}',
      button: true,
      selected: selected,
      enabled: !closed || selected,
      child: Material(
        color: selected
            ? c.gold
            : (closed ? Colors.transparent : c.surfaceRaised),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? c.gold : (closed ? c.line : c.lineStrong),
            width: 1.2,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: closed && !selected ? null : onTap,
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weekdayShort(day, context.language),
                  style: t.caption.copyWith(color: fg),
                ),
                const SizedBox(height: 2),
                Text(
                  '${day.day}',
                  style: t.heading.copyWith(fontSize: 20, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeChipView extends StatelessWidget {
  const _TimeChipView({
    required this.chip,
    required this.selected,
    required this.onTap,
  });
  final TimeChip chip;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final radius = BorderRadius.circular(GdRadius.md);
    final enabled = chip.enabled;
    final style = context.gdText.label.copyWith(
      fontSize: 15,
      color: selected
          ? c.onGold
          : (enabled ? c.ink : c.inkMuted.withValues(alpha: 0.6)),
      decoration: enabled ? null : TextDecoration.lineThrough,
    );
    return Semantics(
      identifier: 'booking.time.${chip.label}',
      button: true,
      enabled: enabled,
      selected: selected,
      child: Material(
        color: selected
            ? c.gold
            : (enabled ? c.surfaceRaised : Colors.transparent),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? c.gold : (enabled ? c.lineStrong : c.line),
            width: 1.2,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Center(child: Text(chip.label, style: style)),
        ),
      ),
    );
  }
}
