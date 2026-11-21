import 'dart:convert';

import 'shortcut_model.dart';

/// The user's shortcut collection. Immutable: every change returns a new library.
class ShortcutLibrary {
  ShortcutLibrary(Iterable<ShortcutItem> items) : _items = _normalized(items);

  final List<ShortcutItem> _items;

  List<ShortcutItem> get items => List.unmodifiable(_items);

  static ShortcutLibrary defaults() => ShortcutLibrary(ShortcutDefaults.all());

  static List<ShortcutItem> _normalized(Iterable<ShortcutItem> items) {
    final seen = <String>{};
    final sorted = items.where((i) => seen.add(i.id)).toList()..sort((a, b) => a.order.compareTo(b.order));
    return [for (var i = 0; i < sorted.length; i++) sorted[i].copyWith(order: i)];
  }

  ShortcutItem? byId(String id) {
    for (final i in _items) {
      if (i.id == id) return i;
    }
    return null;
  }

  String newId() {
    final base = DateTime.now().microsecondsSinceEpoch;
    var n = 0;
    while (byId('custom.${base + n}') != null) {
      n++;
    }
    return 'custom.${base + n}';
  }

  /// Appends [item] at the end of the list.
  ShortcutLibrary add(ShortcutItem item) =>
      ShortcutLibrary([..._items.where((i) => i.id != item.id), item.copyWith(order: _items.length)]);

  ShortcutLibrary update(ShortcutItem item) =>
      ShortcutLibrary([for (final i in _items) i.id == item.id ? item.copyWith(order: i.order) : i]);

  ShortcutLibrary delete(String id) => ShortcutLibrary(_items.where((i) => i.id != id));

  ShortcutLibrary toggleFavorite(String id) =>
      ShortcutLibrary([for (final i in _items) i.id == id ? i.copyWith(favorite: !i.favorite) : i]);

  /// Moves one entry of the *visible* list (what a ReorderableListView shows) and re-assigns the display order
  /// among exactly those entries, so entries that are filtered out keep their place.
  /// [newIndex] follows ReorderableListView's convention (it is adjusted when moving down).
  ShortcutLibrary reorder(List<String> visibleIds, int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= visibleIds.length) return this;
    if (newIndex > oldIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, visibleIds.length - 1).toInt();
    final ids = List<String>.of(visibleIds);
    ids.insert(newIndex, ids.removeAt(oldIndex));
    final slots = [for (final id in visibleIds) byId(id)?.order ?? 0]..sort();
    final newOrder = {for (var i = 0; i < ids.length; i++) ids[i]: slots[i]};
    return ShortcutLibrary([for (final i in _items) newOrder.containsKey(i.id) ? i.copyWith(order: newOrder[i.id]) : i]);
  }

  /// Names of the user-defined categories that at least one shortcut uses.
  Set<String> get groupsInUse => {for (final i in _items) if (i.group != null) i.group!};

  ShortcutLibrary renameGroup(String from, String to) =>
      ShortcutLibrary([for (final i in _items) i.group == from ? i.copyWith(group: to) : i]);

  /// Shortcuts in the deleted category stay, as plain Custom shortcuts.
  ShortcutLibrary deleteGroup(String name) =>
      ShortcutLibrary([for (final i in _items) i.group == name ? i.copyWith(clearGroup: true) : i]);

  /// Replaces the built-in shortcuts with the defaults and keeps everything the user created.
  /// Custom entries go after the defaults; favorites on defaults are reset.
  ShortcutLibrary restoreDefaults() {
    final custom = _items.where((i) => !i.preset).toList();
    final defaults = ShortcutDefaults.all();
    return ShortcutLibrary([
      ...defaults,
      for (var i = 0; i < custom.length; i++) custom[i].copyWith(order: defaults.length + i),
    ]);
  }

  /// Case-insensitive; every word of [query] must match the name, category, key combination or note.
  /// [group] narrows Custom shortcuts to one user-defined category.
  List<ShortcutItem> search({String query = '', ShortcutCategory? category, bool favoritesOnly = false, String? group}) {
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return _items.where((i) {
      if (category != null && i.category != category) return false;
      if (group != null && i.group != group) return false;
      if (favoritesOnly && !i.favorite) return false;
      if (words.isEmpty) return true;
      final hay = '${i.name} ${i.categoryLabel} ${i.category.label} ${i.combo} ${i.note ?? ''}'.toLowerCase();
      return words.every(hay.contains);
    }).toList();
  }

  String toJsonString() => jsonEncode({'v': 1, 'items': [for (final i in _items) i.toJson()]});

  /// Never throws: null, corrupt or empty data gives the defaults; individual bad entries are skipped.
  static ShortcutLibrary fromJsonString(String? text) {
    if (text == null) return defaults();
    try {
      final root = jsonDecode(text);
      if (root is! Map<String, dynamic> || root['items'] is! List) return defaults();
      final items = <ShortcutItem>[];
      for (final raw in root['items'] as List) {
        final item = ShortcutItem.tryFromJson(raw);
        if (item != null) items.add(item);
      }
      return ShortcutLibrary(items);
    } on FormatException {
      return defaults();
    }
  }
}
