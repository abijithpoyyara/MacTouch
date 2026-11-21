import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mactouch_mobile/core/prefs/accent.dart';
import 'package:mactouch_mobile/core/prefs/app_prefs.dart';
import 'package:mactouch_mobile/core/theme/app_theme.dart';

void main() {
  group('AppPrefs', () {
    test('defaults', () {
      const p = AppPrefs();
      expect(p.accentId, 'violet');
      expect(p.haptics, isTrue);
      expect(p.showHints, isTrue);
      expect(p.showQuickBar, isTrue);
      expect(p.orientation, OrientationPref.auto);
      expect(p.onboardingDone, isFalse);
    });

    test('survives a JSON round trip', () {
      const p = AppPrefs(accentId: 'teal', haptics: false, showHints: false, showQuickBar: false, orientation: OrientationPref.landscape, onboardingDone: true);
      final back = AppPrefs.fromJson(jsonDecode(jsonEncode(p.toJson())));
      expect(back.accentId, 'teal');
      expect(back.haptics, isFalse);
      expect(back.showHints, isFalse);
      expect(back.showQuickBar, isFalse);
      expect(back.orientation, OrientationPref.landscape);
      expect(back.onboardingDone, isTrue);
    });

    test('loading never throws: garbage and wrong types fall back to defaults', () {
      expect(AppPrefs.fromJson(null).accentId, 'violet');
      expect(AppPrefs.fromJson('nope').haptics, isTrue);
      final p = AppPrefs.fromJson({'accent': 5, 'haptics': 'yes', 'orientation': 'sideways', 'hints': null});
      expect(p.accentId, 'violet');
      expect(p.haptics, isTrue);
      expect(p.orientation, OrientationPref.auto);
      expect(p.showHints, isTrue);
      expect(AppPrefs.fromJson({'accent': 'x' * 50}).accentId, 'violet', reason: 'absurdly long ids are ignored');
    });

    test('copyWith changes only what it is told to', () {
      const p = AppPrefs(haptics: false);
      final q = p.copyWith(showHints: false);
      expect(q.haptics, isFalse);
      expect(q.showHints, isFalse);
      expect(q.accentId, p.accentId);
    });
  });

  group('accent palette', () {
    test('ids are unique, the default exists, unknown ids fall back to the default', () {
      final ids = AccentPalette.options.map((o) => o.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids, contains(AccentPalette.defaultId));
      expect(AccentPalette.byId('nope').id, AccentPalette.defaultId);
      expect(AccentPalette.byId(null).id, AccentPalette.defaultId);
      expect(AccentPalette.byId('teal').label, 'Teal');
    });

    test('contrast ratio basics', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
      expect(contrastRatio(Colors.white, Colors.white), closeTo(1, 0.001));
      expect(contrastRatio(Colors.white, Colors.black), contrastRatio(Colors.black, Colors.white));
    });

    test('onAccentFor picks the more readable of white and near-black', () {
      expect(onAccentFor(const Color(0xFF111111)), const Color(0xFFFFFFFF));
      expect(onAccentFor(const Color(0xFFF2F2F2)), const Color(0xFF12101F));
    });

    test('every accent keeps readable text on top (4.5:1) and is visible on its background (3:1)', () {
      for (final o in AccentPalette.options) {
        expect(contrastRatio(o.light, onAccentFor(o.light)), greaterThanOrEqualTo(4.5), reason: '${o.id} light label');
        expect(contrastRatio(o.dark, onAccentFor(o.dark)), greaterThanOrEqualTo(4.5), reason: '${o.id} dark label');
        expect(contrastRatio(o.light, MtColors.light.surface), greaterThanOrEqualTo(3.0), reason: '${o.id} light on card');
        expect(contrastRatio(o.dark, MtColors.dark.surface), greaterThanOrEqualTo(3.0), reason: '${o.id} dark on card');
      }
    });

    test('MtColors.withAccent changes only the accent', () {
      final c = MtColors.dark.withAccent(const Color(0xFF123456), const Color(0xFFFFFFFF));
      expect(c.accent, const Color(0xFF123456));
      expect(c.onAccent, const Color(0xFFFFFFFF));
      expect(c.bg, MtColors.dark.bg);
      expect(c.surface, MtColors.dark.surface);
      expect(c.danger, MtColors.dark.danger);
    });

    test('the themes built for an accent use it as the primary color', () {
      final t = AppTheme.lightWith(const Color(0xFF0B7F75), const Color(0xFFFFFFFF));
      expect(t.colorScheme.primary, const Color(0xFF0B7F75));
      expect(t.brightness, Brightness.light);
      expect(AppTheme.darkWith(const Color(0xFF3DD6C4), const Color(0xFF12101F)).brightness, Brightness.dark);
    });
  });
}
