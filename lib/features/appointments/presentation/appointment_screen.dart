import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/format/money.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../../core/widgets/rings.dart';
import '../../settings/data/public_settings.dart';
import '../application/appointments_providers.dart';
import '../data/appointment_models.dart';
import '../data/appointments_api.dart';
import 'appointment_actions.dart';
import 'appointment_widgets.dart';
import 'appointments_text.dart';

/// One appointment (PDF p.14). With [created] it opens as the
/// "So‘rovingiz yuborildi" confirmation of a new booking.
class AppointmentScreen extends ConsumerStatefulWidget {
  const AppointmentScreen({super.key, required this.id, this.created = false});
  final int id;
  final bool created;

  @override
  ConsumerState<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends ConsumerState<AppointmentScreen> {
  bool _cancelling = false;

  Future<void> _cancel(Appointment a) async {
    if (!await confirmCancelAppointment(
          context,
          formatAppointmentTime(a, context.language),
        ) ||
        !mounted) {
      return;
    }
    final container = ProviderScope.containerOf(context, listen: false);
    final api = container.read(appointmentsApiProvider);
    final keys = container.read(idempotencyProvider);
    setState(() => _cancelling = true);
    try {
      await runGuarded(
        context,
        () => withIntentKey(
          keys,
          'appointment.cancel:${a.id}',
          (key) => api.cancel(a.id, idempotencyKey: key),
        ),
      );
      container
        ..invalidate(appointmentProvider(a.id))
        ..invalidate(appointmentsListProvider)
        ..invalidate(nextSlotProvider)
        ..invalidate(slotsProvider);
      if (mounted) showSnack(context, AppointmentsText.cancelled.of(context));
    } on Object catch (e) {
      container.invalidate(appointmentProvider(a.id));
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(appointmentProvider(widget.id));
    final created = widget.created;
    // A new booking replaced the navigation stack (`context.go`): system back
    // leads to the appointments list instead of closing the app.
    return PopScope(
      canPop: !created,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && created) context.go('/appointments');
      },
      child: Scaffold(
        appBar: created
            ? GdHeader(title: '', onBack: () => context.go('/appointments'))
            : GdHeader(title: AppointmentsText.appointmentTitle.of(context)),
        body: switch (async) {
          AsyncValue(value: final Appointment a) => RefreshIndicator(
            onRefresh: () => ref.refresh(appointmentProvider(widget.id).future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                GdSpace.page,
                0,
                GdSpace.page,
                24,
              ),
              children: [
                if (created) const _Hero(),
                _card(context, a),
                if (a.canCancel) ...[
                  const SizedBox(height: 12),
                  _actions(context, a),
                ],
              ],
            ),
          ),
          AsyncError(:final error) => GdErrorView(
            error: error,
            onRetry: () => ref.invalidate(appointmentProvider(widget.id)),
          ),
          _ => const GdLoading(),
        },
        bottomNavigationBar: created
            ? GdBottomBar(
                child: SizedBox(
                  width: double.infinity,
                  child: GdButton(
                    label: AppointmentsText.backToCatalog.of(context),
                    semanticsId: 'appointment.catalog',
                    onPressed: () => context.go('/catalog'),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _card(BuildContext context, Appointment a) {
    final c = context.gd;
    final t = context.gdText;
    final lang = context.language;
    final policy =
        ref.watch(publicSettingsProvider).value?.bookingPolicy.trim() ?? '';
    final service = a.serviceName.isNotEmpty
        ? a.serviceName
        : a.serviceShortName;
    return GdCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppointmentsText.appointmentTitle.of(context),
                style: t.subheading,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AppointmentStatusChip(appointment: a),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: c.line),
          ),
          InfoRow(
            label: AppointmentsText.rowSpecialist.of(context),
            value: a.specialist.name,
          ),
          InfoRow(
            label: AppointmentsText.rowService.of(context),
            value: service,
          ),
          InfoRow(
            label: AppointmentsText.rowTime.of(context),
            value: formatAppointmentTime(a, lang),
          ),
          if (a.location != null && a.location!.address.isNotEmpty)
            InfoRow(
              label: AppointmentsText.rowAddress.of(context),
              value: a.location!.address,
            ),
          InfoRow(
            label: AppointmentsText.rowPrice.of(context),
            value: formatMoney(a.price, language: lang),
            strong: true,
          ),
          if (a.status == AppointmentStatus.cancelled &&
              a.cancelledBy == 'admin') ...[
            const SizedBox(height: 4),
            Text(
              AppointmentsText.cancelledByClinic.of(context),
              style: t.caption.copyWith(color: c.danger),
            ),
          ],
          if (policy.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              AppointmentsText.policy.fmt(context, {'policy': policy}),
              style: t.caption,
            ),
          ],
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, Appointment a) => Row(
    children: [
      Expanded(
        child: GdOutlineButton(
          label: AppointmentsText.reschedule.of(context),
          semanticsId: 'appointment.reschedule',
          onPressed: _cancelling
              ? null
              : () => context.push(
                  '/specialists/${a.specialist.id}/book?reschedule=${a.id}',
                ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: GdOutlineButton(
          label: AppointmentsText.cancel.of(context),
          icon: Icons.close_rounded,
          color: context.gd.danger,
          semanticsId: 'appointment.cancel',
          onPressed: _cancelling ? null : () => _cancel(a),
        ),
      ),
    ],
  );
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final t = context.gdText;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          SizedBox.square(
            dimension: 180,
            child: GdRings(
              color: c.gold.withValues(alpha: 0.55),
              count: 4,
              child: Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: c.goldSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event_available_outlined,
                    size: 38,
                    color: c.goldInk,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Semantics(
            identifier: 'appointment.created',
            child: Text(
              AppointmentsText.sentTitle.of(context),
              textAlign: TextAlign.center,
              style: t.displayLg,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppointmentsText.sentBody.of(context),
            textAlign: TextAlign.center,
            style: t.bodyMd.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }
}
