import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Design tokens. New and polished screens use these instead of ad-hoc numbers.
abstract final class Tk {
  // spacing (4-pt grid)
  static const double s1 = 4, s2 = 8, s3 = 12, s4 = 16, s5 = 20, s6 = 24, s8 = 32;
  // corner radii
  static const double rSm = 12, rMd = 16, rLg = 22, rXl = 28;
  /// Minimum touch target (Android accessibility guideline).
  static const double touchTarget = 48;
  /// Keeps text lines readable on tablets and in landscape.
  static const double maxContentWidth = 560;
  // motion: short and sparing
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 220);
}

abstract final class MtGradients {
  /// Very subtle wash from the accent color, used behind hero areas.
  static LinearGradient hero(MtColors c) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [c.accent.withValues(alpha: 0.20), c.accent.withValues(alpha: 0.03)],
      );

  static LinearGradient accent(MtColors c) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [c.accent, Color.lerp(c.accent, c.bg, 0.28)!],
      );
}
