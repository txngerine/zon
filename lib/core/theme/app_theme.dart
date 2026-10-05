import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'zon_palette.dart';

/// Central [ThemeData] factory for ZON.
///
/// Material defaults are deliberately neutralised so the interface reads as a
/// native desktop product rather than a Material app.
class AppTheme {
  AppTheme._();

  static ThemeData dark() => _build(ZonPalette.dark, Brightness.dark);
  static ThemeData light() => _build(ZonPalette.light, Brightness.light);

  static ThemeData _build(ZonPalette palette, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: palette.textPrimary,
        onPrimary: palette.background,
        secondary: palette.textSecondary,
        onSecondary: palette.background,
        error: palette.textPrimary,
        onError: palette.background,
        surface: palette.surface,
        onSurface: palette.textPrimary,
        outline: palette.border,
      ),
      scaffoldBackgroundColor: palette.background,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: palette.hover,
      focusColor: Colors.transparent,
      extensions: [palette],
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: palette.textPrimary,
        displayColor: palette.textPrimary,
        fontFamily: null,
      ),
      iconTheme: IconThemeData(color: palette.textSecondary, size: 18),
      dividerTheme: DividerThemeData(
        color: palette.border,
        space: 1,
        thickness: 1,
      ),
      canvasColor: palette.surface,
      cardColor: palette.surface,
      primaryColor: palette.textPrimary,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.backgroundRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.border),
        ),
        titleTextStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        contentTextStyle: TextStyle(
          color: palette.textSecondary,
          fontSize: 13.5,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.border),
        ),
        textStyle: TextStyle(color: palette.textPrimary, fontSize: 13),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: palette.textPrimary, fontSize: 13),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(palette.surfaceHigh),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          side: WidgetStatePropertyAll(BorderSide(color: palette.border)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: palette.surfaceHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.border),
        ),
        textStyle: TextStyle(color: palette.textPrimary, fontSize: 12),
        waitDuration: const Duration(milliseconds: 400),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(8),
        thumbColor: WidgetStateProperty.all(
          palette.textMuted.withValues(alpha: 0.35),
        ),
        trackColor: WidgetStatePropertyAll(Colors.transparent),
        trackBorderColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: palette.textMuted, fontSize: 14),
        labelStyle: TextStyle(color: palette.textMuted, fontSize: 13),
        border: const OutlineInputBorder(borderSide: BorderSide.none),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide.none),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide.none),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.onAccent
              : palette.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.accent
              : palette.surfaceHighest,
        ),
        trackOutlineColor: WidgetStatePropertyAll(palette.border),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: palette.textPrimary,
        inactiveTrackColor: palette.track,
        thumbColor: palette.textPrimary,
        overlayColor: palette.hover,
        trackHeight: 3,
        showValueIndicator: ShowValueIndicator.never,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.textPrimary,
        linearTrackColor: palette.track,
        circularTrackColor: palette.track,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surfaceHighest,
        contentTextStyle: TextStyle(color: palette.textPrimary, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: palette.border),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.textPrimary,
        selectionColor: palette.textPrimary.withValues(alpha: 0.25),
        selectionHandleColor: palette.textPrimary,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.textSecondary,
        textColor: palette.textPrimary,
        tileColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}
