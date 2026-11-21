import 'package:flutter/foundation.dart';

/// Logging that never receives secrets: tokens, secrets and proofs have no logging path.
/// Identifiers go through [shortId]; info logs are dropped in release builds.
abstract final class AppLog {
  static void i(String tag, String message) {
    if (kReleaseMode) return;
    debugPrint('[$tag] $message');
  }

  static void w(String tag, String message) => debugPrint('[$tag] WARN $message');
  static void e(String tag, String message) => debugPrint('[$tag] ERROR $message');

  /// "phone-0123456789abcdef" -> "phone-\u2026cdef"
  static String shortId(String id) =>
      id.length <= 10 ? '\u2026${id.substring(id.length - 4)}' : '${id.substring(0, 6)}\u2026${id.substring(id.length - 4)}';
}
