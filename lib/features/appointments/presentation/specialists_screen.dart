import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/format/money.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../application/appointments_providers.dart';
import '../application/booking_logic.dart';
import '../data/appointment_models.dart';
import 'appointment_widgets.dart';
import 'appointments_text.dart';

/// "Mutaxassislar" (PDF p.12): specialists by role with their next free time.
class SpecialistsScreen extends ConsumerStatefulWidget {
  const SpecialistsScreen({super.key});

  @override
  ConsumerState<SpecialistsScreen> createState() => _SpecialistsScreenState();
}

class _SpecialistsScreenState extends ConsumerState<SpecialistsScreen> {
  SpecialistFilter _filter = SpecialistFilter.all;

  static const _filters = {
    SpecialistFilter.all: AppointmentsText.filterAll,
    SpecialistFilter.dermatologist: AppointmentsText.filterDermatologists,
    SpecialistFilter.cosmetologist: AppointmentsText.filterCosmetologists,
  };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(specialistsProvider);
    return Scaffold(
      appBar: GdHeader(title: AppointmentsText.specialistsTitle.of(context)),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(
                GdSpace.page,
                4,
                GdSpace.page,
                8,
              ),
              children: [
                for (final entry in _filters.entries) ...[
                  Semantics(
                    identifier: 'specialists.filter.${entry.key.name}',
                    button: true,
                    selected: entry.key == _filter,
                    child: GdFilterChip(
                      label: entry.value.of(context),
                      selected: entry.key == _filter,
                      onTap: () => setState(() => _filter = entry.key),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: switch (async) {
              AsyncValue(value: final List<Specialist> all) => _list(
                context,
                all,
              ),
              AsyncError(:final error) => GdErrorView(
                error: error,
                onRetry: () => ref.invalidate(specialistsProvider),
              ),
              _ => const GdLoading(),
            },
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, List<Specialist> all) {
    final shown = filterSpecialists(all, _filter);
    final note = Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Text(
        AppointmentsText.specialistsNote.of(context),
        style: context.gdText.caption,
      ),
    );
    return RefreshIndicator(
      onRefresh: () {
        ref.invalidate(nextSlotProvider);
        return ref.refresh(specialistsProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(GdSpace.page, 6, GdSpace.page, 24),
        children: [
          if (shown.isEmpty)
            GdEmptyView(
              icon: Icons.medical_services_outlined,
              title:
                  (all.isEmpty
                          ? AppointmentsText.noSpecialists
                          : AppointmentsText.noSpecialistsInFilter)
                      .of(context),
            ),
          for (final s in shown) ...[
            SpecialistCard(specialist: s),
            const SizedBox(height: 12),
          ],
          note,
        ],
      ),
    );
  }
}

/// One specialist: avatar, name, role · services, next free time, price.
class SpecialistCard extends StatelessWidget {
  const SpecialistCard({super.key, required this.specialist});
  final Specialist specialist;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final t = context.gdText;
    final s = specialist;
    final summary = servicesSummary(s);
    final minPrice = s.minPrice;
    return Semantics(
      identifier: 'specialists.item.${s.id}',
      button: true,
      child: GdCard(
        onTap: () => context.push('/specialists/${s.id}/book'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SpecialistAvatar(name: s.name, photoUrl: s.photoUrl, size: 58),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: t.subheading,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          s.roleLabel,
                          if (summary.isNotEmpty) summary,
                        ].join(' · '),
                        style: t.bodySm.copyWith(color: c.inkMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.inkMuted),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (s.shortestService != null)
                  _NextSlotChip(
                    specialistId: s.id,
                    serviceId: s.shortestService!.id,
                  ),
                if (minPrice != null)
                  InfoChip(
                    label: AppointmentsText.servicesFrom.fmt(context, {
                      'n': s.services.length,
                      'price': formatMoney(
                        minPrice,
                        language: context.language,
                      ),
                    }),
                    background: c.goldSoft,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NextSlotChip extends ConsumerWidget {
  const _NextSlotChip({required this.specialistId, required this.serviceId});
  final int specialistId;
  final int serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gd;
    final async = ref.watch(
      nextSlotProvider((specialistId: specialistId, serviceId: serviceId)),
    );
    return switch (async) {
      AsyncData(value: final DateTime slot) => InfoChip(
        label: nextSlotLabel(slot, clock.now(), context.language),
        background: c.successSoft,
        dot: c.success,
      ),
      AsyncData() => InfoChip(
        label: AppointmentsText.weekBusy.of(context),
        background: c.line,
        dot: c.inkMuted,
      ),
      AsyncError() => const SizedBox.shrink(),
      _ => Container(
        width: 120,
        height: 28,
        decoration: BoxDecoration(
          color: c.line.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(GdRadius.sm),
        ),
      ),
    };
  }
}
