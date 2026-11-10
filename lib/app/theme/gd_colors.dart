import 'package:flutter/material.dart';

/// Design tokens of the Glow Derma design system, mirrored from
/// `frontend/src/app/globals.css` (`--gd-*`) so the app and the website match.
@immutable
class GdColors extends ThemeExtension<GdColors> {
  const GdColors({
    required this.gold,
    required this.goldInk,
    required this.goldSoft,
    required this.onGold,
    required this.surface,
    required this.surfaceRaised,
    required this.ink,
    required this.inkMuted,
    required this.line,
    required this.lineStrong,
    required this.nav,
    required this.navInk,
    required this.navInkMuted,
    required this.banner,
    required this.bannerInk,
    required this.bannerInkSoft,
    required this.imageWell,
    required this.skeleton,
    required this.success,
    required this.successSoft,
    required this.danger,
    required this.dangerStrong,
    required this.dangerSoft,
    required this.warning,
    required this.warningSoft,
    required this.scrim,
  });

  final Color gold, goldInk, goldSoft, onGold;
  final Color surface, surfaceRaised, ink, inkMuted, line, lineStrong;
  final Color nav, navInk, navInkMuted, banner, bannerInk, bannerInkSoft;
  final Color imageWell, skeleton;
  final Color success,
      successSoft,
      danger,
      dangerStrong,
      dangerSoft,
      warning,
      warningSoft,
      scrim;

  static const light = GdColors(
    gold: Color(0xFFC9A24B),
    goldInk: Color(0xFF9A7424),
    goldSoft: Color(0xFFF6EBD0),
    onGold: Color(0xFF2A2418),
    surface: Color(0xFFFBF8F2),
    surfaceRaised: Color(0xFFFFFFFF),
    ink: Color(0xFF2A2418),
    inkMuted: Color(0xFF7A705D),
    line: Color(0xFFEAE3D3),
    lineStrong: Color(0xFF7A705D),
    nav: Color(0xFF2B2620),
    navInk: Color(0xFFF6EBD0),
    navInkMuted: Color(0xFFA39882),
    banner: Color(0xFF2B2620),
    bannerInk: Color(0xFFC9A24B),
    bannerInkSoft: Color(0xFFF6EBD0),
    imageWell: Color(0xFFF3EDE1),
    skeleton: Color(0xFFECE5D6),
    success: Color(0xFF4E9A6B),
    successSoft: Color(0x1F4E9A6B),
    danger: Color(0xFFD64545),
    dangerStrong: Color(0xFFC93B3B),
    dangerSoft: Color(0x1FD64545),
    warning: Color(0xFFE08A2E),
    warningSoft: Color(0x24E08A2E),
    scrim: Color(0x662A2418),
  );

  static const dark = GdColors(
    gold: Color(0xFFE2BC6A),
    goldInk: Color(0xFFEBCB7C),
    goldSoft: Color(0xFF1C2438),
    onGold: Color(0xFF151107),
    surface: Color(0xFF0D1322),
    surfaceRaised: Color(0xFF151C2F),
    ink: Color(0xFFF3EEE2),
    inkMuted: Color(0xFF98A2B8),
    line: Color(0xFF263049),
    lineStrong: Color(0xFF98A2B8),
    nav: Color(0xFF1B2338),
    navInk: Color(0xFFF3EEE2),
    navInkMuted: Color(0xFF98A2B8),
    banner: Color(0xFF1B2338),
    bannerInk: Color(0xFFEBCB7C),
    bannerInkSoft: Color(0xFFF3EEE2),
    imageWell: Color(0xFF121A2C),
    skeleton: Color(0xFF1C2438),
    success: Color(0xFF4E9A6B),
    successSoft: Color(0x2E4E9A6B),
    danger: Color(0xFFD64545),
    dangerStrong: Color(0xFFC93B3B),
    dangerSoft: Color(0x2ED64545),
    warning: Color(0xFFE08A2E),
    warningSoft: Color(0x2EE08A2E),
    scrim: Color(0xB305080F),
  );

  @override
  GdColors copyWith() => this;

  @override
  GdColors lerp(ThemeExtension<GdColors>? other, double t) =>
      t < 0.5 || other is! GdColors ? this : other;
}

extension GdThemeContext on BuildContext {
  GdColors get gd => Theme.of(this).extension<GdColors>()!;
  GdText get gdText => GdText(gd);
}

/// The type scale of `globals.css`: Cormorant Garamond for display sizes (24 px
/// and up), Manrope for everything else.
@immutable
class GdText {
  const GdText(this.c);
  final GdColors c;

  static const display = 'CormorantGaramond';
  static const body = 'Manrope';

  static TextStyle _style(
    String family,
    double size,
    double height,
    FontWeight weight,
    Color color, {
    double spacing = 0,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    height: height / size,
    fontWeight: weight,
    fontVariations: [FontVariation.weight(weight.value.toDouble())],
    letterSpacing: spacing,
    color: color,
  );

  TextStyle get displayLg =>
      _style(display, 34, 40, FontWeight.w600, c.ink, spacing: -0.34);
  TextStyle get title => _style(display, 26, 32, FontWeight.w600, c.ink);
  TextStyle get heading => _style(body, 18, 24, FontWeight.w700, c.ink);
  TextStyle get subheading => _style(body, 16, 22, FontWeight.w600, c.ink);
  TextStyle get bodyMd => _style(body, 15, 22, FontWeight.w400, c.ink);
  TextStyle get bodySm => _style(body, 13, 18, FontWeight.w400, c.inkMuted);
  TextStyle get label => _style(body, 14, 18, FontWeight.w600, c.ink);
  TextStyle get caption => _style(body, 12, 16, FontWeight.w500, c.inkMuted);
  TextStyle get overline =>
      _style(body, 11, 14, FontWeight.w700, c.inkMuted, spacing: 0.88);
  TextStyle get price => _style(body, 17, 22, FontWeight.w700, c.ink);
  TextStyle get priceLg =>
      _style(body, 24, 30, FontWeight.w800, c.ink, spacing: -0.24);
}
