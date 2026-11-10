import 'package:flutter/material.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';

/// A selectable card with a radio on the right, like the payment-method
/// cards of the design (PDF page 6): gold-tinted with a gold border when
/// selected.
class GdOptionCard extends StatelessWidget {
  const GdOptionCard({
    super.key,
    required this.selected,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.footer,
    this.onTap,
    this.semanticsId,
    this.dimmed = false,
  });

  final bool selected;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget? footer;
  final VoidCallback? onTap;
  final String? semanticsId;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final t = context.gdText;
    final radius = BorderRadius.circular(GdRadius.lg - 4);
    return Semantics(
      identifier: semanticsId,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? c.goldSoft : c.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? c.gold : c.lineStrong,
            width: selected ? 1.6 : 1.2,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(GdRadius.md),
                        ),
                        child: Icon(
                          icon,
                          size: 22,
                          color: dimmed ? c.inkMuted : c.goldInk,
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: t.subheading.copyWith(
                              color: dimmed ? c.inkMuted : c.ink,
                            ),
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(subtitle!, style: t.bodySm),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                    const SizedBox(width: 10),
                    GdRadio(selected: selected, enabled: !dimmed),
                  ],
                ),
                ?footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The round radio of the design.
class GdRadio extends StatelessWidget {
  const GdRadio({super.key, required this.selected, this.enabled = true});
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? c.goldInk
              : (enabled ? c.ink.withValues(alpha: 0.6) : c.line),
          width: 1.4,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: c.goldInk,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

/// Section heading inside checkout ("Olish usuli").
class CheckoutSection extends StatelessWidget {
  const CheckoutSection({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: context.gdText.heading),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

/// Inline error under a section.
class InlineError extends StatelessWidget {
  const InlineError(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: c.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: context.gdText.bodySm.copyWith(color: c.danger),
            ),
          ),
        ],
      ),
    );
  }
}
