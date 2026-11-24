import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/format/email.dart';
import '../../../core/format/phone.dart';
import '../data/auth_models.dart';
import 'auth_text.dart';

/// "+998 | 90 123 45 67" field of the welcome screen.
class GdPhoneField extends StatelessWidget {
  const GdPhoneField({
    super.key,
    required this.controller,
    this.onSubmitted,
    this.errorText,
    this.autofocus = false,
  });
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    return Semantics(
      identifier: 'auth.phone',
      textField: true,
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumberNational],
        inputFormatters: [_NationalPhoneFormatter()],
        style: context.gdText.bodyMd.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: '90 123 45 67',
          errorText: errorText,
          prefixIcon: Container(
            width: 72,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: c.lineStrong)),
            ),
            alignment: Alignment.center,
            child: Text(
              '+998',
              style: context.gdText.bodyMd.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 12,
          ),
        ),
      ),
    );
  }
}

class _NationalPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final masked = maskNational(newValue.text);
    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: masked.length),
    );
  }
}

/// Six separate boxes over one real text field (so paste and SMS autofill
/// work).
class GdOtpField extends StatefulWidget {
  const GdOtpField({
    super.key,
    required this.length,
    required this.onChanged,
    this.onCompleted,
    this.error = false,
    this.enabled = true,
  });
  final int length;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final bool error;
  final bool enabled;

  @override
  State<GdOtpField> createState() => GdOtpFieldState();
}

class GdOtpFieldState extends State<GdOtpField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  void clear() {
    _controller.clear();
    widget.onChanged('');
    _focus.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final box =
            ((constraints.maxWidth - gap * (widget.length - 1)) / widget.length)
                .clamp(36.0, 56.0);
        return SizedBox(
          height: box * 1.15,
          child: Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < widget.length; i++)
                    ValueListenableBuilder(
                      valueListenable: _controller,
                      builder: (context, value, _) {
                        final text = value.text;
                        final filled = i < text.length;
                        final active =
                            _focus.hasFocus &&
                            (i == text.length ||
                                (i == widget.length - 1 &&
                                    text.length == widget.length));
                        return Container(
                          width: box,
                          height: box * 1.15,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.surfaceRaised,
                            borderRadius: BorderRadius.circular(GdRadius.md),
                            border: Border.all(
                              color: widget.error
                                  ? c.danger
                                  : (active ? c.goldInk : c.lineStrong),
                              width: active || widget.error ? 2 : 1.2,
                            ),
                          ),
                          child: Text(
                            filled ? text[i] : '',
                            style: context.gdText.priceLg.copyWith(
                              fontSize: 24,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
              Positioned.fill(
                child: Semantics(
                  identifier: 'auth.otp',
                  textField: true,
                  child: Opacity(
                    opacity: 0.011,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      enabled: widget.enabled,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      maxLength: widget.length,
                      showCursor: false,
                      enableInteractiveSelection: false,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        filled: false,
                      ),
                      onChanged: (v) {
                        setState(() {});
                        widget.onChanged(v);
                        if (v.length == widget.length) {
                          widget.onCompleted?.call(v);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Password field with a show/hide toggle.
class GdPasswordField extends StatefulWidget {
  const GdPasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.errorText,
    this.onSubmitted,
    this.newPassword = false,
    this.semanticsId,
  });
  final TextEditingController controller;
  final String label;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;
  final bool newPassword;
  final String? semanticsId;

  @override
  State<GdPasswordField> createState() => _GdPasswordFieldState();
}

class _GdPasswordFieldState extends State<GdPasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: widget.semanticsId,
    textField: true,
    child: TextField(
      controller: widget.controller,
      obscureText: _hidden,
      autofillHints: [
        widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
      ],
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        errorMaxLines: 3,
        suffixIcon: IconButton(
          icon: Icon(
            _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      ),
    ),
  );
}

/// Overline + display title + body, used by every auth step.
class AuthHeading extends StatelessWidget {
  const AuthHeading({super.key, this.overline, required this.title, this.body});
  final String? overline;
  final String title;
  final Widget? body;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (overline != null) ...[
        Text(overline!, style: context.gdText.overline),
        const SizedBox(height: 8),
      ],
      Text(title, style: context.gdText.displayLg),
      if (body != null) ...[const SizedBox(height: 10), body!],
    ],
  );
}

/// E-mail address field: e-mail keyboard and autofill, no autocorrect or
/// capitals, at most 254 characters; the value is trimmed and lower-cased
/// when read ([toEmail]).
class GdEmailField extends StatelessWidget {
  const GdEmailField({
    super.key,
    required this.controller,
    this.onSubmitted,
    this.errorText,
    this.autofocus = false,
  });
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: 'auth.email',
    textField: true,
    child: TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      inputFormatters: [
        FilteringTextInputFormatter.deny(RegExp(r'\s')),
        LengthLimitingTextInputFormatter(emailMaxLength),
      ],
      style: context.gdText.bodyMd.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: AuthText.emailHint.of(context),
        errorText: errorText,
        prefixIcon: const Icon(Icons.mail_outline_rounded),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 12,
        ),
      ),
    ),
  );
}

/// One option of a [GdSegmented] control.
typedef GdSegment<T> = ({T value, String label, String semanticsId});

/// Two or three equal options on a soft gold track (the website's tab list):
/// "Kirish | Ro‘yxatdan o‘tish", "Telefon | E-mail".
class GdSegmented<T> extends StatelessWidget {
  const GdSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.height = 44,
  });
  final List<GdSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.goldSoft,
        borderRadius: BorderRadius.circular(GdRadius.md),
      ),
      child: Row(
        children: [
          for (final s in segments)
            Expanded(
              child: Semantics(
                identifier: s.semanticsId,
                button: true,
                selected: s.value == selected,
                label: s.label,
                excludeSemantics: true,
                child: Material(
                  color: s.value == selected
                      ? c.surfaceRaised
                      : Colors.transparent,
                  elevation: s.value == selected ? 1 : 0,
                  borderRadius: BorderRadius.circular(GdRadius.sm + 1),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(GdRadius.sm + 1),
                    onTap: () => onChanged(s.value),
                    child: SizedBox(
                      height: height - 8,
                      child: Center(
                        child: Text(
                          s.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.gdText.label,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Telefon | E-mail" switch over the matching field. Each channel keeps its
/// own controller, so switching back and forth loses nothing.
class AuthIdentifierInput extends StatelessWidget {
  const AuthIdentifierInput({
    super.key,
    required this.channel,
    required this.onChannel,
    required this.phone,
    required this.email,
    this.errorText,
    this.onSubmitted,
  });
  final OtpChannel channel;
  final ValueChanged<OtpChannel> onChannel;
  final TextEditingController phone;
  final TextEditingController email;
  final String? errorText;
  final VoidCallback? onSubmitted;

  /// The identifier typed for [channel], or null when it is incomplete.
  static AuthIdentifier? read(
    OtpChannel channel,
    TextEditingController phone,
    TextEditingController email,
  ) => switch (channel) {
    OtpChannel.sms => switch (toE164(phone.text)) {
      final p? => AuthIdentifier.phone(p),
      null => null,
    },
    OtpChannel.email => switch (toEmail(email.text)) {
      final e? => AuthIdentifier.email(e),
      null => null,
    },
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      GdSegmented<OtpChannel>(
        height: 40,
        segments: [
          (
            value: OtpChannel.sms,
            label: AuthText.channelPhone.of(context),
            semanticsId: 'auth.channel.phone',
          ),
          (
            value: OtpChannel.email,
            label: AuthText.channelEmail.of(context),
            semanticsId: 'auth.channel.email',
          ),
        ],
        selected: channel,
        onChanged: onChannel,
      ),
      const SizedBox(height: 14),
      Text(
        channel == OtpChannel.sms
            ? AuthText.phone.of(context)
            : AuthText.email.of(context),
        style: context.gdText.label,
      ),
      const SizedBox(height: 8),
      if (channel == OtpChannel.sms)
        GdPhoneField(
          controller: phone,
          errorText: errorText,
          onSubmitted: (_) => onSubmitted?.call(),
        )
      else
        GdEmailField(
          controller: email,
          errorText: errorText,
          onSubmitted: (_) => onSubmitted?.call(),
        ),
    ],
  );
}

/// "Men Foydalanish shartlari va Maxfiylik siyosatini qabul qilaman" with the
/// links to the legal pages. Only on sign-up and the social completion.
class TermsConsent extends StatelessWidget {
  const TermsConsent({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final t = context.gdText;
    final link = t.bodySm.copyWith(
      color: c.ink,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: c.gold,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Semantics(
                identifier: 'auth.consent',
                child: Checkbox(
                  value: value,
                  isError: errorText != null,
                  onChanged: (v) => onChanged(v ?? false),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: t.bodySm.copyWith(color: c.ink),
                  children: [
                    TextSpan(text: AuthText.consentBefore.of(context)),
                    TextSpan(
                      text: AuthText.terms.of(context),
                      style: link,
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => context.push('/settings/legal/terms'),
                    ),
                    TextSpan(text: AuthText.consentMiddle.of(context)),
                    TextSpan(
                      text: AuthText.privacy.of(context),
                      style: link,
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => context.push('/settings/legal/privacy'),
                    ),
                    TextSpan(text: AuthText.consentAfter.of(context)),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: t.bodySm.copyWith(
              color: c.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// An inline message of a form (a refused sign-in, a sent-code limit), with
/// an optional action ("Kirish" after `phone_registered`).
class AuthAlert extends StatelessWidget {
  const AuthAlert({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionSemanticsId,
  });
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? actionSemanticsId;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    return Semantics(
      identifier: 'auth.message',
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: c.dangerSoft,
          borderRadius: BorderRadius.circular(GdRadius.md),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: c.dangerStrong, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: context.gdText.bodySm.copyWith(
                  color: c.dangerStrong,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null)
              Semantics(
                identifier: actionSemanticsId,
                button: true,
                child: TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "yoki" between two lines.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    return Row(
      children: [
        Expanded(child: Divider(color: c.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            AuthText.or.of(context).toUpperCase(),
            style: context.gdText.caption,
          ),
        ),
        Expanded(child: Divider(color: c.line)),
      ],
    );
  }
}

/// "Google bilan davom etish" / "Facebook bilan davom etish".
class SocialButton extends StatelessWidget {
  const SocialButton({
    super.key,
    required this.provider,
    required this.onPressed,
    this.loading = false,
  });
  final SocialProvider provider;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final (label, mark, color) = switch (provider) {
      SocialProvider.google => (
        AuthText.google.of(context),
        'G',
        const Color(0xFF4285F4),
      ),
      SocialProvider.facebook => (
        AuthText.facebook.of(context),
        'f',
        const Color(0xFF1877F2),
      ),
    };
    return Semantics(
      identifier: 'auth.social.${provider.code}',
      button: true,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: c.ink,
          side: BorderSide(color: c.lineStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GdRadius.md),
          ),
        ),
        child: loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      mark,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.gdText.label,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
