import 'package:flutter/material.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/format/dates.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../data/appointment_models.dart';

/// Chip tone of an appointment status: waiting = warning, confirmed or
/// attended = success, rejected = danger, cancelled (and unknown) = neutral.
GdTone appointmentTone(String status) => switch (status) {
  AppointmentStatus.requested => GdTone.warning,
  AppointmentStatus.confirmed => GdTone.success,
  AppointmentStatus.attended => GdTone.success,
  AppointmentStatus.rejected => GdTone.danger,
  _ => GdTone.neutral,
};

/// The server's `status_label` in the status tone.
class AppointmentStatusChip extends StatelessWidget {
  const AppointmentStatusChip({super.key, required this.appointment});
  final Appointment appointment;

  @override
  Widget build(BuildContext context) => GdStatusChip(
    label: appointment.statusLabel,
    tone: appointmentTone(appointment.status),
  );
}

/// "Se, 27-oktabr · 10:30–11:00".
String formatAppointmentTime(Appointment a, AppLanguage language) {
  final start = a.start;
  if (start == null) return '';
  final end =
      a.end ??
      (a.durationMin > 0 ? start.add(Duration(minutes: a.durationMin)) : null);
  return '${formatSlot(start, language)}${end == null ? '' : '–${formatTime(end)}'}';
}

/// Initials avatar, or the photo when there is one.
class SpecialistAvatar extends StatelessWidget {
  const SpecialistAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 56,
  });
  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) =>
      GdAvatar(initials: initialsOf(name), imageUrl: photoUrl, size: size);
}

/// Small rounded chip of the specialists cards ("● Du, 26-oktabr · 09:00").
class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.label,
    required this.background,
    this.dot,
  });
  final String label;
  final Color background;
  final Color? dot;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(GdRadius.sm),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot != null) ...[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: context.gdText.caption.copyWith(
              color: context.gd.ink,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Label/value row of the appointment card.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.strong = false,
  });
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final t = context.gdText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.bodyMd.copyWith(color: context.gd.inkMuted)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: strong
                  ? t.price
                  : t.bodyMd.copyWith(
                      fontWeight: FontWeight.w500,
                      color: context.gd.ink,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
