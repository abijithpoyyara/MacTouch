import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Part 2 message types (see protocol/INPUT.md).
abstract final class InputMsg {
  static const input = 'input';
  static const status = 'status';
}

abstract final class InputCrypto {
  /// Per-session key for signing input frames. Derived locally, never sent.
  static List<int> sessionKey({required List<int> secret, required String clientNonce, required String serverNonce}) =>
      Hmac(sha256, secret).convert(utf8.encode('session|$clientNonce|$serverNonce')).bytes;

  /// MAC over the exact UTF-8 `body` string; `seq` makes replays detectable.
  static List<int> inputMac(List<int> key, int seq, String body) =>
      Hmac(sha256, key).convert(utf8.encode('input|$seq|$body')).bytes;
}

/// Builders for the compact event objects inside an input frame's `ev` array.
abstract final class InputEvents {
  static Map<String, dynamic> move(int dx, int dy) => {'e': 'move', 'dx': dx, 'dy': dy};
  static Map<String, dynamic> scroll(int dx, int dy) => {'e': 'scroll', 'dx': dx, 'dy': dy};
  static Map<String, dynamic> button(String button, bool down, [int clickCount = 1]) =>
      {'e': 'btn', 'b': button, 's': down ? 'down' : 'up', if (clickCount != 1) 'n': clickCount};
  static Map<String, dynamic> key(int code, bool down, [int modifiers = 0]) =>
      {'e': 'key', 'c': code, 's': down ? 'down' : 'up', if (modifiers != 0) 'm': modifiers};
  static Map<String, dynamic> release() => {'e': 'release'};

  /// A full keyboard shortcut. [holdMs] 0 = tap. Modifier bits: shift 1, control 2, option 4, command 8.
  static Map<String, dynamic> shortcut(int code, int modifiers, [int holdMs = 0]) =>
      {'e': 'shortcut', 'c': code, if (modifiers != 0) 'm': modifiers, if (holdMs > 0) 'h': holdMs};

  /// A macOS system action by id (see SystemActionIds).
  static Map<String, dynamic> system(String action) => {'e': 'sys', 'a': action};
}
