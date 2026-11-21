import 'package:flutter/services.dart';

/// Haptic feedback that respects the user's setting. Everything that vibrates goes through here.
abstract final class Haptics {
  /// Kept in sync with SettingsController.
  static bool enabled = true;

  /// Light tick: a tap, a toggle, a selection.
  static void tap() {
    if (enabled) HapticFeedback.selectionClick();
  }

  /// A click on the Mac (button down).
  static void click() {
    if (enabled) HapticFeedback.lightImpact();
  }

  /// A completed gesture such as a swipe.
  static void heavy() {
    if (enabled) HapticFeedback.mediumImpact();
  }
}
