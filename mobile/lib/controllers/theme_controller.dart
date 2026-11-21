import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/services/settings_service.dart';

class ThemeController extends GetxController {
  ThemeController(this._settings);
  final SettingsService _settings;

  final mode = ThemeMode.system.obs;

  @override
  void onInit() {
    super.onInit();
    mode.value = switch (_settings.getString(SettingsService.themeModeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode next) async {
    mode.value = next;
    await _settings.setString(SettingsService.themeModeKey, next.name);
  }

  /// system -> light -> dark -> system
  Future<void> cycle() async {
    mode.value = switch (mode.value) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    await _settings.setString(SettingsService.themeModeKey, mode.value.name);
  }

  IconData get icon => switch (mode.value) {
        ThemeMode.system => Icons.brightness_auto_rounded,
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.dark => Icons.dark_mode_rounded,
      };

  String get label => switch (mode.value) {
        ThemeMode.system => 'Theme: match system',
        ThemeMode.light => 'Theme: light',
        ThemeMode.dark => 'Theme: dark',
      };
}
