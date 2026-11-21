import 'dart:convert';

import 'shortcut_model.dart';

/// Result of reading a pasted preset pack. [items] are ready to add (fresh ids, never marked built-in).
class PackImport {
  const PackImport({this.items = const [], this.groups = const [], this.skipped = 0, this.error});
  final List<ShortcutItem> items;
  final List<String> groups;
  /// Entries that were present but invalid.
  final int skipped;
  /// Set when nothing could be read at all (the text is not a MacTouch pack).
  final String? error;
}

/// Import/export of shortcut presets as plain JSON text, so it works with copy and paste and needs no extra permissions.
abstract final class ShortcutPack {
  static const format = 'mactouch.shortcuts';
  static const maxChars = 200000;
  static const maxItems = 300;

  static Map<String, dynamic> _exportJson(ShortcutItem i) {
    final m = i.toJson();
    m.remove('id');
    m.remove('order');
    m.remove('preset');
    return m;
  }

  static String encode(Iterable<ShortcutItem> items, Iterable<String> groups) {
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': 1,
      'categories': groups.toList(),
      'shortcuts': [for (final i in items) _exportJson(i)],
    });
  }

  /// [newId] must return a fresh unique id each call.
  static PackImport decode(String text, {required String Function() newId}) {
    if (text.trim().isEmpty) return const PackImport(error: 'Nothing to import. Paste the preset text first.');
    if (text.length > maxChars) return const PackImport(error: 'That text is too long to be a shortcut pack.');
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      return const PackImport(error: 'That is not valid preset text. Copy the whole export and try again.');
    }
    if (root is! Map<String, dynamic> || root['format'] != format) {
      return const PackImport(error: 'That text is not a MacTouch shortcut pack.');
    }
    final list = root['shortcuts'];
    if (list is! List) return const PackImport(error: 'The pack has no shortcuts.');

    final items = <ShortcutItem>[];
    var skipped = 0;
    for (final raw in list.take(maxItems)) {
      if (raw is! Map<String, dynamic>) {
        skipped++;
        continue;
      }
      final item = ShortcutItem.tryFromJson({...raw, 'id': 'import', 'order': 0});
      if (item == null) {
        skipped++;
        continue;
      }
      items.add(ShortcutItem(
        id: newId(), name: item.name, category: item.category, iconKey: item.iconKey, kind: item.kind,
        modifiers: item.modifiers, keyId: item.keyId, systemAction: item.systemAction, holdMs: item.holdMs,
        favorite: item.favorite, note: item.note, group: item.group,
      ));
    }
    if (list.length > maxItems) skipped += list.length - maxItems;

    final groups = <String>{};
    final cats = root['categories'];
    if (cats is List) {
      for (final c in cats) {
        final g = ShortcutItem.cleanGroup(c);
        if (g != null) groups.add(g);
      }
    }
    for (final i in items) {
      if (i.group != null) groups.add(i.group!);
    }
    if (items.isEmpty) return PackImport(skipped: skipped, error: 'No valid shortcuts found in that text.');
    return PackImport(items: items, groups: groups.toList(), skipped: skipped);
  }
}
