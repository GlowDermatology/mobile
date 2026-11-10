import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/gd_colors.dart';
import '../../app/theme/gd_theme.dart';
import '../i18n/strings.dart';
import '../i18n/tr.dart';
import '../network/api_exception.dart';
import 'product_art.dart';

/// White card with the design's 20 px radius and soft shadow.
class GdCard extends StatelessWidget {
  const GdCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.border,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final radius = BorderRadius.circular(GdRadius.lg);
    return Container(
      decoration: BoxDecoration(
        color: color ?? c.surfaceRaised,
        borderRadius: radius,
        border: border,
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
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Back arrow + Cormorant title, as on every inner screen of the design.
class GdHeader extends StatelessWidget implements PreferredSizeWidget {
  const GdHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.showBack = true,
    this.onBack,
  });
  final String title;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 64,
    automaticallyImplyLeading: false,
    titleSpacing: showBack ? 0 : GdSpace.page,
    leading: showBack
        ? IconButton(
            tooltip: Strings.back.of(context),
            icon: const Icon(Icons.chevron_left, size: 30),
            onPressed:
                onBack ??
                () => context.canPop() ? context.pop() : context.go('/catalog'),
          )
        : null,
    title: Text(
      title,
      style: context.gdText.title,
      overflow: TextOverflow.ellipsis,
    ),
    actions: [...actions, const SizedBox(width: 8)],
  );
}

/// Bottom bar holding the primary action of a screen ("Savatga qo‘shish").
class GdBottomBar extends StatelessWidget {
  const GdBottomBar({super.key, required this.child, this.top});
  final Widget child;
  final Widget? top;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.gd.surface,
      border: Border(top: BorderSide(color: context.gd.line)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(GdSpace.page, 12, GdSpace.page, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (top != null) ...[top!, const SizedBox(height: 10)],
            child,
          ],
        ),
      ),
    ),
  );
}

/// Primary gold button with a loading state.
class GdButton extends StatelessWidget {
  const GdButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.semanticsId,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final String? semanticsId;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: context.gd.onGold,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, maxLines: 1),
                ),
              ),
            ],
          );
    return Semantics(
      identifier: semanticsId,
      button: true,
      child: FilledButton(onPressed: loading ? null : onPressed, child: child),
    );
  }
}

/// Outlined secondary button.
class GdOutlineButton extends StatelessWidget {
  const GdOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.semanticsId,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final String? semanticsId;

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: semanticsId,
    button: true,
    child: OutlinedButton(
      onPressed: onPressed,
      style: color == null
          ? null
          : OutlinedButton.styleFrom(foregroundColor: color),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1),
            ),
          ),
        ],
      ),
    ),
  );
}

/// "− 1 +" quantity stepper.
class GdStepper extends StatelessWidget {
  const GdStepper({
    super.key,
    required this.value,
    this.onMinus,
    this.onPlus,
    this.compact = false,
    this.busy = false,
    this.semanticsPrefix,
  });

  /// `<prefix>.minus` / `<prefix>.plus` identifiers for tests.
  final String? semanticsPrefix;
  final int value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final bool compact;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final h = compact ? 38.0 : 44.0;
    Widget btn(IconData icon, VoidCallback? onTap, String label, String id) =>
        Semantics(
          identifier: semanticsPrefix == null ? null : '$semanticsPrefix.$id',
          button: true,
          label: label,
          child: InkResponse(
            onTap: busy ? null : onTap,
            radius: h / 2,
            child: SizedBox(
              width: h,
              height: h,
              child: Icon(
                icon,
                size: 20,
                color: onTap == null ? c.line : c.ink,
              ),
            ),
          ),
        );
    return Container(
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GdRadius.md),
        border: Border.all(color: c.lineStrong, width: 1.2),
        color: c.surfaceRaised,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.remove, onMinus, '−', 'minus'),
          SizedBox(
            width: compact ? 26 : 36,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: context.gdText.label.copyWith(fontSize: 16),
            ),
          ),
          btn(Icons.add, onPlus, '+', 'plus'),
        ],
      ),
    );
  }
}

/// Pill chip used for filters ("Hammasi", "Dermatologlar").
class GdFilterChip extends StatelessWidget {
  const GdFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    return Material(
      color: selected ? c.gold : c.surfaceRaised,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? c.gold : c.lineStrong, width: 1.2),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            label,
            style: context.gdText.label.copyWith(
              color: selected ? c.onGold : c.ink,
            ),
          ),
        ),
      ),
    );
  }
}

enum GdTone { gold, success, warning, danger, neutral }

/// Uppercase status chip with a dot ("● JARAYONDA").
class GdStatusChip extends StatelessWidget {
  const GdStatusChip({
    super.key,
    required this.label,
    this.tone = GdTone.gold,
    this.dot = true,
    this.uppercase = true,
  });
  final String label;
  final GdTone tone;
  final bool dot;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final (bg, fg) = switch (tone) {
      GdTone.gold => (c.goldSoft, c.goldInk),
      GdTone.success => (c.successSoft, c.success),
      GdTone.warning => (c.warningSoft, c.warning),
      GdTone.danger => (c.dangerSoft, c.danger),
      GdTone.neutral => (c.line, c.inkMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(GdRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              uppercase ? label.toUpperCase() : label,
              overflow: TextOverflow.ellipsis,
              style: context.gdText.overline.copyWith(
                color: tone == GdTone.neutral ? c.ink : c.ink,
                letterSpacing: uppercase ? 0.7 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Network image with the design's beige "image well" and an illustrated
/// fallback when there is no photo.
class GdImage extends StatelessWidget {
  const GdImage({
    super.key,
    required this.url,
    this.seed = '',
    this.radius = GdRadius.md,
    this.fit = BoxFit.cover,
    this.artSize = 64,
  });
  final String? url;
  final String seed;
  final double radius;
  final BoxFit fit;
  final double artSize;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final fallback = Center(
      child: ProductArt(kind: artKindFor(seed), size: artSize),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: c.goldSoft,
        child: url == null || url!.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: url!,
                fit: fit,
                width: double.infinity,
                height: double.infinity,
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (_, _) => ColoredBox(color: c.imageWell),
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// Initials avatar ("MK").
class GdAvatar extends StatelessWidget {
  const GdAvatar({
    super.key,
    required this.initials,
    this.size = 56,
    this.imageUrl,
  });
  final String initials;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: c.goldSoft, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              width: size,
              height: size,
            )
          : Text(
              initials,
              style: context.gdText.heading.copyWith(
                fontSize: size * 0.34,
                color: c.ink,
              ),
            ),
    );
  }
}

/// Section title ("Mashhur mahsulotlar").
class GdSectionTitle extends StatelessWidget {
  const GdSectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: context.gdText.heading.copyWith(fontSize: 20),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Centered spinner for a loading screen.
class GdLoading extends StatelessWidget {
  const GdLoading({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: CircularProgressIndicator(),
    ),
  );
}

/// Error state with a retry button and the request id ("Xato kodi").
class GdErrorView extends StatelessWidget {
  const GdErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final api = error is ApiException ? error as ApiException : null;
    final message = errorMessage(context, error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              api?.isNetwork == true
                  ? Icons.wifi_off_rounded
                  : Icons.error_outline_rounded,
              size: 44,
              color: context.gd.inkMuted,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.gdText.bodyMd,
            ),
            if (api?.requestId != null) ...[
              const SizedBox(height: 6),
              Text(
                '${Strings.errorCode.of(context)}: ${api!.requestId}',
                style: context.gdText.caption,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: 200,
                child: GdOutlineButton(
                  label: Strings.retry.of(context),
                  onPressed: onRetry,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state ("Savat hozircha bo‘sh").
class GdEmptyView extends StatelessWidget {
  const GdEmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: context.gd.goldSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 38, color: context.gd.goldInk),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.gdText.heading,
          ),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: context.gdText.bodySm,
            ),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

/// The text to show for any error thrown by the data layer.
String errorMessage(BuildContext context, Object error) {
  if (error is ApiException) {
    if (error.isNetwork) return Strings.networkError.of(context);
    if (error.displayMessage.isNotEmpty) return error.displayMessage;
  }
  if (error is SessionEnded && error.message.isNotEmpty) return error.message;
  return Strings.unexpectedError.of(context);
}

void showSnack(BuildContext context, String message) {
  if (message.isEmpty) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void showError(BuildContext context, Object error) =>
    showSnack(context, errorMessage(context, error));

/// A light haptic tap for confirmations (no-op where unsupported).
void tick() => HapticFeedback.selectionClick().ignore();

/// Shortcut for one-off localized strings.
String tr(BuildContext context, String uz, String ru, String en) =>
    Tr(uz, ru, en).of(context);
