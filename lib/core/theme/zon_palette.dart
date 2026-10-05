import 'package:flutter/material.dart';

/// Semantic color system for ZON.
///
/// The application is intentionally monochrome: blacks, whites and greys only.
/// Every widget reads its colors from [ZonPalette] so the light and dark
/// appearance modes can be swapped without touching component code.
@immutable
class ZonPalette extends ThemeExtension<ZonPalette> {
  const ZonPalette({
    required this.background,
    required this.backgroundElevated,
    required this.backgroundRaised,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.track,
    required this.accent,
    required this.onAccent,
    required this.hover,
    required this.scrim,
    required this.shadow,
  });

  /// Deepest application background.
  final Color background;

  /// Shell background (sidebar, status bar).
  final Color backgroundElevated;

  /// Raised shell surfaces such as the details panel.
  final Color backgroundRaised;

  /// Card / input surface.
  final Color surface;

  /// Hovered or selected surface.
  final Color surfaceHigh;

  /// Active surface (nav selection, chips).
  final Color surfaceHighest;

  /// Hairline separators and card outlines.
  final Color border;

  /// Stronger outline used for emphasis.
  final Color borderStrong;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Progress bar track.
  final Color track;

  /// Primary action fill (white in dark mode, near-black in light mode).
  final Color accent;

  /// Content painted on top of [accent].
  final Color onAccent;

  /// Subtle interactive hover wash.
  final Color hover;

  /// Modal scrim.
  final Color scrim;

  /// Soft shadow color.
  final Color shadow;

  static const dark = ZonPalette(
    background: Color(0xFF050505),
    backgroundElevated: Color(0xFF0A0A0A),
    backgroundRaised: Color(0xFF111111),
    surface: Color(0xFF151515),
    surfaceHigh: Color(0xFF1A1A1A),
    surfaceHighest: Color(0xFF202020),
    border: Color(0xFF2A2A2A),
    borderStrong: Color(0xFF3A3A3A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA1A1A1),
    textMuted: Color(0xFF666666),
    track: Color(0xFF252525),
    accent: Color(0xFFFFFFFF),
    onAccent: Color(0xFF050505),
    hover: Color(0x0FFFFFFF),
    scrim: Color(0xB3000000),
    shadow: Color(0x66000000),
  );

  static const light = ZonPalette(
    background: Color(0xFFFAFAFA),
    backgroundElevated: Color(0xFFFFFFFF),
    backgroundRaised: Color(0xFFF4F4F4),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF1F1F1),
    surfaceHighest: Color(0xFFE8E8E8),
    border: Color(0xFFE2E2E2),
    borderStrong: Color(0xFFCFCFCF),
    textPrimary: Color(0xFF0A0A0A),
    textSecondary: Color(0xFF565656),
    textMuted: Color(0xFF8E8E8E),
    track: Color(0xFFE8E8E8),
    accent: Color(0xFF0A0A0A),
    onAccent: Color(0xFFFFFFFF),
    hover: Color(0x0A000000),
    scrim: Color(0x59000000),
    shadow: Color(0x1A000000),
  );

  @override
  ZonPalette copyWith({
    Color? background,
    Color? backgroundElevated,
    Color? backgroundRaised,
    Color? surface,
    Color? surfaceHigh,
    Color? surfaceHighest,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? track,
    Color? accent,
    Color? onAccent,
    Color? hover,
    Color? scrim,
    Color? shadow,
  }) {
    return ZonPalette(
      background: background ?? this.background,
      backgroundElevated: backgroundElevated ?? this.backgroundElevated,
      backgroundRaised: backgroundRaised ?? this.backgroundRaised,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      surfaceHighest: surfaceHighest ?? this.surfaceHighest,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      track: track ?? this.track,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      hover: hover ?? this.hover,
      scrim: scrim ?? this.scrim,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  ZonPalette lerp(ThemeExtension<ZonPalette>? other, double t) {
    if (other is! ZonPalette) return this;
    return ZonPalette(
      background: Color.lerp(background, other.background, t)!,
      backgroundElevated: Color.lerp(
        backgroundElevated,
        other.backgroundElevated,
        t,
      )!,
      backgroundRaised: Color.lerp(
        backgroundRaised,
        other.backgroundRaised,
        t,
      )!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      surfaceHighest: Color.lerp(surfaceHighest, other.surfaceHighest, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      track: Color.lerp(track, other.track, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension ZonPaletteContext on BuildContext {
  ZonPalette get palette =>
      Theme.of(this).extension<ZonPalette>() ?? ZonPalette.dark;
}
