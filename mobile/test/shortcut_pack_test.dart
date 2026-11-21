import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mactouch_mobile/core/shortcuts/shortcut_library.dart';
import 'package:mactouch_mobile/core/shortcuts/shortcut_model.dart';
import 'package:mactouch_mobile/core/shortcuts/shortcut_pack.dart';

ShortcutItem _item(String id, {String name = 'Thing', String key = 't', int mods = Mod.command, String? group, ShortcutCategory cat = ShortcutCategory.custom, bool fav = false, bool preset = false}) =>
    ShortcutItem(id: id, name: name, category: cat, modifiers: mods, keyId: key, group: group, favorite: fav, preset: preset);

String Function() _ids() {
  var n = 0;
  return () => 'new.${n++}';
}

void main() {
  group('custom categories (group)', () {
    test('cleanGroup trims and rejects empty, too long and non-strings', () {
      expect(ShortcutItem.cleanGroup('  Design  '), 'Design');
      expect(ShortcutItem.cleanGroup(''), isNull);
      expect(ShortcutItem.cleanGroup('   '), isNull);
      expect(ShortcutItem.cleanGroup('x' * 31), isNull);
      expect(ShortcutItem.cleanGroup('x' * 30), isNotNull);
      expect(ShortcutItem.cleanGroup(5), isNull);
    });

    test('a group survives serialization and shows as the category label only for Custom shortcuts', () {
      final item = _item('a', group: 'Photoshop');
      final back = ShortcutItem.tryFromJson(jsonDecode(jsonEncode(item.toJson())))!;
      expect(back.group, 'Photoshop');
      expect(back.categoryLabel, 'Photoshop');
      expect(_item('b').categoryLabel, 'Custom');
      expect(_item('c', cat: ShortcutCategory.browser, group: 'Stray').categoryLabel, 'Browser', reason: 'only Custom shortcuts use the group name');
      expect(item.toJson().containsKey('grp'), isTrue);
      expect(_item('d').toJson().containsKey('grp'), isFalse, reason: 'existing data stays unchanged');
    });

    test('copyWith can set and clear a group', () {
      final item = _item('a', group: 'X');
      expect(item.copyWith(group: 'Y').group, 'Y');
      expect(item.copyWith(clearGroup: true).group, isNull);
      expect(item.copyWith(name: 'Other').group, 'X');
    });

    test('the library filters, renames and deletes groups', () {
      var lib = ShortcutLibrary([_item('a', group: 'Design'), _item('b', group: 'Design'), _item('c', group: 'Video'), _item('d')]);
      expect(lib.search(group: 'Design').map((i) => i.id), ['a', 'b']);
      expect(lib.search(category: ShortcutCategory.custom).length, 4);
      expect(lib.groupsInUse, {'Design', 'Video'});
      expect(lib.search(query: 'video').map((i) => i.id), ['c'], reason: 'search also matches the category name');

      lib = lib.renameGroup('Design', 'Graphics');
      expect(lib.search(group: 'Graphics').length, 2);
      expect(lib.search(group: 'Design'), isEmpty);

      lib = lib.deleteGroup('Graphics');
      expect(lib.groupsInUse, {'Video'});
      expect(lib.byId('a'), isNotNull, reason: 'shortcuts are kept');
      expect(lib.byId('a')!.group, isNull);
      expect(lib.byId('a')!.category, ShortcutCategory.custom);
    });

    test('reordering within a group keeps other items in place', () {
      final lib = ShortcutLibrary([_item('a', group: 'G', ), _item('x'), _item('b', group: 'G'), _item('y'), _item('c', group: 'G')]);
      final visible = lib.search(group: 'G').map((i) => i.id).toList();
      final moved = lib.reorder(visible, 2, 0);
      expect(moved.search(group: 'G').map((i) => i.id), ['c', 'a', 'b']);
      expect(moved.items.map((i) => i.id), ['c', 'x', 'a', 'y', 'b']);
    });
  });

  group('pack export', () {
    test('uses a recognisable format and leaves out ids, order and the built-in flag', () {
      final text = ShortcutPack.encode([_item('custom.1', name: 'Mine', group: 'G', fav: true, preset: true)], ['G', 'Empty']);
      final json = jsonDecode(text) as Map<String, dynamic>;
      expect(json['format'], 'mactouch.shortcuts');
      expect(json['version'], 1);
      expect(json['categories'], ['G', 'Empty']);
      final s = (json['shortcuts'] as List).single as Map<String, dynamic>;
      expect(s['name'], 'Mine');
      expect(s['fav'], true);
      expect(s.containsKey('id'), isFalse);
      expect(s.containsKey('order'), isFalse);
      expect(s.containsKey('preset'), isFalse);
    });
  });

  group('pack import', () {
    final good = ShortcutPack.encode([
      _item('1', name: 'One', key: 'n', mods: Mod.command | Mod.shift, group: 'Finder'),
      _item('2', name: 'Two', key: 'f11', mods: 0),
    ], ['Finder', 'Spare']);

    test('round trip: fresh ids, never built-in, category and favorites kept', () {
      final r = ShortcutPack.decode(good, newId: _ids());
      expect(r.error, isNull);
      expect(r.items.map((i) => i.name), ['One', 'Two']);
      expect(r.items.map((i) => i.id), ['new.0', 'new.1']);
      expect(r.items.every((i) => !i.preset), isTrue);
      expect(r.items.first.group, 'Finder');
      expect(r.items.first.modifiers, Mod.command | Mod.shift);
      expect(r.items.first.keyId, 'n');
      expect(r.groups.toSet(), {'Finder', 'Spare'});
      expect(r.skipped, 0);
    });

    test('an imported pack can never overwrite an existing shortcut (ids are always new)', () {
      final lib = ShortcutLibrary([_item('custom.1', name: 'Keep me')]);
      final r = ShortcutPack.decode(good, newId: _ids());
      var next = lib;
      for (final i in r.items) {
        next = next.add(i);
      }
      expect(next.byId('custom.1')!.name, 'Keep me');
      expect(next.items.length, 3);
    });

    test('invalid entries are skipped and counted; valid ones still import', () {
      final text = jsonEncode({
        'format': 'mactouch.shortcuts',
        'version': 1,
        'shortcuts': [
          {'name': 'Fine', 'cat': 'custom', 'key': 'a', 'mods': 8},
          {'name': '', 'cat': 'custom', 'key': 'a'},
          {'name': 'No key', 'cat': 'custom', 'key': 'doesnotexist'},
          {'name': 'Bad category', 'cat': 'nope', 'key': 'a'},
          {'name': 'Hold too long', 'cat': 'custom', 'key': 'a', 'hold': 99999},
          'garbage',
        ],
      });
      final r = ShortcutPack.decode(text, newId: _ids());
      expect(r.error, isNull);
      expect(r.items.map((i) => i.name), ['Fine']);
      expect(r.skipped, 5);
    });

    test('text that is not a pack is refused with a clear message', () {
      for (final bad in ['', '   ', 'hello', '[1,2,3]', '{"format":"other","shortcuts":[]}', '{"format":"mactouch.shortcuts"}', '{"format":"mactouch.shortcuts","shortcuts":"x"}']) {
        final r = ShortcutPack.decode(bad, newId: _ids());
        expect(r.error, isNotNull, reason: bad);
        expect(r.items, isEmpty);
      }
    });

    test('a pack with only invalid shortcuts reports that nothing was importable', () {
      final r = ShortcutPack.decode('{"format":"mactouch.shortcuts","shortcuts":[{"name":""}]}', newId: _ids());
      expect(r.error, isNotNull);
      expect(r.skipped, 1);
    });

    test('oversized input and oversized packs are limited', () {
      expect(ShortcutPack.decode('x' * (ShortcutPack.maxChars + 1), newId: _ids()).error, isNotNull);
      final many = jsonEncode({
        'format': 'mactouch.shortcuts',
        'shortcuts': [for (var i = 0; i < ShortcutPack.maxItems + 20; i++) {'name': 'S$i', 'cat': 'custom', 'key': 'a'}],
      });
      final r = ShortcutPack.decode(many, newId: _ids());
      expect(r.items.length, ShortcutPack.maxItems);
      expect(r.skipped, 20);
    });

    test('unusable category names are ignored, and imported shortcuts keep a usable one', () {
      final text = jsonEncode({
        'format': 'mactouch.shortcuts',
        'categories': ['Good', '', 5, 'x' * 40],
        'shortcuts': [{'name': 'A', 'cat': 'custom', 'key': 'a', 'grp': 'Other'}],
      });
      final r = ShortcutPack.decode(text, newId: _ids());
      expect(r.groups.toSet(), {'Good', 'Other'});
    });
  });
}
