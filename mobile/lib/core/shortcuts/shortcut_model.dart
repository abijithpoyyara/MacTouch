import 'key_catalog.dart';
import 'system_actions.dart';

/// Keyboard modifier bitmask shared with the Mac app: shift 1, control 2, option 4, command 8.
abstract final class Mod {
  static const shift = 1;
  static const control = 2;
  static const option = 4;
  static const command = 8;

  /// Display and press order.
  static const ordered = [control, option, shift, command];

  static String symbols(int mods) {
    final b = StringBuffer();
    if (mods & control != 0) b.write('\u2303');
    if (mods & option != 0) b.write('\u2325');
    if (mods & shift != 0) b.write('\u21e7');
    if (mods & command != 0) b.write('\u2318');
    return b.toString();
  }

  static String name(int bit) => switch (bit) {
        control => 'Control',
        option => 'Option',
        shift => 'Shift',
        command => 'Command',
        _ => '?',
      };
}

enum ShortcutCategory {
  system('System', 'system'),
  window('Window Management', 'window'),
  browser('Browser', 'browser'),
  developer('Developer', 'developer'),
  custom('Custom', 'custom');

  const ShortcutCategory(this.label, this.id);
  final String label;
  final String id;

  static ShortcutCategory? fromId(Object? id) {
    for (final c in values) {
      if (c.id == id) return c;
    }
    return null;
  }
}

enum ShortcutKind { key, system }

class ShortcutItem {
  const ShortcutItem({
    required this.id,
    required this.name,
    required this.category,
    this.iconKey = 'bolt',
    this.kind = ShortcutKind.key,
    this.modifiers = 0,
    this.keyId = '',
    this.systemAction,
    this.holdMs = 0,
    this.favorite = false,
    this.order = 0,
    this.note,
    this.preset = false,
    this.group,
  });

  final String id;
  final String name;
  final ShortcutCategory category;
  final String iconKey;
  final ShortcutKind kind;
  final int modifiers;
  /// Key catalog id ("t", "left", "f11") or a raw code ("code:123"). Empty for system actions.
  final String keyId;
  /// One of [SystemActionIds.all] when [kind] is [ShortcutKind.system].
  final String? systemAction;
  /// 0 = tap. Otherwise keep the keys pressed for this many ms (for example Command-Tab app switcher).
  final int holdMs;
  final bool favorite;
  final int order;
  /// Where it works / what it needs. Shown to the user; never assumed to hold in every app.
  final String? note;
  final bool preset;
  /// User-defined sub-category (only used when [category] is Custom). Null = plain Custom.
  final String? group;

  static const maxHoldMs = 5000;

  /// What to show as the category: the user's own category name, or the built-in one.
  String get categoryLabel => (category == ShortcutCategory.custom ? group : null) ?? category.label;

  static const maxGroupLength = 30;

  /// Trimmed category name, or null if it is not a usable name.
  static String? cleanGroup(Object? raw) {
    if (raw is! String) return null;
    final t = raw.trim();
    return t.isEmpty || t.length > maxGroupLength ? null : t;
  }

  /// "\u2318T", "\u2303\u2318Q", or the action name for system actions.
  String get combo => kind == ShortcutKind.system
      ? SystemActionIds.label(systemAction ?? '')
      : '${Mod.symbols(modifiers)}${KeyCatalog.label(keyId)}';

  /// User-facing problem with this shortcut, or null when it can be saved and run.
  String? validate() {
    if (name.trim().isEmpty) return 'Give the shortcut a name.';
    if (name.trim().length > 40) return 'Use a shorter name (40 characters or fewer).';
    if (holdMs < 0 || holdMs > maxHoldMs) return 'Hold time must be between 0 and $maxHoldMs ms.';
    if (kind == ShortcutKind.system) {
      return SystemActionIds.isValid(systemAction ?? '') ? null : 'Unknown system action.';
    }
    if (modifiers < 0 || modifiers > 15) return 'Invalid modifiers.';
    if (keyId.isEmpty || const KeyMap().codeFor(keyId) == null) return 'Choose a key.';
    return null;
  }

  ShortcutItem copyWith({
    String? name, ShortcutCategory? category, String? iconKey, int? modifiers, String? keyId,
    int? holdMs, bool? favorite, int? order, String? note, bool? preset, String? group, bool clearGroup = false,
  }) =>
      ShortcutItem(
        id: id, name: name ?? this.name, category: category ?? this.category, iconKey: iconKey ?? this.iconKey,
        kind: kind, modifiers: modifiers ?? this.modifiers, keyId: keyId ?? this.keyId, systemAction: systemAction,
        holdMs: holdMs ?? this.holdMs, favorite: favorite ?? this.favorite, order: order ?? this.order,
        note: note ?? this.note, preset: preset ?? this.preset,
        group: clearGroup ? null : (group ?? this.group),
      );

  /// The input event to send to the Mac, or null when the key cannot be resolved with [map].
  Map<String, dynamic>? toEvent(KeyMap map) {
    if (kind == ShortcutKind.system) {
      final a = systemAction;
      return a != null && SystemActionIds.isValid(a) ? {'e': 'sys', 'a': a} : null;
    }
    final code = map.codeFor(keyId);
    if (code == null) return null;
    return {'e': 'shortcut', 'c': code, if (modifiers != 0) 'm': modifiers, if (holdMs > 0) 'h': holdMs};
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'cat': category.id, 'icon': iconKey, 'kind': kind.name,
        'mods': modifiers, 'key': keyId, if (systemAction != null) 'sys': systemAction,
        'hold': holdMs, 'fav': favorite, 'order': order, if (note != null) 'note': note, 'preset': preset,
        if (group != null) 'grp': group,
      };

  /// Returns null for malformed records instead of throwing, so one bad entry cannot break the library.
  static ShortcutItem? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'], name = json['name'];
    final cat = ShortcutCategory.fromId(json['cat']);
    if (id is! String || id.isEmpty || id.length > 80 || name is! String || cat == null) return null;
    final kind = json['kind'] == 'system' ? ShortcutKind.system : ShortcutKind.key;
    final mods = json['mods'], hold = json['hold'], order = json['order'];
    final item = ShortcutItem(
      id: id,
      name: name,
      category: cat,
      iconKey: json['icon'] is String ? json['icon'] as String : 'bolt',
      kind: kind,
      modifiers: mods is int ? mods : 0,
      keyId: json['key'] is String ? json['key'] as String : '',
      systemAction: json['sys'] is String ? json['sys'] as String : null,
      holdMs: hold is int ? hold : 0,
      favorite: json['fav'] == true,
      order: order is int ? order : 0,
      note: json['note'] is String ? json['note'] as String : null,
      preset: json['preset'] == true,
      group: cleanGroup(json['grp']),
    );
    return item.validate() == null ? item : null;
  }
}

/// The shortcuts every install starts with. Ids are stable ("preset.*") so gestures can refer to them.
abstract final class ShortcutDefaults {
  static ShortcutItem _k(String id, String name, ShortcutCategory cat, String icon, int mods, String key,
          {int hold = 0, String? note, bool fav = false}) =>
      ShortcutItem(id: 'preset.$id', name: name, category: cat, iconKey: icon, modifiers: mods, keyId: key,
          holdMs: hold, note: note, favorite: fav, preset: true);

  static ShortcutItem _s(String id, String name, ShortcutCategory cat, String icon, String action) => ShortcutItem(
      id: 'preset.$id', name: name, category: cat, iconKey: icon, kind: ShortcutKind.system, systemAction: action,
      note: SystemActionIds.requirement(action), preset: true);

  static List<ShortcutItem> all() {
    const sys = ShortcutCategory.system, win = ShortcutCategory.window;
    const web = ShortcutCategory.browser, dev = ShortcutCategory.developer;
    const c = Mod.command, s = Mod.shift, ctrl = Mod.control;
    final list = <ShortcutItem>[
      // System
      _k('lock_screen', 'Lock screen', sys, 'lock', ctrl | c, 'q', note: 'Locks immediately. Works on macOS 10.13 and later.'),
      _k('screenshot_full', 'Screenshot: whole screen', sys, 'screenshot', s | c, '3'),
      _k('screenshot_selection', 'Screenshot: selection', sys, 'crop', s | c, '4'),
      _k('screenshot_tool', 'Screenshot toolbar', sys, 'screenshot', s | c, '5'),
      _s('show_desktop', 'Show desktop', sys, 'desktop', SystemActionIds.showDesktop),
      // Window management
      _k('app_switcher', 'App switcher', win, 'apps', c, 'tab', note: 'Switches to the previous app. Add a hold time to keep the switcher open.'),
      _k('minimize_window', 'Minimize window', win, 'minimize', c, 'm'),
      _k('close_window', 'Close window', win, 'close', c, 'w'),
      _k('hide_app', 'Hide app', win, 'window', c, 'h'),
      _k('fullscreen', 'Full screen', win, 'window', ctrl | c, 'f', note: 'Works in apps that support macOS full screen.'),
      _s('mission_control', 'Mission Control', win, 'mission', SystemActionIds.missionControl),
      _s('app_expose', 'App Expos\u00e9', win, 'mission', SystemActionIds.appExpose),
      _s('desktop_left', 'Previous desktop', win, 'arrow_left', SystemActionIds.desktopLeft),
      _s('desktop_right', 'Next desktop', win, 'arrow_right', SystemActionIds.desktopRight),
      // Browser
      _k('new_tab', 'New tab', web, 'tab', c, 't', fav: true, note: 'Browsers and most tabbed apps.'),
      _k('close_tab', 'Close tab', web, 'close', c, 'w', note: 'Same keys as Close window; in a browser it closes the tab.'),
      _k('reopen_tab', 'Reopen closed tab', web, 'undo', s | c, 't'),
      _k('find', 'Find', web, 'search', c, 'f'),
      _k('reload', 'Reload page', web, 'refresh', c, 'r'),
      _k('address_bar', 'Address bar', web, 'search', c, 'l'),
      // Developer: terminal
      _k('term_new_tab', 'Terminal: new tab', dev, 'terminal', c, 't', note: 'Terminal, iTerm2.'),
      _k('term_clear', 'Terminal: clear screen', dev, 'terminal', c, 'k', note: 'Terminal, iTerm2.'),
      _k('term_interrupt', 'Terminal: interrupt (Ctrl-C)', dev, 'terminal', ctrl, 'c', note: 'Stops the running command in a terminal.'),
      _k('term_history', 'Terminal: search history', dev, 'terminal', ctrl, 'r', note: 'Shells with reverse search (zsh, bash).'),
      // Developer: IDE
      _k('ide_build', 'Build', dev, 'build', c, 'b', note: 'Xcode.'),
      _k('ide_run', 'Run', dev, 'play', c, 'r', note: 'Xcode.'),
      _k('ide_quick_open', 'Open quickly', dev, 'code', s | c, 'o', note: 'Xcode. In VS Code use Command-P.'),
      _k('ide_palette', 'Command palette', dev, 'code', s | c, 'p', note: 'VS Code.'),
      _k('ide_comment', 'Toggle comment', dev, 'code', c, 'slash', note: 'Xcode, VS Code, JetBrains.'),
      _k('ide_terminal', 'Toggle terminal panel', dev, 'terminal', ctrl, 'grave', note: 'VS Code.'),
    ];
    return [for (var i = 0; i < list.length; i++) list[i].copyWith(order: i)];
  }
}
