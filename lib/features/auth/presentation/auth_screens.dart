import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/format/phone.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../../core/widgets/product_art.dart';
import '../../../core/widgets/rings.dart';
import '../../settings/data/public_settings.dart';
import '../application/session_controller.dart';
import '../data/auth_models.dart';
import 'auth_text.dart';
import 'auth_widgets.dart';
import 'language_sheet.dart';

/// Arguments passed between the sign-in steps.
class OtpArgs {
  const OtpArgs({required this.phone, required this.purpose, required this.issue, this.password, this.next});
  final String phone;
  final OtpPurpose purpose;
  final CodeIssue issue;

  /// The typed password, kept in memory only until the new-device step ends.
  final String? password;
  final String? next;
}

class PasswordArgs {
  const PasswordArgs({required this.phone, this.next});
  final String phone;
  final String? next;
}

class RegisterArgs {
  const RegisterArgs({required this.phone, required this.verificationToken, this.next});
  final String phone;
  final String verificationToken;
  final String? next;
}

/// Location of an auth step, keeping `next` so the router can return there
/// once the session starts.
String authRoute(String path, String? next) => next == null ? path : Uri(path: path, queryParameters: {'next': next}).toString();

/// Design 1 — "Xush kelibsiz": phone number and consent.
class AuthPhoneScreen extends ConsumerStatefulWidget {
  const AuthPhoneScreen({super.key, this.next});
  final String? next;

  @override
  ConsumerState<AuthPhoneScreen> createState() => _AuthPhoneScreenState();
}

class _AuthPhoneScreenState extends ConsumerState<AuthPhoneScreen> {
  final _phone = TextEditingController();
  bool _agreed = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = toE164(_phone.text);
    if (phone == null) return setState(() => _error = AuthText.phoneInvalid.of(context));
    if (!_agreed) return showSnack(context, AuthText.consentRequired.of(context));
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final issue = await ref.read(authApiProvider).sendCode(phone, OtpPurpose.register);
      if (!mounted) return;
      unawaited(context.push(authRoute('/auth/otp', widget.next), extra: OtpArgs(phone: phone, purpose: OtpPurpose.register, issue: issue, next: widget.next)));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'phone_registered') {
        unawaited(context.push(authRoute('/auth/password', widget.next), extra: PasswordArgs(phone: phone, next: widget.next)));
      } else if (e.fieldErrors.containsKey('phone')) {
        setState(() => _error = e.fieldErrors['phone']);
      } else {
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final t = context.gdText;
    final language = ref.watch(languageProvider);
    final linkStyle = t.bodySm.copyWith(color: c.ink, fontWeight: FontWeight.w700, decoration: TextDecoration.underline);
    return Scaffold(
      body: Column(children: [
        _WelcomeHero(
          language: language,
          onLanguage: () => showLanguageSheet(context, ref),
          onClose: context.canPop() ? () => context.pop() : null,
        ),
        Expanded(
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              children: [
                AuthHeading(title: AuthText.welcome.of(context), body: Text(AuthText.welcomeBody.of(context), style: t.bodyMd.copyWith(color: c.inkMuted))),
                const SizedBox(height: 28),
                Text(AuthText.phone.of(context), style: t.label),
                const SizedBox(height: 8),
                GdPhoneField(controller: _phone, errorText: _error, onSubmitted: (_) => _submit()),
                const SizedBox(height: 22),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Semantics(
                      identifier: 'auth.consent',
                      child: Checkbox(value: _agreed, onChanged: (v) => setState(() => _agreed = v ?? false)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(style: t.bodySm, children: [
                        TextSpan(text: AuthText.agreePrefix.of(context)),
                        TextSpan(text: AuthText.privacy.of(context), style: linkStyle, recognizer: TapGestureRecognizer()..onTap = () => context.push('/settings/legal/privacy')),
                        TextSpan(text: AuthText.and.of(context)),
                        TextSpan(text: AuthText.terms.of(context), style: linkStyle, recognizer: TapGestureRecognizer()..onTap = () => context.push('/settings/legal/terms')),
                        TextSpan(text: AuthText.agreeSuffix.of(context)),
                      ]),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
        GdBottomBar(
          child: Column(children: [
            GdButton(label: AuthText.getCode.of(context), loading: _busy, onPressed: _submit, semanticsId: 'auth.getCode'),
            const SizedBox(height: 10),
            Text(AuthText.codeValid.of(context), style: t.caption),
          ]),
        ),
      ]),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.language, required this.onLanguage, this.onClose});
  final AppLanguage language;
  final VoidCallback onLanguage;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(GdRadius.lg)),
      child: Container(
        color: c.banner,
        height: 300 + MediaQuery.paddingOf(context).top,
        child: Stack(children: [
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.paddingOf(context).top - 40,
            bottom: -140,
            child: GdRings(color: c.gold.withValues(alpha: 0.75), count: 4, strokeWidth: 1.2),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 34,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                ProductArt(kind: ProductArtKind.dropper, size: 62),
                SizedBox(width: 22),
                ProductArt(kind: ProductArtKind.pump, size: 96),
                SizedBox(width: 22),
                ProductArt(kind: ProductArtKind.jar, size: 66),
              ],
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
              child: Row(children: [
                if (onClose != null)
                  IconButton(onPressed: onClose, icon: Icon(Icons.close, color: c.bannerInkSoft), tooltip: Strings.close.of(context)),
                GdWordmark(color: c.bannerInk, size: 30),
                const Spacer(),
                Semantics(
                  identifier: 'auth.language',
                  button: true,
                  child: OutlinedButton(
                    onPressed: onLanguage,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: c.bannerInkSoft,
                      side: BorderSide(color: c.bannerInkSoft.withValues(alpha: 0.4)),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(language.label, style: context.gdText.label.copyWith(color: c.bannerInkSoft)),
                      const SizedBox(width: 6),
                      Icon(Icons.keyboard_arrow_down, size: 20, color: c.bannerInkSoft),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Design 2 — "Kodni kiriting": 6-digit SMS code for registration, a new
/// device or a password reset.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, this.args});
  final OtpArgs? args;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _field = GlobalKey<GdOtpFieldState>();
  String _code = '';
  bool _busy = false;
  bool _error = false;
  String? _message;
  late CodeIssue _issue;
  Timer? _timer;
  int _resendLeft = 0;

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    if (args != null) {
      _issue = args.issue;
      _startTimer(args.issue.resendIn);
    }
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() => _resendLeft = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendLeft = (_resendLeft - 1).clamp(0, 1 << 30));
      if (_resendLeft == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    final args = widget.args!;
    setState(() => _busy = true);
    try {
      final auth = ref.read(authApiProvider);
      if (args.purpose == OtpPurpose.loginNewDevice) {
        final result = await auth.login(args.phone, args.password ?? '');
        if (result is LoginNeedsCode) _issue = result.issue;
        if (result is LoginSignedIn) {
          await ref.read(sessionProvider.notifier).signedIn(result.tokens);
          return;
        }
      } else {
        _issue = await auth.sendCode(args.phone, args.purpose);
      }
      if (!mounted) return;
      _startTimer(_issue.resendIn);
      _field.currentState?.clear();
      showSnack(context, AuthText.codeResent.of(context));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.retryAfter != null) _startTimer(e.retryAfter!);
      showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final args = widget.args!;
    if (_code.length != _issue.length || _busy) return;
    setState(() {
      _busy = true;
      _error = false;
      _message = null;
    });
    final auth = ref.read(authApiProvider);
    try {
      final token = await auth.verifyCode(args.phone, args.purpose, _code);
      if (!mounted) return;
      switch (args.purpose) {
        case OtpPurpose.register:
          context.pushReplacement(authRoute('/auth/register', args.next), extra: RegisterArgs(phone: args.phone, verificationToken: token, next: args.next));
        case OtpPurpose.resetPassword:
          context.pushReplacement(authRoute('/auth/reset', args.next), extra: RegisterArgs(phone: args.phone, verificationToken: token, next: args.next));
        case OtpPurpose.loginNewDevice:
          final result = await auth.login(args.phone, args.password ?? '', verificationToken: token);
          if (result is LoginSignedIn) await ref.read(sessionProvider.notifier).signedIn(result.tokens);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _message = e.fieldErrors['code'] ?? e.displayMessage;
      });
      if (e.code == 'otp_locked' && e.retryAfter != null) _startTimer(e.retryAfter!);
      if (e.code == 'verification_invalid' || e.code == 'invalid_credentials') {
        showSnack(context, AuthText.restart.of(context));
        context.go(authRoute('/auth', args.next));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    if (args == null) return _Restart(next: null);
    final c = context.gd;
    final t = context.gdText;
    final complete = _code.length == _issue.length;
    return Scaffold(
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.chevron_left, size: 30), onPressed: () => context.pop())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          AuthHeading(
            overline: AuthText.step.fmt(context, {'n': 2}),
            title: AuthText.enterCode.of(context),
            body: Text.rich(TextSpan(style: t.bodyMd.copyWith(color: c.inkMuted), children: [
              TextSpan(text: '${formatPhone(args.phone)} ', style: t.bodyMd.copyWith(fontWeight: FontWeight.w700)),
              TextSpan(text: AuthText.codeSent.fmt(context, {'n': _issue.length})),
            ])),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => context.go(authRoute('/auth', args.next)),
              child: Container(
                padding: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.gold, width: 1.5))),
                child: Text(AuthText.changeNumber.of(context), style: t.label),
              ),
            ),
          ),
          const SizedBox(height: 28),
          GdOtpField(
            key: _field,
            length: _issue.length,
            error: _error,
            enabled: !_busy,
            onChanged: (v) => setState(() {
              _code = v;
              _error = false;
              _message = null;
            }),
            onCompleted: (_) => _submit(),
          ),
          if (_message != null) ...[const SizedBox(height: 10), Text(_message!, style: t.bodySm.copyWith(color: c.danger))],
          const SizedBox(height: 22),
          Row(children: [
            Icon(Icons.schedule, size: 20, color: c.inkMuted),
            const SizedBox(width: 8),
            if (_resendLeft > 0) ...[
              Text(AuthText.resendIn.of(context), style: t.bodySm),
              const SizedBox(width: 6),
              Text('${_resendLeft ~/ 60}:${(_resendLeft % 60).toString().padLeft(2, '0')}', style: t.label),
            ] else
              TextButton(onPressed: _busy ? null : _resend, child: Text(AuthText.resend.of(context))),
          ]),
        ],
      ),
      bottomNavigationBar: GdBottomBar(
        child: Column(children: [
          GdButton(label: AuthText.confirm.of(context), loading: _busy, onPressed: complete ? _submit : null, semanticsId: 'auth.confirm'),
          const SizedBox(height: 10),
          Text(AuthText.nextStepHint.of(context), style: t.caption),
        ]),
      ),
    );
  }
}

/// Step 3 for an existing account: the password (design 2's "parolni kiritish").
class PasswordScreen extends ConsumerStatefulWidget {
  const PasswordScreen({super.key, this.args});
  final PasswordArgs? args;

  @override
  ConsumerState<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends ConsumerState<PasswordScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final args = widget.args!;
    if (_password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(authApiProvider).login(args.phone, _password.text);
      if (!mounted) return;
      switch (result) {
        case LoginSignedIn(:final tokens):
          await ref.read(sessionProvider.notifier).signedIn(tokens);
        case LoginNeedsCode(:final issue):
          unawaited(context.push(
            authRoute('/auth/otp', args.next),
            extra: OtpArgs(phone: args.phone, purpose: OtpPurpose.loginNewDevice, issue: issue, password: _password.text, next: args.next),
          ));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'invalid_credentials') {
        setState(() => _error = e.displayMessage);
      } else {
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final args = widget.args!;
    setState(() => _busy = true);
    try {
      final issue = await ref.read(authApiProvider).sendCode(args.phone, OtpPurpose.resetPassword);
      if (!mounted) return;
      unawaited(context.push(authRoute('/auth/otp', args.next), extra: OtpArgs(phone: args.phone, purpose: OtpPurpose.resetPassword, issue: issue, next: args.next)));
    } on ApiException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    if (args == null) return const _Restart(next: null);
    final t = context.gdText;
    return Scaffold(
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.chevron_left, size: 30), onPressed: () => context.pop())),
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            AuthHeading(
              overline: AuthText.step.fmt(context, {'n': 2}),
              title: AuthText.enterPassword.of(context),
              body: Text('${formatPhone(args.phone)}\n${AuthText.enterPasswordBody.of(context)}', style: t.bodyMd.copyWith(color: context.gd.inkMuted)),
            ),
            const SizedBox(height: 28),
            GdPasswordField(controller: _password, label: AuthText.password.of(context), errorText: _error, onSubmitted: (_) => _submit(), semanticsId: 'auth.password'),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: _busy ? null : _forgot, child: Text(AuthText.forgot.of(context)))),
          ],
        ),
      ),
      bottomNavigationBar: GdBottomBar(child: GdButton(label: AuthText.signIn.of(context), loading: _busy, onPressed: _submit, semanticsId: 'auth.signIn')),
    );
  }
}

/// Step 3 for a new account: name + password (`auth/set-password/`).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.args});
  final RegisterArgs? args;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  Map<String, String> _errors = const {};

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final args = widget.args!;
    setState(() {
      _busy = true;
      _errors = const {};
    });
    try {
      final settings = await ref.read(publicSettingsProvider.future);
      final tokens = await ref.read(authApiProvider).register(
            verificationToken: args.verificationToken,
            name: _name.text.trim(),
            password: _password.text,
            termsVersion: settings.termsVersion ?? '',
            language: ref.read(languageProvider),
          );
      await ref.read(sessionProvider.notifier).signedIn(tokens);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.fieldErrors.isNotEmpty && e.code == 'validation_error') {
        setState(() => _errors = e.fieldErrors);
      } else {
        showError(context, e);
        if (e.code == 'verification_invalid') context.go(authRoute('/auth', args.next));
      }
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    if (args == null) return const _Restart(next: null);
    final t = context.gdText;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            AuthHeading(
              overline: AuthText.step.fmt(context, {'n': 3}),
              title: AuthText.createAccount.of(context),
              body: Text(AuthText.createAccountBody.of(context), style: t.bodyMd.copyWith(color: context.gd.inkMuted)),
            ),
            const SizedBox(height: 28),
            Semantics(
              identifier: 'auth.name',
              textField: true,
              child: TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(labelText: AuthText.name.of(context), errorText: _errors['name']),
              ),
            ),
            const SizedBox(height: 16),
            GdPasswordField(
              controller: _password,
              label: AuthText.password.of(context),
              errorText: _errors['password'],
              newPassword: true,
              onSubmitted: (_) => _submit(),
              semanticsId: 'auth.newPassword',
            ),
            const SizedBox(height: 8),
            Text(AuthText.passwordRule.of(context), style: t.caption),
          ],
        ),
      ),
      bottomNavigationBar: GdBottomBar(child: GdButton(label: AuthText.finish.of(context), loading: _busy, onPressed: _submit, semanticsId: 'auth.register')),
    );
  }
}

/// Step 3 of "forgot password": a new password (`auth/reset-password/`).
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.args});
  final RegisterArgs? args;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final args = widget.args!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final tokens = await ref.read(authApiProvider).resetPassword(args.verificationToken, _password.text);
      await ref.read(sessionProvider.notifier).signedIn(tokens);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.fieldErrors['password'] != null) {
        setState(() => _error = e.fieldErrors['password']);
      } else {
        showError(context, e);
        if (e.code == 'verification_invalid') context.go(authRoute('/auth', args.next));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    if (args == null) return const _Restart(next: null);
    final t = context.gdText;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          AuthHeading(
            overline: AuthText.step.fmt(context, {'n': 3}),
            title: AuthText.newPassword.of(context),
            body: Text(AuthText.newPasswordBody.of(context), style: t.bodyMd.copyWith(color: context.gd.inkMuted)),
          ),
          const SizedBox(height: 28),
          GdPasswordField(controller: _password, label: AuthText.newPassword.of(context), errorText: _error, newPassword: true, onSubmitted: (_) => _submit(), semanticsId: 'auth.newPassword'),
          const SizedBox(height: 8),
          Text(AuthText.passwordRule.of(context), style: t.caption),
        ],
      ),
      bottomNavigationBar: GdBottomBar(child: GdButton(label: AuthText.savePassword.of(context), loading: _busy, onPressed: _submit, semanticsId: 'auth.savePassword')),
    );
  }
}

/// Shown when a step is opened without its arguments (e.g. a web reload).
class _Restart extends StatelessWidget {
  const _Restart({required this.next});
  final String? next;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go(authRoute('/auth', next));
    });
    return const Scaffold(body: GdLoading());
  }
}
