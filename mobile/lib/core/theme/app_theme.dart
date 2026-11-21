import 'package:flutter/material.dart';

/// MacTouch palette. Mirrors desktop/Sources/MacTouchDesktop/Theme.swift.
class MtColors {
  const MtColors({
    required this.bg, required this.surface, required this.surfaceHigh, required this.outline,
    required this.text, required this.textDim, required this.accent, required this.onAccent,
    required this.success, required this.danger, required this.warning,
  });

  final Color bg, surface, surfaceHigh, outline, text, textDim, accent, onAccent, success, danger, warning;

  static const dark = MtColors(
    bg: Color(0xFF14171D), surface: Color(0xFF1D2129), surfaceHigh: Color(0xFF272C36), outline: Color(0xFF343A46),
    text: Color(0xFFECEFF4), textDim: Color(0xFF98A1B3), accent: Color(0xFF8D79FF), onAccent: Color(0xFF12101F),
    success: Color(0xFF38C99B), danger: Color(0xFFFF6B7A), warning: Color(0xFFF2B24B),
  );

  static const light = MtColors(
    bg: Color(0xFFEEF0F5), surface: Color(0xFFFFFFFF), surfaceHigh: Color(0xFFE4E7EE), outline: Color(0xFFD3D8E2),
    text: Color(0xFF161922), textDim: Color(0xFF5C6577), accent: Color(0xFF5B3FF0), onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF14946B), danger: Color(0xFFD8374A), warning: Color(0xFFA86400),
  );

  /// The palette for this context. The accent comes from the app theme, so a user-chosen accent reaches every screen.
  static MtColors of(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.brightness == Brightness.dark ? dark : light;
    final scheme = theme.colorScheme;
    return scheme.primary == base.accent ? base : base.withAccent(scheme.primary, scheme.onPrimary);
  }

  MtColors withAccent(Color accent, Color onAccent) => MtColors(
        bg: bg, surface: surface, surfaceHigh: surfaceHigh, outline: outline, text: text, textDim: textDim,
        accent: accent, onAccent: onAccent, success: success, danger: danger, warning: warning,
      );
}

abstract final class AppTheme {
  static ThemeData get light => _build(MtColors.light, Brightness.light);
  static ThemeData get dark => _build(MtColors.dark, Brightness.dark);

  /// Themes with the user's accent color.
  static ThemeData lightWith(Color accent, Color onAccent) => _build(MtColors.light.withAccent(accent, onAccent), Brightness.light);
  static ThemeData darkWith(Color accent, Color onAccent) => _build(MtColors.dark.withAccent(accent, onAccent), Brightness.dark);

  static ThemeData _build(MtColors c, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent, onPrimary: c.onAccent,
      secondary: c.accent, onSecondary: c.onAccent,
      error: c.danger, onError: c.bg,
      surface: c.surface, onSurface: c.text,
      outline: c.outline,
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    const padding = EdgeInsets.symmetric(horizontal: 22, vertical: 16);
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      textTheme: base.textTheme.apply(bodyColor: c.text, displayColor: c.text),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent, foregroundColor: c.onAccent, shape: shape, padding: padding,
          minimumSize: const Size.fromHeight(54),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text, side: BorderSide(color: c.outline), shape: shape, padding: padding,
          minimumSize: const Size.fromHeight(54),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: c.accent)),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating, backgroundColor: c.surfaceHigh,
        contentTextStyle: TextStyle(color: c.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
