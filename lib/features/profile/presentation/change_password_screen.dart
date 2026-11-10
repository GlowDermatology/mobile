import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../application/profile_logic.dart';
import 'profile_text.dart';

/// `POST me/password/` — change the password while signed in.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  static const _intent = 'password';
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;
  Map<String, String> _errors = const {};

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final errors = <String, String>{};
    if (_current.text.isEmpty) {
      errors['current_password'] = ProfileText.required.of(context);
    }
    switch (checkNewPassword(_next.text)) {
      case PasswordProblem.tooShort:
        errors['password'] = ProfileText.passwordTooShort.of(context);
      case PasswordProblem.numeric:
        errors['password'] = ProfileText.passwordNumeric.of(context);
      case null:
        break;
    }
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    final keys = ref.read(idempotencyProvider);
    setState(() => _busy = true);
    try {
      final me = await ref
          .read(authApiProvider)
          .changePassword(
            current: _current.text,
            password: _next.text,
            idempotencyKey: keys.keyFor(_intent),
          );
      keys.done(_intent);
      ref.read(sessionProvider.notifier).updateMe(me);
      if (!mounted) return;
      showSnack(context, ProfileText.passwordChanged.of(context));
      context.pop();
    } on Object catch (e) {
      if (e is! ApiException || !e.isNetwork) keys.done(_intent);
      if (!mounted) return;
      final (fields, general) = splitFieldErrors(e, {
        'current_password',
        'password',
      });
      setState(() => _errors = fields);
      if (general != null) showError(context, general);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider).me;
    final noPassword = me != null && !me.hasPassword;
    return Scaffold(
      appBar: GdHeader(title: ProfileText.changePassword.of(context)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(GdSpace.page, 8, GdSpace.page, 24),
        children: [
          Text(
            ProfileText.passwordLead.of(context),
            style: context.gdText.bodySm,
          ),
          if (noPassword) ...[
            const SizedBox(height: 12),
            GdCard(
              color: context.gd.warningSoft,
              child: Text(
                ProfileText.noPassword.of(context),
                style: context.gdText.bodySm.copyWith(color: context.gd.ink),
              ),
            ),
          ],
          const SizedBox(height: 20),
          GdPasswordField(
            controller: _current,
            label: ProfileText.currentPassword.of(context),
            errorText: _errors['current_password'],
            semanticsId: 'password.current',
          ),
          const SizedBox(height: 14),
          GdPasswordField(
            controller: _next,
            label: ProfileText.newPassword.of(context),
            errorText: _errors['password'],
            newPassword: true,
            onSubmitted: (_) => _save(),
            semanticsId: 'password.new',
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              ProfileText.passwordRules.of(context),
              style: context.gdText.caption,
            ),
          ),
        ],
      ),
      // Kept above the keyboard so «Saqlash» stays reachable while typing.
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: GdBottomBar(
          child: GdButton(
            label: ProfileText.passwordSave.of(context),
            loading: _busy,
            onPressed: _busy ? null : _save,
            semanticsId: 'password.save',
          ),
        ),
      ),
    );
  }
}
