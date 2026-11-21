import 'dart:convert';

import 'package:get/get.dart';

import '../core/touchpad/gesture_config.dart';
import '../data/services/settings_service.dart';

/// Holds the user's gesture mapping and persists it. The touchpad controller listens to [config].
class GestureConfigController extends GetxController {
  GestureConfigController(this._store);
  final SettingsService _store;

  static const _key = 'gestures.v1';
  final config = GestureConfig.defaults().obs;

  @override
  void onInit() {
    super.onInit();
    final raw = _store.getString(_key);
    if (raw != null) {
      try {
        config.value = GestureConfig.fromJson(jsonDecode(raw));
      } on FormatException {
        config.value = GestureConfig.defaults();
      }
    }
  }

  void updateGesture(GestureId id, GestureSetting Function(GestureSetting) change, {bool persist = true}) {
    config.value = config.value.with_(id, change(config.value[id]));
    if (persist) save();
  }

  void setAction(GestureId id, GestureAction? action) =>
      updateGesture(id, (s) => action == null ? s.copyWith(clearAction: true) : s.copyWith(action: action));

  void save() => _store.setString(_key, jsonEncode(config.value.toJson()));

  void restoreDefaults() {
    config.value = GestureConfig.defaults();
    save();
  }
}
