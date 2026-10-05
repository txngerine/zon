import 'package:flutter/material.dart';

/// Shared typography helpers.
///
/// Numeric readouts use tabular figures so values stay aligned while they
/// animate — an important detail for a download manager.
class AppType {
  AppType._();

  static const tabular = <FontFeature>[FontFeature.tabularFigures()];

  /// Small uppercase, letter-spaced label used for eyebrows and status chips.
  static TextStyle eyebrow(
    Color color, {
    double size = 10.5,
    double spacing = 1.6,
  }) => TextStyle(
    color: color,
    fontSize: size,
    fontWeight: FontWeight.w600,
    letterSpacing: spacing,
    height: 1.2,
  );

  static TextStyle heading(
    Color color, {
    double size = 34,
    double spacing = -1,
  }) => TextStyle(
    color: color,
    fontSize: size,
    fontWeight: FontWeight.w600,
    letterSpacing: spacing,
    height: 1.05,
  );

  static TextStyle body(
    Color color, {
    double size = 13.5,
    FontWeight weight = FontWeight.w400,
  }) =>
      TextStyle(color: color, fontSize: size, fontWeight: weight, height: 1.45);

  static TextStyle numeric(
    Color color, {
    double size = 13,
    FontWeight weight = FontWeight.w500,
  }) => TextStyle(
    color: color,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: 0.1,
    fontFeatures: tabular,
    height: 1.3,
  );
}

extension TextStyleX on TextStyle {
  TextStyle get muted => copyWith(color: const Color(0xFF666666));
}
