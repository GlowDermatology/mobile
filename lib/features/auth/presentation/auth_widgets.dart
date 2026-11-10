import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/format/phone.dart';

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
