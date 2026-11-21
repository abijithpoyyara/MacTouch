import 'package:get/get.dart';

import '../controllers/connection_controller.dart';
import '../controllers/pairing_controller.dart';
import '../controllers/gesture_config_controller.dart';
import '../controllers/connection_history_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/shortcut_controller.dart';
import '../controllers/theme_controller.dart';
import '../controllers/touchpad_controller.dart';
import '../data/repositories/connection_repository.dart';
import '../data/repositories/identity_repository.dart';
import '../data/repositories/paired_mac_repository.dart';
import '../data/services/network_monitor_service.dart';
import '../data/services/secure_store_service.dart';
import '../data/services/settings_service.dart';
import '../data/services/transport.dart';

/// Services -> repositories -> controllers. Everything lives for the app's lifetime.
Future<void> initDependencies() async {
  final settings = await SettingsService.create();
  final secure = SecureStoreService();
  final network = NetworkMonitorService();
  final macs = PairedMacRepository(settings, secure);
  final identity = IdentityRepository(settings);
  final connectionRepo = ConnectionRepository(WebSocketTransport(), macs, identity);

  Get.put<SettingsService>(settings, permanent: true);
  Get.put<ConnectionRepository>(connectionRepo, permanent: true);
  Get.put<ThemeController>(ThemeController(settings), permanent: true);
  Get.put<SettingsController>(SettingsController(settings), permanent: true);
  final connection = Get.put<ConnectionController>(ConnectionController(connectionRepo, macs, network), permanent: true);
  Get.put<PairingController>(PairingController(connectionRepo, connection), permanent: true);
  Get.put<ConnectionHistoryController>(ConnectionHistoryController(connection, settings), permanent: true);
  // The touchpad controller reads these in onInit, so they must exist first.
  Get.put<GestureConfigController>(GestureConfigController(settings), permanent: true);
  Get.put<ShortcutController>(ShortcutController(settings), permanent: true);
  Get.put<TouchpadController>(TouchpadController(connectionRepo, connection, settings), permanent: true);
}
