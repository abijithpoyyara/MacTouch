import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../core/haptics.dart';
import '../core/prefs/accent.dart';
import '../core/prefs/app_prefs.dart';
import '../data/services/settings_service.dart';

/// App-level preferences: accent color, haptics, touchpad extras, orientation, onboarding. Persisted and applied immediately.
class SettingsController extends GetxController {
  SettingsController(this._store);
  final SettingsService _store;

  static const _key = 'prefs.v1';

  final prefs = const AppPrefs().obs;

  /// Separate from [prefs] so the app theme only rebuilds when the accent actually changes.
  final accentId = AccentPalette.defaultId.obs;

  AccentOption get accent => AccentPalette.byId(accentId.value);

  @override
  void onInit() {
    super.onInit();
    final raw = _store.getString(_key);
    if (raw != null) {
      try {
        prefs.value = AppPrefs.fromJson(jsonDecode(raw));
      } on FormatException {
        prefs.value = const AppPrefs();
      }
    }
    accentId.value = prefs.value.accentId;
    Haptics.enabled = prefs.value.haptics;
  }

  void setAccent(String id) => _set(prefs.value.copyWith(accentId: AccentPalette.byId(id).id));
  void setHaptics(bool on) => _set(prefs.value.copyWith(haptics: on));
  void setShowHints(bool on) => _set(prefs.value.copyWith(showHints: on));
  void setShowQuickBar(bool on) => _set(prefs.value.copyWith(showQuickBar: on));
  void setOrientation(OrientationPref o) {
    _set(prefs.value.copyWith(orientation: o));
    applyOrientation();
  }

  void completeOnboarding() => _set(prefs.value.copyWith(onboardingDone: true));

  /// Back to the defaults for everything except "introduction already seen".
  void resetAppearanceAndBehaviour() {
    _set(AppPrefs(onboardingDone: prefs.value.onboardingDone));
    applyOrientation();
  }

  Future<void> applyOrientation() => SystemChrome.setPreferredOrientations(switch (prefs.value.orientation) {
        OrientationPref.auto => [DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
        OrientationPref.portrait => [DeviceOrientation.portraitUp],
        OrientationPref.landscape => [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
      });

  void _set(AppPrefs next) {
    prefs.value = next;
    accentId.value = next.accentId;
    Haptics.enabled = next.haptics;
    _store.setString(_key, jsonEncode(next.toJson()));
  }
}
