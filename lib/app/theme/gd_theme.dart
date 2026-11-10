import 'package:flutter/material.dart';

import 'gd_colors.dart';

/// Radii and sizes from the design system.
abstract final class GdRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 20.0;
}

abstract final class GdSpace {
  static const page = 18.0;
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? GdColors.dark : GdColors.light;
  final t = GdText(c);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.gold,
    onPrimary: c.onGold,
    secondary: c.goldInk,
    onSecondary: c.surfaceRaised,
    error: c.danger,
    onError: Colors.white,
    surface: c.surface,
    onSurface: c.ink,
    surfaceContainerHighest: c.surfaceRaised,
    outline: c.line,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(GdRadius.md));
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.surface,
    canvasColor: c.surface,
    fontFamily: GdText.body,
    extensions: [c],
    splashFactory: InkSparkle.splashFactory,
    textTheme: TextTheme(
      displayLarge: t.displayLg,
      headlineMedium: t.title,
      titleLarge: t.heading,
      titleMedium: t.subheading,
      bodyLarge: t.bodyMd,
      bodyMedium: t.bodyMd,
      bodySmall: t.bodySm,
      labelLarge: t.label,
      labelSmall: t.caption,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: c.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: t.title,
    ),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.gold,
        foregroundColor: c.onGold,
        disabledBackgroundColor: c.goldSoft,
        disabledForegroundColor: c.inkMuted,
        minimumSize: const Size.fromHeight(52),
        shape: shape,
        textStyle: t.subheading,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        side: BorderSide(color: c.lineStrong, width: 1.5),
        minimumSize: const Size.fromHeight(52),
        shape: shape,
        textStyle: t.subheading,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.goldInk, textStyle: t.label),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceRaised,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: t.bodyMd.copyWith(color: c.inkMuted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(GdRadius.md), borderSide: BorderSide(color: c.lineStrong)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(GdRadius.md), borderSide: BorderSide(color: c.lineStrong)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(GdRadius.md), borderSide: BorderSide(color: c.goldInk, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(GdRadius.md), borderSide: BorderSide(color: c.danger)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(GdRadius.md), borderSide: BorderSide(color: c.danger, width: 2)),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.goldInk : Colors.transparent),
      checkColor: WidgetStatePropertyAll(c.surfaceRaised),
      side: BorderSide(color: c.lineStrong, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.nav,
      contentTextStyle: t.bodyMd.copyWith(color: c.navInk),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GdRadius.md)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(GdRadius.lg))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GdRadius.lg)),
      titleTextStyle: t.heading,
      contentTextStyle: t.bodyMd,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.gold, linearTrackColor: c.goldSoft),
  );
}
