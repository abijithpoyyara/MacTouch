import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/app.dart';
import 'app/di.dart';
import 'controllers/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  // Rotation follows the user's setting (automatic by default; portrait or landscape lock in Settings).
  await Get.find<SettingsController>().applyOrientation();
  runApp(const MacTouchApp());
}
