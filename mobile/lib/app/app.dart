import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/settings_controller.dart';
import '../controllers/theme_controller.dart';
import '../core/prefs/accent.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import 'routes.dart';

class MacTouchApp extends StatelessWidget {
  const MacTouchApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Get.find<ThemeController>();
    final settings = Get.find<SettingsController>();
    // First launch shows the introduction; afterwards the app opens on the welcome screen.
    final start = settings.prefs.value.onboardingDone ? Routes.welcome : Routes.onboarding;

    // Only the theme mode and the accent id are read here, so unrelated preferences never rebuild the whole app.
    return Obx(() {
      final accent = settings.accent;
      return GetMaterialApp(
        title: 'MacTouch',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightWith(accent.light, onAccentFor(accent.light)),
        darkTheme: AppTheme.darkWith(accent.dark, onAccentFor(accent.dark)),
        themeMode: theme.mode.value,
        initialRoute: start,
        getPages: appPages,
        defaultTransition: Transition.fade,
        transitionDuration: Tk.normal,
      );
    });
  }
}
