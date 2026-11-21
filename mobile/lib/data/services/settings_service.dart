import 'package:shared_preferences/shared_preferences.dart';

/// Non-secret local persistence: theme, this phone's id, and the paired Mac's metadata.
class SettingsService {
  SettingsService(this._prefs);
  final SharedPreferences _prefs;

  static Future<SettingsService> create() async => SettingsService(await SharedPreferences.getInstance());

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) => _prefs.setString(key, value);
  Future<void> remove(String key) => _prefs.remove(key);

  static const themeModeKey = 'themeMode';
  static const pairedMacKey = 'pairedMac.v1';
  static const deviceIdKey = 'deviceId';
}
