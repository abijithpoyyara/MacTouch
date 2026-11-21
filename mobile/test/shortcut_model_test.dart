import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mactouch_mobile/core/shortcuts/key_catalog.dart';
import 'package:mactouch_mobile/core/shortcuts/shortcut_library.dart';
import 'package:mactouch_mobile/core/shortcuts/shortcut_model.dart';
import 'package:mactouch_mobile/core/shortcuts/system_actions.dart';

ShortcutItem _item(String id, {String name = 'Thing', int mods = Mod.command, String key = 't', ShortcutCategory cat = ShortcutCategory.custom, int order = 0, bool fav = false}) =>
    ShortcutItem(id: id, name: name, category: cat, modifiers: mods, keyId: key, order: order, favorite: fav);

void main() {
  group('serialization', () {
    test('a key shortcut survives a JSON round trip with every field', () {
      const item = ShortcutItem(
        id: 'custom.1', name: 'Lock', category: ShortcutCategory.system, iconKey: 'lock', modifiers: Mod.control | Mod.command,
        keyId: 'q', holdMs: 250, favorite: true, order: 3, note: 'works on 10.13+',
      );
      final back = ShortcutItem.tryFromJson(jsonDecode(jsonEncode(item.toJson())))!;
      expect(back.id, 'custom.1');
      expect(back.name, 'Lock');
      expect(back.category, ShortcutCategory.system);
      expect(back.iconKey, 'lock');
      expect(back.modifiers, Mod.control | Mod.command);
      expect(back.keyId, 'q');
      expect(back.holdMs, 250);
      expect(back.favorite, isTrue);
      expect(back.order, 3);
      expect(back.note, 'works on 10.13+');
      expect(back.kind, ShortcutKind.key);
    });

    test('a system shortcut round trips and keeps its action', () {
      final item = ShortcutDefaults.all().firstWhere((s) => s.id == 'preset.mission_control');
      final back = ShortcutItem.tryFromJson(jsonDecode(jsonEncode(item.toJson())))!;
      expect(back.kind, ShortcutKind.system);
      expect(back.systemAction, SystemActionIds.missionControl);
      expect(back.preset, isTrue);
    });

    test('malformed records are rejected instead of throwing', () {
      for (final bad in <Object?>[
        null, 5, 'x', {}, {'id': 'a'}, {'id': '', 'name': 'n', 'cat': 'system'},
        {'id': 'a', 'name': 'n', 'cat': 'nope', 'key': 't'},
        {'id': 'a', 'name': '', 'cat': 'system', 'key': 't'},                       // empty name
        {'id': 'a', 'name': 'n', 'cat': 'system', 'key': 'unknown-key'},            // unresolvable key
        {'id': 'a', 'name': 'n', 'cat': 'system', 'key': 't', 'hold': 99999},       // hold out of range
        {'id': 'a', 'name': 'n', 'cat': 'system', 'key': 't', 'mods': 99},
        {'id': 'a', 'name': 'n', 'cat': 'system', 'kind': 'system', 'sys': 'reboot'},
      ]) {
        expect(ShortcutItem.tryFromJson(bad), isNull, reason: '$bad');
      }
    });

    test('the whole library round trips; bad entries and corrupt text fall back safely', () {
      final lib = ShortcutLibrary.defaults().add(_item('custom.x', name: 'Mine'));
      final back = ShortcutLibrary.fromJsonString(lib.toJsonString());
      expect(back.items.length, lib.items.length);
      expect(back.byId('custom.x')?.name, 'Mine');

      final withBad = jsonEncode({'v': 1, 'items': [_item('ok.1').toJson(), {'id': 'bad'}, 7]});
      expect(ShortcutLibrary.fromJsonString(withBad).items.map((i) => i.id), ['ok.1']);

      expect(ShortcutLibrary.fromJsonString(null).items, isNotEmpty);
      expect(ShortcutLibrary.fromJsonString('{{{not json').items.length, ShortcutDefaults.all().length);
      expect(ShortcutLibrary.fromJsonString('{"items": 5}').items.length, ShortcutDefaults.all().length);
    });
  });

  group('key combinations and events', () {
    test('modifier symbols are always in control, option, shift, command order', () {
      expect(Mod.symbols(Mod.command), '\u2318');
      expect(Mod.symbols(Mod.shift | Mod.command), '\u21e7\u2318');
      expect(Mod.symbols(Mod.command | Mod.option | Mod.shift | Mod.control), '\u2303\u2325\u21e7\u2318');
      expect(Mod.symbols(0), '');
    });

    test('combo label', () {
      expect(_item('a', mods: Mod.shift | Mod.command, key: 't').combo, '\u21e7\u2318T');
      expect(_item('a', mods: Mod.control, key: 'left').combo, '\u2303\u2190');
    });

    test('toEvent builds the wire event; zero modifiers and zero hold are omitted', () {
      const map = KeyMap();
      expect(_item('a', mods: Mod.command, key: 't').toEvent(map), {'e': 'shortcut', 'c': 17, 'm': 8});
      expect(_item('a', mods: 0, key: 'return').toEvent(map), {'e': 'shortcut', 'c': 36});
      expect(_item('a', mods: Mod.command, key: 'tab').copyWith(holdMs: 600).toEvent(map), {'e': 'shortcut', 'c': 48, 'm': 8, 'h': 600});
      final sys = ShortcutDefaults.all().firstWhere((s) => s.id == 'preset.app_expose');
      expect(sys.toEvent(map), {'e': 'sys', 'a': 'app_expose'});
    });

    test('an unresolvable key gives no event instead of a wrong one', () {
      expect(_item('a', key: 'nonsense').toEvent(const KeyMap()), isNull);
    });

    test('validate explains what is wrong', () {
      expect(_item('a', name: '  ').validate(), isNotNull);
      expect(_item('a', key: '').validate(), isNotNull);
      expect(_item('a', name: 'x' * 41).validate(), isNotNull);
      expect(_item('a').copyWith(holdMs: 6000).validate(), isNotNull);
      expect(_item('a').validate(), isNull);
    });
  });

  group('key mapping', () {
    test('defaults follow the US layout', () {
      const m = KeyMap();
      expect(m.codeFor('a'), 0);
      expect(m.codeFor('t'), 17);
      expect(m.codeFor('return'), 36);
      expect(m.codeFor('f11'), 103);
      expect(m.codeFor('left'), 123);
      expect(m.codeFor('nope'), isNull);
    });

    test('overrides win, can be removed, and are validated', () {
      final m = const KeyMap().withOverride('z', 12);
      expect(m.codeFor('z'), 12);
      expect(m.isOverridden('z'), isTrue);
      expect(m.without('z').codeFor('z'), 6);
      expect(() => const KeyMap().withOverride('z', 300), throwsArgumentError);
      expect(() => const KeyMap().withOverride('z', -1), throwsArgumentError);
    });

    test('raw key codes work for keys that are not in the catalog', () {
      expect(const KeyMap().codeFor(KeyCatalog.rawId(114)), 114);
      expect(const KeyMap().codeFor('code:999'), isNull);
      expect(KeyCatalog.label('code:114'), 'Key 114');
      final item = ShortcutItem(id: 'x', name: 'Help', category: ShortcutCategory.custom, keyId: KeyCatalog.rawId(114));
      expect(item.validate(), isNull);
      expect(item.toEvent(const KeyMap()), {'e': 'shortcut', 'c': 114});
    });

    test('an overridden key is what gets sent', () {
      final m = const KeyMap().withOverride('t', 99);
      expect(_item('a', key: 't').toEvent(m), {'e': 'shortcut', 'c': 99, 'm': 8});
    });

    test('serialization drops invalid overrides', () {
      final m = KeyMap.fromJson({'overrides': {'t': 99, 'zzz': 5, 'a': 999, 'b': 'x'}});
      expect(m.overrides, {'t': 99});
      expect(KeyMap.fromJson(null).overrides, isEmpty);
      expect(KeyMap.fromJson(jsonDecode(jsonEncode(const KeyMap({'q': 7}).toJson()))).overrides, {'q': 7});
    });

    test('catalog ids and codes are unique, and search finds keys', () {
      expect(KeyCatalog.keys.map((k) => k.id).toSet().length, KeyCatalog.keys.length);
      expect(KeyCatalog.keys.map((k) => k.code).toSet().length, KeyCatalog.keys.length);
      expect(KeyCatalog.keys.every((k) => k.code >= 0 && k.code <= 255), isTrue);
      expect(KeyCatalog.search('f1').map((k) => k.id), containsAll(['f1', 'f10', 'f11', 'f12']));
      expect(KeyCatalog.search('arrows'), hasLength(4));
    });
  });

  group('library', () {
    test('defaults cover the required categories and every preset is valid and has a unique id', () {
      final lib = ShortcutLibrary.defaults();
      for (final c in [ShortcutCategory.system, ShortcutCategory.window, ShortcutCategory.browser, ShortcutCategory.developer]) {
        expect(lib.search(category: c), isNotEmpty, reason: c.label);
      }
      expect(lib.items.every((i) => i.validate() == null), isTrue);
      expect(lib.items.map((i) => i.id).toSet().length, lib.items.length);
      for (final name in ['Lock screen', 'Show desktop', 'App switcher', 'Minimize window', 'Close window', 'Mission Control',
        'New tab', 'Close tab', 'Reopen closed tab', 'Find']) {
        expect(lib.items.any((i) => i.name == name), isTrue, reason: name);
      }
      expect(lib.search(category: ShortcutCategory.developer).length, greaterThanOrEqualTo(8));
      expect(lib.items.map((i) => i.order), List.generate(lib.items.length, (i) => i));
    });

    test('gesture defaults point at shortcuts that exist', () {
      expect(ShortcutLibrary.defaults().byId('preset.app_switcher'), isNotNull);
    });

    test('add appends, update keeps the order, delete removes', () {
      var lib = ShortcutLibrary([_item('a', order: 0), _item('b', order: 1)]);
      lib = lib.add(_item('c'));
      expect(lib.items.map((i) => i.id), ['a', 'b', 'c']);
      lib = lib.update(_item('b', name: 'Renamed'));
      expect(lib.byId('b')!.name, 'Renamed');
      expect(lib.items.map((i) => i.id), ['a', 'b', 'c']);
      lib = lib.delete('a');
      expect(lib.items.map((i) => i.id), ['b', 'c']);
      expect(lib.items.map((i) => i.order), [0, 1]);
    });

    test('favorites toggle', () {
      var lib = ShortcutLibrary([_item('a')]).toggleFavorite('a');
      expect(lib.byId('a')!.favorite, isTrue);
      expect(lib.search(favoritesOnly: true), hasLength(1));
      lib = lib.toggleFavorite('a');
      expect(lib.search(favoritesOnly: true), isEmpty);
    });

    test('reorder moves an item (ReorderableListView semantics)', () {
      final lib = ShortcutLibrary([for (var i = 0; i < 5; i++) _item('i$i', order: i)]);
      final ids = lib.items.map((i) => i.id).toList();
      expect(lib.reorder(ids, 0, 3).items.map((i) => i.id), ['i1', 'i2', 'i0', 'i3', 'i4'], reason: 'down: newIndex is adjusted');
      expect(lib.reorder(ids, 4, 1).items.map((i) => i.id), ['i0', 'i4', 'i1', 'i2', 'i3']);
      expect(lib.reorder(ids, 2, 2).items.map((i) => i.id), ids, reason: 'no-op');
      expect(lib.reorder(ids, 9, 0).items.map((i) => i.id), ids, reason: 'bad index is ignored');
      expect(lib.reorder(ids, 0, 5).items.map((i) => i.id), ['i1', 'i2', 'i3', 'i4', 'i0'], reason: 'to the very end');
    });

    test('reordering a filtered view keeps hidden items where they were', () {
      final lib = ShortcutLibrary([
        _item('w1', cat: ShortcutCategory.window, order: 0),
        _item('b1', cat: ShortcutCategory.browser, order: 1),
        _item('w2', cat: ShortcutCategory.window, order: 2),
        _item('b2', cat: ShortcutCategory.browser, order: 3),
        _item('w3', cat: ShortcutCategory.window, order: 4),
      ]);
      final visible = lib.search(category: ShortcutCategory.window).map((i) => i.id).toList();
      expect(visible, ['w1', 'w2', 'w3']);
      final moved = lib.reorder(visible, 2, 0);                      // w3 to the top of the window list
      expect(moved.search(category: ShortcutCategory.window).map((i) => i.id), ['w3', 'w1', 'w2']);
      expect(moved.search(category: ShortcutCategory.browser).map((i) => i.id), ['b1', 'b2']);
      expect(moved.items.map((i) => i.id), ['w3', 'b1', 'w1', 'b2', 'w2'], reason: 'browser items stay in slots 1 and 3');
      expect(moved.items.map((i) => i.order), [0, 1, 2, 3, 4]);
    });

    test('search is case-insensitive, matches name, category, combo and note, and needs every word', () {
      final lib = ShortcutLibrary.defaults();
      expect(lib.search(query: 'LOCK').map((i) => i.name), contains('Lock screen'));
      expect(lib.search(query: 'browser').every((i) => i.category == ShortcutCategory.browser || i.note?.toLowerCase().contains('browser') == true || i.name.toLowerCase().contains('browser')), isTrue);
      expect(lib.search(query: '\u2318T').map((i) => i.name), contains('New tab'));
      expect(lib.search(query: 'xcode').map((i) => i.name), containsAll(['Build', 'Run']));
      expect(lib.search(query: 'new tab').map((i) => i.name), contains('New tab'));
      expect(lib.search(query: 'tab nonexistentword'), isEmpty);
      expect(lib.search(query: '   ').length, lib.items.length);
      expect(lib.search(query: 'tab', category: ShortcutCategory.browser).every((i) => i.category == ShortcutCategory.browser), isTrue);
    });

    test('restoreDefaults brings back presets, keeps custom shortcuts, resets preset edits and deletions', () {
      var lib = ShortcutLibrary.defaults();
      lib = lib.delete('preset.find').update(lib.byId('preset.new_tab')!.copyWith(name: 'Mangled'));
      lib = lib.add(_item('custom.mine', name: 'Mine'));
      final restored = lib.restoreDefaults();
      expect(restored.byId('preset.find'), isNotNull);
      expect(restored.byId('preset.new_tab')!.name, 'New tab');
      expect(restored.byId('custom.mine')!.name, 'Mine');
      expect(restored.items.last.id, 'custom.mine');
      expect(restored.items.length, ShortcutDefaults.all().length + 1);
    });

    test('newId never collides', () {
      var lib = ShortcutLibrary([]);
      for (var i = 0; i < 50; i++) {
        lib = lib.add(_item(lib.newId()));
      }
      expect(lib.items.length, 50);
    });
  });
}
