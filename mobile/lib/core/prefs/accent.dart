import 'package:flutter/material.dart';

/// Accent colors the user can pick. Each has a light-theme and a dark-theme shade that both keep readable contrast.
class AccentOption {
  const AccentOption(this.id, this.label, this.light, this.dark);
  final String id;
  final String label;
  final Color light;
  final Color dark;
}

abstract final class AccentPalette {
  static const defaultId = 'violet';

  static const options = <AccentOption>[
    AccentOption('violet', 'Violet', Color(0xFF5B3FF0), Color(0xFF8D79FF)),
    AccentOption('blue', 'Blue', Color(0xFF1F63D6), Color(0xFF6CA8FF)),
    AccentOption('teal', 'Teal', Color(0xFF0B7F75), Color(0xFF3DD6C4)),
    AccentOption('green', 'Green', Color(0xFF2B7A3A), Color(0xFF6FD27B)),
    AccentOption('orange', 'Orange', Color(0xFFB85000), Color(0xFFFFA14A)),
    AccentOption('pink', 'Pink', Color(0xFFBD1F55), Color(0xFFFF7AA8)),
    AccentOption('red', 'Red', Color(0xFFC02525), Color(0xFFFF7D7D)),
    AccentOption('graphite', 'Graphite', Color(0xFF3B4252), Color(0xFFB8C0D0)),
  ];

  static AccentOption byId(String? id) => options.firstWhere((o) => o.id == id, orElse: () => options.first);
}

/// WCAG contrast ratio, 1 (none) to 21 (black on white).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Text/icon color to put on top of [accent]: white or near-black, whichever reads better.
Color onAccentFor(Color accent) {
  const white = Color(0xFFFFFFFF), ink = Color(0xFF12101F);
  return contrastRatio(accent, white) >= contrastRatio(accent, ink) ? white : ink;
}
