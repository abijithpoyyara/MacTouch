import 'package:get/get.dart';

import '../views/connected_view.dart';
import '../views/devices_view.dart';
import '../views/help_view.dart';
import '../views/onboarding_view.dart';
import '../views/settings_view.dart';
import '../views/pairing_view.dart';
import '../views/gesture_settings_view.dart';
import '../views/scanner_view.dart';
import '../views/shortcut_center_view.dart';
import '../views/touchpad_view.dart';
import '../views/welcome_view.dart';

abstract final class Routes {
  static const welcome = '/';
  static const scan = '/scan';
  static const pairing = '/pairing';
  static const connected = '/connected';
  static const touchpad = '/touchpad';
  static const shortcuts = '/shortcuts';
  static const gestures = '/gestures';
  static const onboarding = '/onboarding';
  static const devices = '/devices';
  static const settings = '/settings';
  static const help = '/help';
}

final appPages = <GetPage<dynamic>>[
  GetPage(name: Routes.welcome, page: () => const WelcomeView(), transition: Transition.fade),
  GetPage(name: Routes.scan, page: () => const ScannerView(), transition: Transition.downToUp),
  GetPage(name: Routes.pairing, page: () => const PairingView(), transition: Transition.fade),
  GetPage(name: Routes.connected, page: () => const ConnectedView(), transition: Transition.fadeIn),
  GetPage(name: Routes.touchpad, page: () => const TouchpadView(), transition: Transition.downToUp),
  GetPage(name: Routes.shortcuts, page: () => const ShortcutCenterView(), transition: Transition.rightToLeftWithFade),
  GetPage(name: Routes.gestures, page: () => const GestureSettingsView(), transition: Transition.rightToLeftWithFade),
  GetPage(name: Routes.onboarding, page: () => const OnboardingView(), transition: Transition.fade),
  GetPage(name: Routes.devices, page: () => const DevicesView(), transition: Transition.rightToLeftWithFade),
  GetPage(name: Routes.settings, page: () => const SettingsView(), transition: Transition.rightToLeftWithFade),
  GetPage(name: Routes.help, page: () => const HelpView(), transition: Transition.rightToLeftWithFade),
];
