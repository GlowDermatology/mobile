import 'package:flutter/material.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/i18n/strings.dart';

/// A rounded card holding settings rows separated by hairlines (design p.11).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            color: c.line,
            indent: 16,
            endIndent: 16,
          ),
        );
      }
      rows.add(children[i]);
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(GdRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F2A2418),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x0D2A2418),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }
}

/// Icon · label · trailing value · chevron.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.danger = false,
    this.chevron = true,
    required this.semanticsId,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;
  final bool chevron;
  final String semanticsId;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final color = danger ? c.danger : c.ink;
    return Semantics(
      identifier: semanticsId,
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 22, color: danger ? c.danger : c.inkMuted),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: context.gdText.subheading.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    value!,
                    style: context.gdText.bodySm.copyWith(fontSize: 14),
                  ),
                ],
                ?trailing,
                if (chevron && onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: c.inkMuted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A yes/no confirmation; true when confirmed.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? body,
  required String confirm,
  bool destructive = true,
  String semanticsPrefix = 'confirm',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: context.gdText.heading),
      content: body == null ? null : Text(body, style: context.gdText.bodyMd),
      actions: [
        Semantics(
          identifier: '$semanticsPrefix.cancel',
          button: true,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: context.gd.ink),
            child: Text(Strings.cancel.of(context)),
          ),
        ),
        Semantics(
          identifier: '$semanticsPrefix.confirm',
          button: true,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: destructive
                ? TextButton.styleFrom(foregroundColor: context.gd.danger)
                : null,
            child: Text(confirm),
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}
