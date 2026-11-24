import 'dart:async';

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
import '../../../core/network/json.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../../core/widgets/product_art.dart';
import '../../../core/widgets/rings.dart';
import '../../settings/data/public_settings.dart';
import '../application/auth_channel.dart';
import '../application/session_controller.dart';
import '../data/auth_models.dart';
import '../data/social_auth.dart';
import 'auth_text.dart';
import 'auth_widgets.dart';
import 'language_sheet.dart';

/// What the entry screen does: `/auth?mode=signin|signup|reset`.
enum AuthMode {
  signIn('signin'),
  signUp('signup'),
  reset('reset');

  const AuthMode(this.query);
  final String query;

  static AuthMode fromQuery(String? value) => AuthMode.values.firstWhere(
    (m) => m.query == value,
    orElse: () => AuthMode.signIn,
  );
}

/// Arguments of the code step.
class OtpArgs {
  const OtpArgs({
    required this.identifier,
    required this.purpose,
    required this.issue,
    this.password,
    this.channels = const [],
    this.socialTicket,
    this.next,
  });

  /// What the person typed (the code may have gone to the account's other
  /// identifier, see [channels]).
  final AuthIdentifier identifier;
  final OtpPurpose purpose;
  final CodeIssue issue;

  /// The typed password, kept in memory only until the new-device step ends.
  final String? password;

  /// Where a new-device code can be sent (`NextStep.channels`).
  final List<CodeChannel> channels;

  /// The ticket of a `link_social` code (resend needs it).
  final String? socialTicket;
  final String? next;
}

/// Arguments of the details (sign-up) and new-password (reset) steps.
class RegisterArgs {
  const RegisterArgs({
    required this.identifier,
    required this.verificationToken,
    this.next,
  });
  final AuthIdentifier identifier;
  final String verificationToken;
  final String? next;
}

/// Arguments of the social completion step (`NextStep.verify_phone`).
class SocialArgs {
  const SocialArgs({required this.ticket, required this.provider, this.next});
  final String ticket;
  final SocialProvider provider;
  final String? next;
}

/// Location of an auth step, keeping `next` so the router can return there
/// once the session starts.
String authRoute(String path, String? next, {AuthMode? mode}) {
  final query = {
    if (mode != null && mode != AuthMode.signIn) 'mode': mode.query,
    'next': ?next,
  };
  return query.isEmpty
      ? path
      : Uri(path: path, queryParameters: query).toString();
}

/// Back to the entry screen without wiping what is under it.
void _backToStart(BuildContext context, String? next) =>
    context.canPop() ? context.pop() : context.go(authRoute('/auth', next));

/// Field messages for [fields] and one message for everything else, so no
/// error of the server is ever swallowed.
({Map<String, String> fields, String? message}) _splitErrors(
  BuildContext context,
  Object error,
  Set<String> fields,
) {
  if (error is ApiException && error.fieldErrors.isNotEmpty) {
    final inline = <String, String>{};
    final rest = <String>[];
    for (final e in error.fieldErrors.entries) {
      if (fields.contains(e.key)) {
        inline[e.key] = e.value;
      } else if (e.value.isNotEmpty) {
        rest.add(e.value);
      }
    }
    return (
      fields: inline,
      message: rest.isNotEmpty
          ? rest.join('\n')
          : (inline.isEmpty ? errorMessage(context, error) : null),
    );
  }
  return (fields: const {}, message: errorMessage(context, error));
}

/// The current `terms_version` (`GET settings/public/`), always re-read so a
/// version published while the app was open is the one sent; null while no
/// terms are published (sign-up is closed then).
Future<String?> freshTermsVersion(WidgetRef ref) async {
  ref.invalidate(publicSettingsProvider);
  final settings = await ref.read(publicSettingsProvider.future);
  final version = settings.termsVersion;
  return version == null || version.isEmpty ? null : version;
}

/// The "Kirish | Ro‘yxatdan o‘tish" entry screen: phone or e-mail, password
/// sign-in, sign-up by code, password reset and Google / Facebook.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.next, this.mode = AuthMode.signIn});
  final String? next;
  final AuthMode mode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

typedef _Alert = ({String message, AuthMode? switchTo});

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late AuthMode _mode = widget.mode;
  late OtpChannel _channel;
  bool _busy = false;
  SocialProvider? _socialBusy;
  String? _identifierError;
  String? _passwordError;
  _Alert? _alert;

  @override
  void initState() {
    super.initState();
    _channel = ref.read(authChannelProvider);
  }

  @override
  void didUpdateWidget(AuthScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) _mode = widget.mode;
  }

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _switchMode(AuthMode mode) => setState(() {
    _mode = mode;
    _identifierError = null;
    _passwordError = null;
    _alert = null;
    _password.clear();
  });

  void _setChannel(OtpChannel channel) {
    ref.read(authChannelProvider.notifier).set(channel);
    setState(() {
      _channel = channel;
      _identifierError = null;
      _alert = null;
    });
  }

  AuthIdentifier? _readIdentifier() {
    final id = AuthIdentifierInput.read(_channel, _phone, _email);
    if (id == null) {
      setState(
        () => _identifierError = _channel == OtpChannel.sms
            ? AuthText.phoneInvalid.of(context)
            : AuthText.emailInvalid.of(context),
      );
    }
    return id;
  }

  Future<void> _submit() async {
    if (_busy || _socialBusy != null) return;
    setState(() {
      _identifierError = null;
      _passwordError = null;
      _alert = null;
    });
    final id = _readIdentifier();
    if (id == null) return;
    if (_mode == AuthMode.signIn && _password.text.isEmpty) {
      setState(() => _passwordError = AuthText.passwordRequired.of(context));
      return;
    }
    setState(() => _busy = true);
    final auth = ref.read(authApiProvider);
    final next = widget.next;
    try {
      if (_mode == AuthMode.signIn) {
        final result = await auth.login(id, _password.text);
        if (!mounted) return;
        switch (result) {
          case LoginSignedIn(:final tokens):
            await ref.read(sessionProvider.notifier).signedIn(tokens);
          case LoginNeedsCode(:final step):
            unawaited(
              context.push(
                authRoute('/auth/otp', next),
                extra: OtpArgs(
                  identifier: id,
                  purpose: OtpPurpose.loginNewDevice,
                  issue: step.issue,
                  channels: step.channels,
                  password: _password.text,
                  next: next,
                ),
              ),
            );
        }
      } else {
        final purpose = _mode == AuthMode.signUp
            ? OtpPurpose.register
            : OtpPurpose.resetPassword;
        final issue = await auth.sendCode(id, purpose);
        if (!mounted) return;
        unawaited(
          context.push(
            authRoute('/auth/otp', next),
            extra: OtpArgs(
              identifier: id,
              purpose: purpose,
              issue: issue,
              next: next,
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) _onError(e);
    } on Object catch (e) {
      if (mounted) {
        setState(
          () => _alert = (message: errorMessage(context, e), switchTo: null),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onError(ApiException e) {
    final AuthMode? switchTo = switch (e.code) {
      'phone_registered' || 'email_registered' => AuthMode.signIn,
      'phone_not_registered' || 'email_not_registered' => AuthMode.signUp,
      _ => null,
    };
    final split = _splitErrors(context, e, const {
      'phone',
      'email',
      'password',
    });
    setState(() {
      _identifierError = split.fields['phone'] ?? split.fields['email'];
      _passwordError = split.fields['password'];
      final message = switchTo != null
          ? errorMessage(context, e)
          : split.message;
      _alert = message == null ? null : (message: message, switchTo: switchTo);
    });
  }

  Future<void> _social(SocialProvider provider) async {
    if (_busy || _socialBusy != null) return;
    setState(() {
      _socialBusy = provider;
      _alert = null;
    });
    final auth = ref.read(authApiProvider);
    var gotNonce = false;
    try {
      final nonce = await auth.socialNonce();
      gotNonce = true;
      final result = await ref
          .read(socialAuthProvider)
          .signIn(provider, nonce: nonce);
      if (!mounted) return;
      switch (result) {
        case SocialCancelled():
          return;
        case SocialCredential(:final token, :final tokenType, nonce: final n):
          final answer = await auth.social(
            provider: provider,
            token: token,
            tokenType: tokenType,
            nonce: n,
          );
          if (!mounted) return;
          switch (answer) {
            case SocialSignedIn(:final tokens):
              await ref.read(sessionProvider.notifier).signedIn(tokens);
            case SocialNeedsCompletion(:final ticket):
              unawaited(
                context.push(
                  authRoute('/auth/social', widget.next),
                  extra: SocialArgs(
                    ticket: ticket,
                    provider: provider,
                    next: widget.next,
                  ),
                ),
              );
          }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 404) {
        // Social sign-in is off on this server: hide the button(s).
        final disabled = ref.read(socialDisabledProvider.notifier);
        if (gotNonce) {
          disabled.disable(provider);
        } else {
          SocialProvider.values.forEach(disabled.disable);
        }
      }
      setState(
        () => _alert = (
          message: e.status == 404 || (e.displayMessage.isEmpty && !e.isNetwork)
              ? AuthText.socialFailed.of(context)
              : errorMessage(context, e),
          switchTo: null,
        ),
      );
    } on Object {
      if (mounted) {
        setState(
          () => _alert = (
            message: AuthText.socialFailed.of(context),
            switchTo: null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _socialBusy = null);
    }
  }

  void _close() => context.canPop() ? context.pop() : context.go('/catalog');

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final t = context.gdText;
    final language = ref.watch(languageProvider);
    final providers = ref.watch(socialProvidersProvider);
    final signIn = _mode == AuthMode.signIn;
    final (title, lead) = switch (_mode) {
      AuthMode.signIn => (AuthText.signInTitle, AuthText.signInLead),
      AuthMode.signUp => (AuthText.signUpTitle, AuthText.signUpLead),
      AuthMode.reset => (AuthText.resetTitle, AuthText.resetLead),
    };
    final alert = _alert;
    return Scaffold(
      body: Column(
        children: [
          _WelcomeHero(
            language: language,
            onLanguage: () => showLanguageSheet(context, ref),
            onClose: _close,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: AutofillGroup(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  children: [
                    if (_mode != AuthMode.reset) ...[
                      GdSegmented<AuthMode>(
                        segments: [
                          (
                            value: AuthMode.signIn,
                            label: AuthText.modeSignIn.of(context),
                            semanticsId: 'auth.mode.signin',
                          ),
                          (
                            value: AuthMode.signUp,
                            label: AuthText.modeSignUp.of(context),
                            semanticsId: 'auth.mode.signup',
                          ),
                        ],
                        selected: _mode,
                        onChanged: _switchMode,
                      ),
                      const SizedBox(height: 22),
                    ],
                    AuthHeading(
                      title: title.of(context),
                      body: Text(
                        lead.of(context),
                        style: t.bodyMd.copyWith(color: c.inkMuted),
                      ),
                    ),
                    const SizedBox(height: 22),
                    AuthIdentifierInput(
                      channel: _channel,
                      onChannel: _setChannel,
                      phone: _phone,
                      email: _email,
                      errorText: _identifierError,
                      onSubmitted: signIn ? null : _submit,
                    ),
                    if (signIn) ...[
                      const SizedBox(height: 16),
                      GdPasswordField(
                        controller: _password,
                        label: AuthText.password.of(context),
                        errorText: _passwordError,
                        onSubmitted: (_) => _submit(),
                        semanticsId: 'auth.password',
                      ),
                    ],
                    if (alert != null) ...[
                      const SizedBox(height: 16),
                      AuthAlert(
                        message: alert.message,
                        actionLabel: switch (alert.switchTo) {
                          AuthMode.signIn => AuthText.signIn.of(context),
                          AuthMode.signUp => AuthText.signUpAction.of(context),
                          _ => null,
                        },
                        actionSemanticsId: 'auth.message.action',
                        onAction: alert.switchTo == null
                            ? null
                            : () => _switchMode(alert.switchTo!),
                      ),
                    ],
                    const SizedBox(height: 20),
                    GdButton(
                      label: signIn
                          ? AuthText.signIn.of(context)
                          : AuthText.getCode.of(context),
                      loading: _busy,
                      onPressed: _submit,
                      semanticsId: signIn ? 'auth.signIn' : 'auth.getCode',
                    ),
                    if (!signIn) ...[
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          AuthText.codeValid.of(context),
                          style: t.caption,
                        ),
                      ),
                    ],
                    if (_mode != AuthMode.signUp) ...[
                      const SizedBox(height: 6),
                      Center(
                        child: Semantics(
                          identifier: signIn
                              ? 'auth.forgot'
                              : 'auth.backToSignIn',
                          button: true,
                          child: TextButton(
                            onPressed: () => _switchMode(
                              signIn ? AuthMode.reset : AuthMode.signIn,
                            ),
                            child: Text(
                              signIn
                                  ? AuthText.forgot.of(context)
                                  : AuthText.resetBack.of(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_mode != AuthMode.reset && providers.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const AuthDivider(),
                      const SizedBox(height: 16),
                      for (final p in providers) ...[
                        SocialButton(
                          provider: p,
                          loading: _socialBusy == p,
                          onPressed: _busy || _socialBusy != null
                              ? null
                              : () => _social(p),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({
    required this.language,
    required this.onLanguage,
    required this.onClose,
  });
  final AppLanguage language;
  final VoidCallback onLanguage;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(GdRadius.lg),
      ),
      child: Container(
        color: c.banner,
        height: 220 + MediaQuery.paddingOf(context).top,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: MediaQuery.paddingOf(context).top - 60,
              bottom: -160,
              child: GdRings(
                color: c.gold.withValues(alpha: 0.75),
                count: 4,
                strokeWidth: 1.2,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 22,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  ProductArt(kind: ProductArtKind.dropper, size: 48),
                  SizedBox(width: 18),
                  ProductArt(kind: ProductArtKind.pump, size: 74),
                  SizedBox(width: 18),
                  ProductArt(kind: ProductArtKind.jar, size: 52),
                ],
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                child: Row(
                  children: [
                    Semantics(
                      identifier: 'auth.close',
                      button: true,
                      child: IconButton(
                        onPressed: onClose,
                        icon: Icon(Icons.close, color: c.bannerInkSoft),
                        tooltip: Strings.close.of(context),
                      ),
                    ),
                    GdWordmark(
                      color: c.bannerInk,
                      size: 28,
                      onTap: () => context.go('/catalog'),
                    ),
                    const Spacer(),
                    Semantics(
                      identifier: 'auth.language',
                      button: true,
                      child: OutlinedButton(
                        onPressed: onLanguage,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          foregroundColor: c.bannerInkSoft,
                          side: BorderSide(
                            color: c.bannerInkSoft.withValues(alpha: 0.4),
                          ),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              language.label,
                              style: context.gdText.label.copyWith(
                                color: c.bannerInkSoft,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 20,
                              color: c.bannerInkSoft,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Back chevron of the inner auth steps: pops, or opens the entry screen
/// when there is nothing under (a reload on the web).
class _BackButton extends StatelessWidget {
  const _BackButton({required this.next, this.onPressed});
  final String? next;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: Strings.back.of(context),
    icon: const Icon(Icons.chevron_left, size: 30),
    onPressed: onPressed ?? () => _backToStart(context, next),
  );
}

/// "Kodni kiriting": the code sent by SMS or e-mail for sign-up, a new
/// device, a password reset or linking a social profile.
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
  int? _attemptsLeft;
  late CodeIssue _issue;

  /// Where the new-device code was last asked for ("Kodni e-mailga
  /// yuborish"); null = where the person signed in with.
  OtpChannel? _otpChannel;
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

  /// The other place a new-device code can go, when the account has two
  /// (`NextStep.channels`, newer backends).
  OtpChannel? get _otherChannel {
    final args = widget.args!;
    if (args.purpose != OtpPurpose.loginNewDevice ||
        args.channels.length != 2) {
      return null;
    }
    for (final c in args.channels) {
      if (c.channel != _issue.channel) return c.channel;
    }
    return null;
  }

  /// A new code: `auth/login/` again for a new device (contract §2.1.4),
  /// `send-code` otherwise. [channel] moves a new-device code.
  Future<void> _resend({OtpChannel? channel}) async {
    final args = widget.args!;
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _attemptsLeft = null;
      _error = false;
    });
    try {
      final auth = ref.read(authApiProvider);
      if (args.purpose == OtpPurpose.loginNewDevice) {
        final wanted = channel ?? _otpChannel;
        final result = await auth.login(
          args.identifier,
          args.password ?? '',
          otpChannel: wanted,
        );
        switch (result) {
          case LoginSignedIn(:final tokens):
            await ref.read(sessionProvider.notifier).signedIn(tokens);
            return;
          case LoginNeedsCode(:final issue):
            _issue = issue;
            _otpChannel = wanted;
        }
      } else {
        _issue = await auth.sendCode(
          args.identifier,
          args.purpose,
          socialTicket: args.socialTicket,
        );
      }
      if (!mounted) return;
      _startTimer(_issue.resendIn);
      _field.currentState?.clear();
      showSnack(context, AuthText.codeResent.of(context));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.retryAfter != null) _startTimer(e.retryAfter!);
      setState(() => _message = errorMessage(context, e));
    } on Object catch (e) {
      if (mounted) setState(() => _message = errorMessage(context, e));
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
      _attemptsLeft = null;
    });
    final auth = ref.read(authApiProvider);
    final newDevice = args.purpose == OtpPurpose.loginNewDevice;
    try {
      final verified = await auth.verifyCode(
        args.identifier,
        args.purpose,
        _code,
        otpChannel: newDevice ? _otpChannel : null,
      );
      if (!mounted) return;
      final details = RegisterArgs(
        identifier: args.identifier,
        verificationToken: verified.token,
        next: args.next,
      );
      switch (args.purpose) {
        case OtpPurpose.register:
          context.pushReplacement(
            authRoute('/auth/register', args.next),
            extra: details,
          );
        case OtpPurpose.resetPassword:
          context.pushReplacement(
            authRoute('/auth/reset', args.next),
            extra: details,
          );
        case OtpPurpose.linkSocial:
          context.pop(verified);
        case OtpPurpose.loginNewDevice:
          final result = await auth.login(
            args.identifier,
            args.password ?? '',
            verificationToken: verified.token,
            otpChannel: _otpChannel,
          );
          if (result is LoginSignedIn) {
            await ref.read(sessionProvider.notifier).signedIn(result.tokens);
          }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'verification_invalid' ||
          e.code == 'invalid_credentials' ||
          e.code == 'social_ticket_invalid') {
        showSnack(
          context,
          e.displayMessage.isEmpty
              ? AuthText.restart.of(context)
              : e.displayMessage,
        );
        _backToStart(context, args.next);
        return;
      }
      setState(() {
        _error = true;
        _message = e.fieldErrors['code'] ?? errorMessage(context, e);
        _attemptsLeft = asIntOrNull(e.details['attempts_left']);
      });
      if (e.code == 'otp_locked' && e.retryAfter != null) {
        _startTimer(e.retryAfter!);
      }
    } on Object catch (e) {
      if (mounted) setState(() => _message = errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    if (args == null) return const _Restart(next: null);
    final c = context.gd;
    final t = context.gdText;
    final complete = _code.length == _issue.length;
    final newDevice = args.purpose == OtpPurpose.loginNewDevice;
    final mask = _issue.mask.isNotEmpty
        ? _issue.mask
        : (args.identifier.isEmail
              ? args.identifier.value
              : formatPhone(args.identifier.value));
    final sent =
        (_issue.channel == OtpChannel.email
                ? AuthText.codeSentEmail
                : AuthText.codeSentSms)
            .fmt(context, {'mask': mask, 'n': _issue.length});
    final other = _otherChannel;
    return Scaffold(
      appBar: AppBar(leading: _BackButton(next: args.next)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          AuthHeading(
            title: newDevice
                ? AuthText.newDeviceTitle.of(context)
                : AuthText.enterCode.of(context),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (newDevice) ...[
                  Text(
                    AuthText.newDeviceLead.of(context),
                    style: t.bodyMd.copyWith(color: c.inkMuted),
                  ),
                  const SizedBox(height: 8),
                ],
                Semantics(
                  identifier: 'auth.otp.sentTo',
                  child: Text(
                    sent,
                    style: t.bodyMd.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => _backToStart(context, args.next),
              child: Container(
                padding: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.gold, width: 1.5)),
                ),
                child: Text(
                  args.identifier.isEmail
                      ? AuthText.changeEmail.of(context)
                      : AuthText.changeNumber.of(context),
                  style: t.label,
                ),
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
              _attemptsLeft = null;
            }),
            onCompleted: (_) => _submit(),
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Semantics(
              identifier: 'auth.message',
              liveRegion: true,
              child: Text(_message!, style: t.bodySm.copyWith(color: c.danger)),
            ),
          ],
          if (_attemptsLeft != null) ...[
            const SizedBox(height: 4),
            Text(
              AuthText.attemptsLeft.fmt(context, {'n': _attemptsLeft!}),
              style: t.caption.copyWith(color: c.danger),
            ),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Icon(Icons.schedule, size: 20, color: c.inkMuted),
              const SizedBox(width: 8),
              if (_resendLeft > 0) ...[
                Flexible(
                  child: Text(AuthText.resendIn.of(context), style: t.bodySm),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_resendLeft ~/ 60}:${(_resendLeft % 60).toString().padLeft(2, '0')}',
                  style: t.label,
                ),
              ] else
                Semantics(
                  identifier: 'auth.resend',
                  button: true,
                  child: TextButton(
                    onPressed: _busy ? null : _resend,
                    child: Text(AuthText.resend.of(context)),
                  ),
                ),
            ],
          ),
          if (other != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                identifier: 'auth.otp.otherChannel',
                button: true,
                child: TextButton.icon(
                  onPressed: _busy ? null : () => _resend(channel: other),
                  icon: Icon(
                    other == OtpChannel.email
                        ? Icons.mail_outline_rounded
                        : Icons.sms_outlined,
                    size: 20,
                  ),
                  label: Text(
                    other == OtpChannel.email
                        ? AuthText.sendToEmail.of(context)
                        : AuthText.sendBySms.of(context),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: GdBottomBar(
        child: GdButton(
          label: AuthText.confirm.of(context),
          loading: _busy,
          onPressed: complete ? _submit : null,
          semanticsId: 'auth.confirm',
        ),
      ),
    );
  }
}

/// Sign-up details after the code: name, password and the terms consent
/// (`auth/set-password/`).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.args});
  final RegisterArgs? args;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _password = TextEditingController();
  bool _agreed = false;
  bool _busy = false;
  Map<String, String> _errors = const {};
  String? _termsError;
  String? _message;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final args = widget.args!;
    if (_busy) return;
    if (!_agreed) {
      setState(() => _termsError = AuthText.consentRequired.of(context));
      return;
    }
    setState(() {
      _busy = true;
      _errors = const {};
      _termsError = null;
      _message = null;
    });
    try {
      final version = await freshTermsVersion(ref);
      if (!mounted) return;
      if (version == null) {
        setState(() => _message = AuthText.termsUnavailable.of(context));
        return;
      }
      final tokens = await ref
          .read(authApiProvider)
          .register(
            verificationToken: args.verificationToken,
            name: _name.text.trim(),
            password: _password.text,
            termsVersion: version,
            language: ref.read(languageProvider),
          );
      await ref.read(sessionProvider.notifier).signedIn(tokens);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'verification_invalid') {
        showError(context, e);
        _backToStart(context, args.next);
        return;
      }
      final split = _splitErrors(context, e, const {
        'name',
        'password',
        'terms_version',
      });
      final outdated = e.fieldCodes['terms_version'] == 'terms_outdated';
      setState(() {
        _errors = split.fields;
        _message = split.message;
        final terms = split.fields['terms_version'];
        if (outdated) {
          // New terms were published meanwhile: they must be accepted anew.
          _agreed = false;
          _termsError = [
            if (terms != null && terms.isNotEmpty) terms,
            AuthText.termsUpdated.of(context),
          ].join('\n');
        } else {
          _termsError = terms;
        }
      });
      if (outdated) {
        try {
          await freshTermsVersion(ref);
        } on Object {
          // read again on the next tap
        }
      }
    } on Object catch (e) {
      if (mounted) setState(() => _message = errorMessage(context, e));
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
      appBar: AppBar(leading: _BackButton(next: args.next)),
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            AuthHeading(
              title: AuthText.detailsTitle.of(context),
              body: Text(
                AuthText.createAccountBody.of(context),
                style: t.bodyMd.copyWith(color: context.gd.inkMuted),
              ),
            ),
            const SizedBox(height: 28),
            _NameField(controller: _name, errorText: _errors['name']),
            const SizedBox(height: 16),
            GdPasswordField(
              controller: _password,
              label: AuthText.password.of(context),
              errorText: _errors['password'],
              newPassword: true,
              semanticsId: 'auth.newPassword',
            ),
            const SizedBox(height: 8),
            Text(AuthText.passwordRule.of(context), style: t.caption),
            const SizedBox(height: 22),
            TermsConsent(
              value: _agreed,
              errorText: _termsError,
              onChanged: (v) => setState(() {
                _agreed = v;
                _termsError = null;
              }),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              AuthAlert(message: _message!),
            ],
          ],
        ),
      ),
      bottomNavigationBar: GdBottomBar(
        child: GdButton(
          label: AuthText.create.of(context),
          loading: _busy,
          onPressed: _submit,
          semanticsId: 'auth.register',
        ),
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller, this.errorText});
  final TextEditingController controller;
  final String? errorText;

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: 'auth.name',
    textField: true,
    child: TextField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      autofillHints: const [AutofillHints.name],
      decoration: InputDecoration(
        labelText: AuthText.name.of(context),
        hintText: AuthText.namePlaceholder.of(context),
        errorText: errorText,
        errorMaxLines: 3,
      ),
    ),
  );
}

/// The new password of "forgot password" (`auth/reset-password/`, which
/// also signs in).
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.args});
  final RegisterArgs? args;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _repeatError;
  String? _message;

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final args = widget.args!;
    if (_busy) return;
    setState(() {
      _error = null;
      _repeatError = null;
      _message = null;
    });
    if (_password.text != _repeat.text) {
      setState(() => _repeatError = AuthText.passwordsDiffer.of(context));
      return;
    }
    setState(() => _busy = true);
    try {
      final tokens = await ref
          .read(authApiProvider)
          .resetPassword(args.verificationToken, _password.text);
      await ref.read(sessionProvider.notifier).signedIn(tokens);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'verification_invalid') {
        showError(context, e);
        _backToStart(context, args.next);
        return;
      }
      final split = _splitErrors(context, e, const {'password'});
      setState(() {
        _error = split.fields['password'];
        _message = split.message;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _message = errorMessage(context, e));
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
      appBar: AppBar(leading: _BackButton(next: args.next)),
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            AuthHeading(
              title: AuthText.newPassword.of(context),
              body: Text(
                AuthText.newPasswordBody.of(context),
                style: t.bodyMd.copyWith(color: context.gd.inkMuted),
              ),
            ),
            const SizedBox(height: 28),
            GdPasswordField(
              controller: _password,
              label: AuthText.newPassword.of(context),
              errorText: _error,
              newPassword: true,
              semanticsId: 'auth.newPassword',
            ),
            const SizedBox(height: 8),
            Text(AuthText.passwordRule.of(context), style: t.caption),
            const SizedBox(height: 16),
            GdPasswordField(
              controller: _repeat,
              label: AuthText.repeatPassword.of(context),
              errorText: _repeatError,
              newPassword: true,
              onSubmitted: (_) => _submit(),
              semanticsId: 'auth.newPasswordRepeat',
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              AuthAlert(message: _message!),
            ],
          ],
        ),
      ),
      bottomNavigationBar: GdBottomBar(
        child: GdButton(
          label: AuthText.savePassword.of(context),
          loading: _busy,
          onPressed: _submit,
          semanticsId: 'auth.savePassword',
        ),
      ),
    );
  }
}

enum _SocialStep { choose, link, finishNew, password }

/// "Hisobingizni yakunlang" after `auth/social/` answered `verify_phone`:
/// continue without a phone now, or link a phone or e-mail by code (an
/// existing account asks for its password when it has one).
class SocialCompleteScreen extends ConsumerStatefulWidget {
  const SocialCompleteScreen({super.key, this.args});
  final SocialArgs? args;

  @override
  ConsumerState<SocialCompleteScreen> createState() =>
      _SocialCompleteScreenState();
}

class _SocialCompleteScreenState extends ConsumerState<SocialCompleteScreen> {
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  late OtpChannel _channel;
  _SocialStep _step = _SocialStep.choose;
  bool _agreed = false;
  bool _busy = false;
  String? _token;
  Map<String, String> _errors = const {};
  String? _termsError;
  String? _identifierError;
  String? _message;

  @override
  void initState() {
    super.initState();
    _channel = ref.read(authChannelProvider);
  }

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _goTo(_SocialStep step) => setState(() {
    _step = step;
    _errors = const {};
    _termsError = null;
    _identifierError = null;
    _message = null;
  });

  Future<void> _run(Future<void> Function() body) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errors = const {};
      _identifierError = null;
      _message = null;
    });
    try {
      await body();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'social_ticket_invalid') {
        showError(context, e);
        _backToStart(context, widget.args?.next);
        return;
      }
      final split = _splitErrors(context, e, const {
        'name',
        'password',
        'terms_version',
        'phone',
        'email',
      });
      setState(() {
        _errors = split.fields;
        _termsError = split.fields['terms_version'];
        _identifierError = split.fields['phone'] ?? split.fields['email'];
        _message = split.message;
        if (e.fieldCodes['terms_version'] == 'terms_outdated') {
          _agreed = false;
          _termsError = AuthText.termsUpdated.of(context);
        }
      });
    } on Object catch (e) {
      if (mounted) setState(() => _message = errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Name and terms of a new account (skip, or a link to a new identifier).
  Future<void> _completeNew({String? token}) async {
    if (!_agreed) {
      setState(() => _termsError = AuthText.consentRequired.of(context));
      return;
    }
    setState(() => _termsError = null);
    await _run(() async {
      final version = await freshTermsVersion(ref);
      if (!mounted) return;
      if (version == null) {
        setState(() => _message = AuthText.termsUnavailable.of(context));
        return;
      }
      final tokens = await ref
          .read(authApiProvider)
          .socialComplete(
            socialTicket: widget.args!.ticket,
            verificationToken: token,
            name: _name.text.trim(),
            termsVersion: version,
            language: ref.read(languageProvider),
          );
      await ref.read(sessionProvider.notifier).signedIn(tokens);
    });
  }

  Future<void> _sendLinkCode() async {
    final args = widget.args!;
    final id = AuthIdentifierInput.read(_channel, _phone, _email);
    if (id == null) {
      setState(
        () => _identifierError = _channel == OtpChannel.sms
            ? AuthText.phoneInvalid.of(context)
            : AuthText.emailInvalid.of(context),
      );
      return;
    }
    Verification? verified;
    await _run(() async {
      final issue = await ref
          .read(authApiProvider)
          .sendCode(id, OtpPurpose.linkSocial, socialTicket: args.ticket);
      if (!mounted) return;
      verified = await context.push<Verification>(
        authRoute('/auth/otp', args.next),
        extra: OtpArgs(
          identifier: id,
          purpose: OtpPurpose.linkSocial,
          issue: issue,
          socialTicket: args.ticket,
          next: args.next,
        ),
      );
    });
    final v = verified;
    if (v == null || !mounted) return;
    _token = v.token;
    if (!v.customerExists) {
      _goTo(_SocialStep.finishNew);
    } else {
      await _completeExisting();
    }
  }

  /// An existing account: linked at once, or its password is asked.
  Future<void> _completeExisting({String? password}) async {
    final args = widget.args!;
    var needsPassword = false;
    await _run(() async {
      try {
        final tokens = await ref
            .read(authApiProvider)
            .socialComplete(
              socialTicket: args.ticket,
              verificationToken: _token,
              password: password,
              language: ref.read(languageProvider),
            );
        await ref.read(sessionProvider.notifier).signedIn(tokens);
      } on ApiException catch (e) {
        if (password == null && e.fieldErrors.containsKey('password')) {
          needsPassword = true;
          return;
        }
        rethrow;
      }
    });
    if (needsPassword && mounted) _goTo(_SocialStep.password);
  }

  void _back() {
    if (_step == _SocialStep.choose) {
      _backToStart(context, widget.args?.next);
    } else {
      _goTo(_SocialStep.choose);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    if (args == null) return const _Restart(next: null);
    final c = context.gd;
    final t = context.gdText;
    Widget lead(Tr text) =>
        Text(text.of(context), style: t.bodyMd.copyWith(color: c.inkMuted));
    final consent = TermsConsent(
      value: _agreed,
      errorText: _termsError,
      onChanged: (v) => setState(() {
        _agreed = v;
        _termsError = null;
      }),
    );
    final children = switch (_step) {
      _SocialStep.choose => [
        AuthHeading(
          title: AuthText.completeTitle.of(context),
          body: lead(AuthText.completeLead),
        ),
        const SizedBox(height: 24),
        _NameField(controller: _name, errorText: _errors['name']),
        const SizedBox(height: 20),
        consent,
      ],
      _SocialStep.link => [
        AuthHeading(
          title: AuthText.socialLink.of(context),
          body: lead(AuthText.linkLead),
        ),
        const SizedBox(height: 24),
        AuthIdentifierInput(
          channel: _channel,
          onChannel: (ch) {
            ref.read(authChannelProvider.notifier).set(ch);
            setState(() {
              _channel = ch;
              _identifierError = null;
            });
          },
          phone: _phone,
          email: _email,
          errorText: _identifierError,
          onSubmitted: _sendLinkCode,
        ),
      ],
      _SocialStep.finishNew => [
        AuthHeading(title: AuthText.completeTitle.of(context)),
        const SizedBox(height: 24),
        _NameField(controller: _name, errorText: _errors['name']),
        const SizedBox(height: 20),
        consent,
      ],
      _SocialStep.password => [
        AuthHeading(
          title: AuthText.completeTitle.of(context),
          body: lead(AuthText.existingPasswordHint),
        ),
        const SizedBox(height: 24),
        GdPasswordField(
          controller: _password,
          label: AuthText.existingPassword.of(context),
          errorText: _errors['password'],
          onSubmitted: (_) => _completeExisting(password: _password.text),
          semanticsId: 'auth.password',
        ),
      ],
    };
    final bottom = switch (_step) {
      _SocialStep.choose => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GdButton(
            label: AuthText.socialSkip.of(context),
            loading: _busy,
            onPressed: () => _completeNew(),
            semanticsId: 'auth.social.skip',
          ),
          const SizedBox(height: 10),
          GdOutlineButton(
            label: AuthText.socialLink.of(context),
            onPressed: _busy ? null : () => _goTo(_SocialStep.link),
            semanticsId: 'auth.social.link',
          ),
        ],
      ),
      _SocialStep.link => GdButton(
        label: AuthText.getCode.of(context),
        loading: _busy,
        onPressed: _sendLinkCode,
        semanticsId: 'auth.getCode',
      ),
      _SocialStep.finishNew => GdButton(
        label: AuthText.create.of(context),
        loading: _busy,
        onPressed: () => _completeNew(token: _token),
        semanticsId: 'auth.register',
      ),
      _SocialStep.password => GdButton(
        label: AuthText.confirm.of(context),
        loading: _busy,
        onPressed: () => _completeExisting(password: _password.text),
        semanticsId: 'auth.confirm',
      ),
    };
    return PopScope(
      canPop: _step == _SocialStep.choose,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(_SocialStep.choose);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _BackButton(next: args.next, onPressed: _back),
        ),
        body: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              ...children,
              if (_message != null) ...[
                const SizedBox(height: 16),
                AuthAlert(message: _message!),
              ],
            ],
          ),
        ),
        bottomNavigationBar: GdBottomBar(child: bottom),
      ),
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
