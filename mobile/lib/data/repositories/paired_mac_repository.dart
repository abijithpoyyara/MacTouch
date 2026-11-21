import 'dart:convert';
import 'dart:typed_data';

import '../../core/protocol/crypto.dart';
import '../models/paired_mac.dart';
import '../services/secure_store_service.dart';
import '../services/settings_service.dart';

/// Metadata (name, address) in SharedPreferences; the long-term secret in the Keystore.
class PairedMacRepository {
  PairedMacRepository(this._settings, this._secure);
  final SettingsService _settings;
  final SecureStoreService _secure;

  String _secretKey(String serverId) => 'secret.$serverId';

  PairedMac? load() {
    final raw = _settings.getString(SettingsService.pairedMacKey);
    if (raw == null) return null;
    try {
      return PairedMac.tryFromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> save(PairedMac mac, List<int> secret) async {
    await _secure.write(_secretKey(mac.serverId), b64uEncode(secret));
    await _settings.setString(SettingsService.pairedMacKey, jsonEncode(mac.toJson()));
  }

  Future<void> update(PairedMac mac) =>
      _settings.setString(SettingsService.pairedMacKey, jsonEncode(mac.toJson()));

  Future<Uint8List?> loadSecret(String serverId) async {
    final text = await _secure.read(_secretKey(serverId));
    if (text == null) return null;
    try {
      return b64uDecode(text);
    } on FormatException {
      return null;
    }
  }

  Future<void> clear(String serverId) async {
    await _secure.delete(_secretKey(serverId));
    await _settings.remove(SettingsService.pairedMacKey);
  }
}
