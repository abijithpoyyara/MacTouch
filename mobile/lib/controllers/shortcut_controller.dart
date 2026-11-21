import 'dart:convert';

import 'package:get/get.dart';

import '../core/shortcuts/key_catalog.dart';
import '../core/shortcuts/shortcut_library.dart';
import '../core/shortcuts/shortcut_model.dart';
import '../core/shortcuts/shortcut_pack.dart';
import '../data/services/settings_service.dart';

/// The shortcut library (add, edit, delete, reorder, favorites, search), the user's own categories, preset import/export,
/// and the key mapping, persisted locally.
class ShortcutController extends GetxController {
  ShortcutController(this._store);
  final SettingsService _store;

  static const _libraryKey = 'shortcuts.v1';
  static const _mapKey = 'keymap.v1';
  static const _groupsKey = 'shortcut.groups.v1';
  static const maxGroups = 20;

  final library = ShortcutLibrary.defaults().obs;
  final keyMap = const KeyMap().obs;
  /// User-defined categories, in the order the user created them (includes empty ones).
  final groups = <String>[].obs;

  final query = ''.obs;
  final category = Rxn<ShortcutCategory>();
  /// When set (with category == custom), only that user-defined category is shown.
  final group = RxnString();
  final favoritesOnly = false.obs;
  final reorderMode = false.obs;

  @override
  void onInit() {
    super.onInit();
    library.value = ShortcutLibrary.fromJsonString(_store.getString(_libraryKey));
    final raw = _store.getString(_mapKey);
    if (raw != null) {
      try {
        keyMap.value = KeyMap.fromJson(jsonDecode(raw));
      } on FormatException {
        keyMap.value = const KeyMap();
      }
    }
    final g = _store.getString(_groupsKey);
    if (g != null) {
      try {
        final list = jsonDecode(g);
        if (list is List) {
          for (final n in list) {
            final name = ShortcutItem.cleanGroup(n);
            if (name != null && !groups.contains(name)) groups.add(name);
          }
        }
      } on FormatException {
        // ignore a corrupt list; groups in use are still derived from the shortcuts
      }
    }
  }

  List<ShortcutItem> get visible => library.value.search(
        query: query.value,
        category: category.value,
        favoritesOnly: favoritesOnly.value,
        group: group.value,
      );

  /// Every user-defined category: the saved list plus any a shortcut still refers to.
  List<String> get allGroups {
    final out = <String>[...groups];
    for (final g in library.value.groupsInUse) {
      if (!out.contains(g)) out.add(g);
    }
    return out;
  }

  /// Dragging only makes sense when nothing but the category/favorites filter is applied.
  bool get canReorder => query.value.trim().isEmpty;

  ShortcutItem? byId(String id) => library.value.byId(id);

  void add(ShortcutItem item) => _setLibrary(library.value.add(item));
  void updateItem(ShortcutItem item) => _setLibrary(library.value.update(item));
  void delete(String id) => _setLibrary(library.value.delete(id));
  void toggleFavorite(String id) => _setLibrary(library.value.toggleFavorite(id));
  void restoreDefaults() => _setLibrary(library.value.restoreDefaults());

  void reorder(int oldIndex, int newIndex) =>
      _setLibrary(library.value.reorder([for (final i in visible) i.id], oldIndex, newIndex));

  String newId() => library.value.newId();

  // MARK: custom categories

  /// Returns an error message, or null when the category was created.
  String? addGroup(String raw) {
    final name = ShortcutItem.cleanGroup(raw);
    if (name == null) return 'Use a name of 1 to ${ShortcutItem.maxGroupLength} characters.';
    if (allGroups.any((g) => g.toLowerCase() == name.toLowerCase())) return 'You already have a category called \u201c$name\u201d.';
    if (allGroups.length >= maxGroups) return 'You can have up to $maxGroups categories.';
    groups.add(name);
    _saveGroups();
    return null;
  }

  String? renameGroup(String from, String raw) {
    final name = ShortcutItem.cleanGroup(raw);
    if (name == null) return 'Use a name of 1 to ${ShortcutItem.maxGroupLength} characters.';
    if (name != from && allGroups.any((g) => g.toLowerCase() == name.toLowerCase())) return 'You already have a category called \u201c$name\u201d.';
    final i = groups.indexOf(from);
    if (i >= 0) {
      groups[i] = name;
    } else {
      groups.add(name);
    }
    _saveGroups();
    _setLibrary(library.value.renameGroup(from, name));
    if (group.value == from) group.value = name;
    return null;
  }

  /// Shortcuts in the category are kept as plain Custom shortcuts.
  void deleteGroup(String name) {
    groups.remove(name);
    _saveGroups();
    _setLibrary(library.value.deleteGroup(name));
    if (group.value == name) {
      group.value = null;
      category.value = ShortcutCategory.custom;
    }
  }

  // MARK: import / export

  /// Text for the clipboard. By default only the user's own shortcuts are exported.
  String exportText({bool includeBuiltIn = false}) {
    final items = library.value.items.where((i) => includeBuiltIn || !i.preset);
    return ShortcutPack.encode(items, allGroups);
  }

  PackImport readPack(String text) => ShortcutPack.decode(text, newId: _freshIdMaker());

  /// Adds the imported shortcuts (always as new entries) and their categories. Returns how many were added.
  int importPack(PackImport pack) {
    if (pack.error != null || pack.items.isEmpty) return 0;
    var lib = library.value;
    for (final item in pack.items) {
      lib = lib.add(item);
    }
    for (final g in pack.groups) {
      if (!allGroups.any((x) => x.toLowerCase() == g.toLowerCase()) && allGroups.length < maxGroups) groups.add(g);
    }
    _saveGroups();
    _setLibrary(lib);
    return pack.items.length;
  }

  String Function() _freshIdMaker() {
    var n = 0;
    final base = DateTime.now().microsecondsSinceEpoch;
    return () => 'custom.${base + n++}';
  }

  // MARK: key mapping

  void setKeyCode(String keyId, int code) {
    keyMap.value = keyMap.value.withOverride(keyId, code);
    _saveMap();
  }

  void resetKey(String keyId) {
    keyMap.value = keyMap.value.without(keyId);
    _saveMap();
  }

  void resetKeyMap() {
    keyMap.value = const KeyMap();
    _saveMap();
  }

  /// The event to send for [item] with the user's key mapping, or null if its key cannot be resolved.
  Map<String, dynamic>? eventFor(ShortcutItem item) => item.toEvent(keyMap.value);

  void _setLibrary(ShortcutLibrary next) {
    library.value = next;
    _store.setString(_libraryKey, next.toJsonString());
  }

  void _saveGroups() => _store.setString(_groupsKey, jsonEncode(groups.toList()));
  void _saveMap() => _store.setString(_mapKey, jsonEncode(keyMap.value.toJson()));
}
