import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/idempotency.dart';
import '../../../app/theme/gd_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../auth/presentation/consent_screen.dart';
import 'appointments_text.dart';

/// Runs [action], handling the generic 409s once: `terms_update_required`
/// (asks for consent, then retries) and `phone_required` (attaches a phone,
/// then retries). Any other error is rethrown.
Future<T> runGuarded<T>(
  BuildContext context,
  Future<T> Function() action, {
  bool retried = false,
}) async {
  try {
    return await action();
  } on ApiException catch (e) {
    if (retried || e.status != 409 || !context.mounted) rethrow;
    if (e.code == 'terms_update_required') {
      if (await askConsent(context) && context.mounted) {
        return runGuarded(context, action, retried: true);
      }
    } else if (e.code == 'phone_required') {
      if (await context.push<bool>('/settings/phone') == true &&
          context.mounted) {
        return runGuarded(context, action, retried: true);
      }
    }
    rethrow;
  }
}

/// Runs a POST with an `Idempotency-Key` for [intent]: reused after a network
/// error, dropped after any answer of the server. Takes the keys store (not a
/// `ref`) so it stays usable after the screen that started it is disposed.
Future<T> withIntentKey<T>(
  IdempotencyKeys keys,
  String intent,
  Future<T> Function(String key) call,
) async {
  try {
    final result = await call(keys.keyFor(intent));
    keys.done(intent);
    return result;
  } on ApiException catch (e) {
    if (!e.isNetwork) keys.done(intent);
    rethrow;
  }
}

/// The message to show for a refused booking: a field error ("Sizda bu
/// vaqtda boshqa qabul bor.") wins over the generic "Maydonlarni tekshiring.".
String bookingErrorMessage(BuildContext context, Object error) {
  if (error is ApiException &&
      !error.isNetwork &&
      error.fieldErrors.isNotEmpty) {
    final first = error.fieldErrors.values.firstWhere(
      (m) => m.isNotEmpty,
      orElse: () => '',
    );
    if (first.isNotEmpty) return first;
  }
  return errorMessage(context, error);
}

/// "Qabulni bekor qilasizmi?" confirmation.
Future<bool> confirmCancelAppointment(BuildContext context, String when) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        AppointmentsText.cancelTitle.of(context),
        style: context.gdText.heading,
      ),
      content: Text(
        AppointmentsText.cancelBody.fmt(context, {'when': when}),
        style: context.gdText.bodyMd,
      ),
      actions: [
        Semantics(
          identifier: 'appointment.cancel.keep',
          button: true,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppointmentsText.cancelKeep.of(context)),
          ),
        ),
        Semantics(
          identifier: 'appointment.cancel.confirm',
          button: true,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.gd.danger),
            child: Text(AppointmentsText.cancelConfirm.of(context)),
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}
