/// A key on a US (ANSI) keyboard and its macOS virtual key code. Virtual key codes identify physical key
/// positions, so on other keyboard layouts a letter may differ; [KeyMap] lets the user change any code.
class KeyDef {
  const KeyDef(this.id, this.label, this.code, this.group);
  final String id;
  final String label;
  final int code;
  final String group;
}

abstract final class KeyCatalog {
  static const keys = <KeyDef>[
    KeyDef('a', 'A', 0, 'Letters'), KeyDef('b', 'B', 11, 'Letters'), KeyDef('c', 'C', 8, 'Letters'),
    KeyDef('d', 'D', 2, 'Letters'), KeyDef('e', 'E', 14, 'Letters'), KeyDef('f', 'F', 3, 'Letters'),
    KeyDef('g', 'G', 5, 'Letters'), KeyDef('h', 'H', 4, 'Letters'), KeyDef('i', 'I', 34, 'Letters'),
    KeyDef('j', 'J', 38, 'Letters'), KeyDef('k', 'K', 40, 'Letters'), KeyDef('l', 'L', 37, 'Letters'),
    KeyDef('m', 'M', 46, 'Letters'), KeyDef('n', 'N', 45, 'Letters'), KeyDef('o', 'O', 31, 'Letters'),
    KeyDef('p', 'P', 35, 'Letters'), KeyDef('q', 'Q', 12, 'Letters'), KeyDef('r', 'R', 15, 'Letters'),
    KeyDef('s', 'S', 1, 'Letters'), KeyDef('t', 'T', 17, 'Letters'), KeyDef('u', 'U', 32, 'Letters'),
    KeyDef('v', 'V', 9, 'Letters'), KeyDef('w', 'W', 13, 'Letters'), KeyDef('x', 'X', 7, 'Letters'),
    KeyDef('y', 'Y', 16, 'Letters'), KeyDef('z', 'Z', 6, 'Letters'),
    KeyDef('1', '1', 18, 'Numbers'), KeyDef('2', '2', 19, 'Numbers'), KeyDef('3', '3', 20, 'Numbers'),
    KeyDef('4', '4', 21, 'Numbers'), KeyDef('5', '5', 23, 'Numbers'), KeyDef('6', '6', 22, 'Numbers'),
    KeyDef('7', '7', 26, 'Numbers'), KeyDef('8', '8', 28, 'Numbers'), KeyDef('9', '9', 25, 'Numbers'),
    KeyDef('0', '0', 29, 'Numbers'),
    KeyDef('return', 'Return', 36, 'Special'), KeyDef('tab', 'Tab', 48, 'Special'),
    KeyDef('space', 'Space', 49, 'Special'), KeyDef('delete', 'Delete', 51, 'Special'),
    KeyDef('escape', 'Esc', 53, 'Special'), KeyDef('forwarddelete', 'Fwd Delete', 117, 'Special'),
    KeyDef('home', 'Home', 115, 'Special'), KeyDef('end', 'End', 119, 'Special'),
    KeyDef('pageup', 'Page Up', 116, 'Special'), KeyDef('pagedown', 'Page Down', 121, 'Special'),
    KeyDef('left', '\u2190', 123, 'Arrows'), KeyDef('right', '\u2192', 124, 'Arrows'),
    KeyDef('down', '\u2193', 125, 'Arrows'), KeyDef('up', '\u2191', 126, 'Arrows'),
    KeyDef('minus', '-', 27, 'Symbols'), KeyDef('equal', '=', 24, 'Symbols'),
    KeyDef('leftbracket', '[', 33, 'Symbols'), KeyDef('rightbracket', ']', 30, 'Symbols'),
    KeyDef('semicolon', ';', 41, 'Symbols'), KeyDef('quote', "'", 39, 'Symbols'),
    KeyDef('comma', ',', 43, 'Symbols'), KeyDef('period', '.', 47, 'Symbols'),
    KeyDef('slash', '/', 44, 'Symbols'), KeyDef('backslash', '\\', 42, 'Symbols'),
    KeyDef('grave', '`', 50, 'Symbols'),
    KeyDef('f1', 'F1', 122, 'Function'), KeyDef('f2', 'F2', 120, 'Function'), KeyDef('f3', 'F3', 99, 'Function'),
    KeyDef('f4', 'F4', 118, 'Function'), KeyDef('f5', 'F5', 96, 'Function'), KeyDef('f6', 'F6', 97, 'Function'),
    KeyDef('f7', 'F7', 98, 'Function'), KeyDef('f8', 'F8', 100, 'Function'), KeyDef('f9', 'F9', 101, 'Function'),
    KeyDef('f10', 'F10', 109, 'Function'), KeyDef('f11', 'F11', 103, 'Function'), KeyDef('f12', 'F12', 111, 'Function'),
  ];

  static final Map<String, KeyDef> _byId = {for (final k in keys) k.id: k};

  static KeyDef? byId(String id) => _byId[id];

  /// A key that is not in the catalog, typed in as a raw macOS key code: "code:123".
  static const rawPrefix = 'code:';
  static String rawId(int code) => '$rawPrefix$code';

  static String label(String id) {
    final k = _byId[id];
    if (k != null) return k.label;
    final raw = _rawCode(id);
    return raw != null ? 'Key $raw' : '?';
  }

  static List<KeyDef> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return keys;
    return keys.where((k) => k.id.contains(q) || k.label.toLowerCase().contains(q) || k.group.toLowerCase().contains(q)).toList();
  }

  static int? _rawCode(String id) {
    if (!id.startsWith(rawPrefix)) return null;
    final v = int.tryParse(id.substring(rawPrefix.length));
    return v != null && v >= 0 && v <= 255 ? v : null;
  }
}

/// Key id -> macOS virtual key code. Defaults to the US layout; the user can override any key.
class KeyMap {
  const KeyMap([this.overrides = const {}]);
  final Map<String, int> overrides;

  int? codeFor(String keyId) {
    final o = overrides[keyId];
    if (o != null) return o;
    final def = KeyCatalog.byId(keyId);
    if (def != null) return def.code;
    return KeyCatalog._rawCode(keyId);
  }

  bool isOverridden(String keyId) => overrides.containsKey(keyId);

  /// Throws [ArgumentError] for codes outside 0-255.
  KeyMap withOverride(String keyId, int code) {
    if (code < 0 || code > 255) throw ArgumentError.value(code, 'code', 'must be 0-255');
    return KeyMap({...overrides, keyId: code});
  }

  KeyMap without(String keyId) => KeyMap({...overrides}..remove(keyId));

  Map<String, dynamic> toJson() => {'overrides': overrides};

  /// Never throws; invalid entries are dropped.
  static KeyMap fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return const KeyMap();
    final raw = json['overrides'];
    if (raw is! Map) return const KeyMap();
    final out = <String, int>{};
    raw.forEach((k, v) {
      if (k is String && KeyCatalog.byId(k) != null && v is int && v >= 0 && v <= 255) out[k] = v;
    });
    return KeyMap(out);
  }
}
