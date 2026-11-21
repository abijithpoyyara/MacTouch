import 'package:device_info_plus/device_info_plus.dart';

import '../../core/protocol/crypto.dart';
import '../services/settings_service.dart';

/// This phone's stable id and display name.
class IdentityRepository {
  IdentityRepository(this._settings, [DeviceInfoPlugin? deviceInfo]) : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();
  final SettingsService _settings;
  final DeviceInfoPlugin _deviceInfo;

  Future<String> deviceId() async {
    final existing = _settings.getString(SettingsService.deviceIdKey);
    if (existing != null) return existing;
    final created = 'phone-${b64uEncode(randomBytes(12))}';
    await _settings.setString(SettingsService.deviceIdKey, created);
    return created;
  }

  Future<String> deviceName() async {
    try {
      final info = await _deviceInfo.androidInfo;
      final name = '${info.manufacturer} ${info.model}'.trim();
      if (name.isNotEmpty) return name.length > 64 ? name.substring(0, 64) : name;
    } catch (_) {/* fall through */}
    return 'Android phone';
  }
}
