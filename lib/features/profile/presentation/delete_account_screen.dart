import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../application/profile_logic.dart';
import 'profile_text.dart';
import 'profile_widgets.dart';

/// «Hisobni o‘chirish» — `DELETE me/` (contract §2.2.3).
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_busy) return;
    if (_password.text.isEmpty) {
      setState(() => _error = ProfileText.required.of(context));
      return;
    }
    final ok = await confirmAction(
      context,
      title: ProfileText.deleteConfirmTitle.of(context),
      body:
          '${ProfileText.deleteCancelled.of(context)} ${ProfileText.deleteIrreversible.of(context)}',
      confirm: ProfileText.deleteConfirm2.of(context),
      semanticsPrefix: 'delete.dialog',
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    // The router may leave this private screen as soon as the session ends.
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final done = ProfileText.deleted.of(context);
    try {
      await ref.read(authApiProvider).deleteAccount(password: _password.text);
      await ref.read(sessionProvider.notifier).accountDeleted();
      router.go('/catalog');
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(done)));
    } on Object catch (e) {
      if (!mounted) return;
      // 409 payment_in_progress and the rest: the server's message as is.
      final (fields, general) = splitFieldErrors(e, {'password'});
      setState(() => _error = fields['password']);
      if (general != null) showError(context, general);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final me = ref.watch(sessionProvider).me;
    final noPassword = me != null && !me.hasPassword;
    Widget point(IconData icon, Color color, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: context.gdText.bodyMd.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: GdHeader(title: ProfileText.deleteAccount.of(context)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(GdSpace.page, 8, GdSpace.page, 24),
        children: [
          GdCard(
            color: c.dangerSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: c.danger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ProfileText.deleteLead.of(context),
                        style: context.gdText.label,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                point(
                  Icons.cancel_outlined,
                  c.danger,
                  ProfileText.deleteCancelled.of(context),
                ),
                point(
                  Icons.local_shipping_outlined,
                  c.inkMuted,
                  ProfileText.deletePaid.of(context),
                ),
                point(
                  Icons.savings_outlined,
                  c.goldInk,
                  ProfileText.deleteCashback.of(context),
                ),
                Text(
                  ProfileText.deleteIrreversible.of(context),
                  style: context.gdText.label.copyWith(color: c.danger),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (noPassword)
            Text(
              ProfileText.deleteNeedsPassword.of(context),
              style: context.gdText.bodySm,
            )
          else ...[
            Text(
              ProfileText.deletePasswordHint.of(context),
              style: context.gdText.bodySm,
            ),
            const SizedBox(height: 10),
            GdPasswordField(
              controller: _password,
              label: ProfileText.currentPassword.of(context),
              errorText: _error,
              onSubmitted: (_) => _delete(),
              semanticsId: 'delete.password',
            ),
          ],
        ],
      ),
      bottomNavigationBar: noPassword
          ? null
          : Padding(
              // Kept above the keyboard so the button stays reachable while typing.
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: GdBottomBar(
                child: Semantics(
                  identifier: 'delete.submit',
                  button: true,
                  child: FilledButton(
                    onPressed: _busy ? null : _delete,
                    style: FilledButton.styleFrom(
                      backgroundColor: c.danger,
                      foregroundColor: Colors.white,
                    ),
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(ProfileText.deleteAccount.of(context)),
                  ),
                ),
              ),
            ),
    );
  }
}
