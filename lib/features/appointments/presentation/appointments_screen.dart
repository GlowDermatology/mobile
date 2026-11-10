import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../application/appointments_providers.dart';
import '../data/appointment_models.dart';
import 'appointment_widgets.dart';
import 'appointments_text.dart';

/// "Mening qabullarim": upcoming and past appointments.
class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  AppointmentScope _scope = AppointmentScope.upcoming;

  static const _scopes = {
    AppointmentScope.upcoming: AppointmentsText.upcoming,
    AppointmentScope.past: AppointmentsText.past,
  };

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 400) {
      ref.read(appointmentsListProvider(_scope).notifier).loadMore();
    }
    return false;
  }

  Future<void> _open(Appointment a) async {
    await context.push('/appointments/${a.id}');
    if (mounted) ref.invalidate(appointmentsListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(appointmentsListProvider(_scope));
    return Scaffold(
      appBar: GdHeader(title: AppointmentsText.myAppointments.of(context)),
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
                for (final entry in _scopes.entries) ...[
                  Semantics(
                    identifier: 'appointments.scope.${entry.key.code}',
                    button: true,
                    selected: entry.key == _scope,
                    child: GdFilterChip(
                      label: entry.value.of(context),
                      selected: entry.key == _scope,
                      onTap: () => setState(() => _scope = entry.key),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: switch (async) {
              AsyncValue(value: final AppointmentsListState list) => _list(
                context,
                list,
              ),
              AsyncError(:final error) => GdErrorView(
                error: error,
                onRetry: () => ref.invalidate(appointmentsListProvider(_scope)),
              ),
              _ => const GdLoading(),
            },
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, AppointmentsListState list) {
    if (list.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.refresh(appointmentsListProvider(_scope).future),
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: box.maxHeight,
              child: GdEmptyView(
                icon: Icons.event_note_outlined,
                title:
                    (_scope == AppointmentScope.upcoming
                            ? AppointmentsText.emptyUpcoming
                            : AppointmentsText.emptyPast)
                        .of(context),
                body: AppointmentsText.emptyBody.of(context),
                action: SizedBox(
                  width: 220,
                  child: GdButton(
                    label: AppointmentsText.specialistsTitle.of(context),
                    semanticsId: 'appointments.specialists',
                    onPressed: () => context.push('/specialists'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final footer = list.hasMore || list.loadMoreError != null;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(appointmentsListProvider(_scope).future),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(GdSpace.page, 6, GdSpace.page, 24),
          itemCount: list.items.length + (footer ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            if (i < list.items.length) {
              final a = list.items[i];
              return AppointmentCard(appointment: a, onTap: () => _open(a));
            }
            if (list.loadMoreError != null) {
              return Center(
                child: TextButton.icon(
                  onPressed: () => ref
                      .read(appointmentsListProvider(_scope).notifier)
                      .loadMore(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    '${AppointmentsText.loadMoreFailed.of(context)} · ${Strings.retry.of(context)}',
                  ),
                ),
              );
            }
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }
}

/// One appointment in the list: time, specialist, service, status.
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onTap,
  });
  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final t = context.gdText;
    final a = appointment;
    final service = a.serviceName.isNotEmpty
        ? a.serviceName
        : a.serviceShortName;
    return Semantics(
      identifier: 'appointments.item.${a.id}',
      button: true,
      child: GdCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_outlined, size: 18, color: c.goldInk),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    formatAppointmentTime(a, context.language),
                    style: t.label.copyWith(color: c.ink),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(child: AppointmentStatusChip(appointment: a)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SpecialistAvatar(
                  name: a.specialist.name,
                  photoUrl: a.specialist.photoUrl,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.specialist.name,
                        style: t.subheading.copyWith(fontSize: 16),
                      ),
                      Text(
                        service,
                        style: t.bodySm.copyWith(color: c.inkMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.inkMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
