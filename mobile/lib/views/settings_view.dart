import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes.dart';
import '../controllers/settings_controller.dart';
import '../controllers/theme_controller.dart';
import '../controllers/touchpad_controller.dart';
import '../core/haptics.dart';
import '../core/prefs/accent.dart';
import '../core/prefs/app_prefs.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../core/touchpad/touchpad_settings.dart';
import 'widgets/shortcut_pack_sheet.dart';
import 'widgets/ui_kit.dart';

/// Application settings. Everything here is saved on the phone and takes effect immediately.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  static const version = '0.4.0';

  @override
  Widget build(BuildContext context) {
    final app = Get.find<SettingsController>();
    final theme = Get.find<ThemeController>();
    final pad = Get.find<TouchpadController>();

    return ScreenFrame(
      title: 'Settings',
      children: [
        const SectionLabel('Appearance'),
        RowGroup(children: [
          Obx(() => ChoiceRow<ThemeMode>(
                label: 'Theme',
                value: theme.mode.value,
                options: const {ThemeMode.system: 'System', ThemeMode.light: 'Light', ThemeMode.dark: 'Dark'},
                onChanged: theme.setMode,
              )),
          const _AccentPicker(),
          Obx(() => SwitchRow(
                title: 'Haptic feedback',
                subtitle: 'A light tap for clicks, swipes and toggles',
                value: app.prefs.value.haptics,
                onChanged: app.setHaptics,
              )),
        ]),

        const SectionLabel('Touchpad'),
        RowGroup(children: [
          Obx(() => SwitchRow(
                title: 'Gesture hints',
                subtitle: 'Show reminders on the empty touchpad',
                value: app.prefs.value.showHints,
                onChanged: app.setShowHints,
              )),
          Obx(() => SwitchRow(
                title: 'Quick shortcuts bar',
                subtitle: 'Show your favorite shortcuts above the touchpad',
                value: app.prefs.value.showQuickBar,
                onChanged: app.setShowQuickBar,
              )),
          Obx(() => ChoiceRow<OrientationPref>(
                label: 'Screen orientation',
                value: app.prefs.value.orientation,
                options: {for (final o in OrientationPref.values) o: o.label},
                onChanged: app.setOrientation,
              )),
        ]),

        const SectionLabel('Pointer'),
        Obx(() {
          final s = pad.settings.value;
          return RowGroup(children: [
            SliderRow(
              label: 'Pointer speed', value: s.sensitivity, min: TouchpadSettings.sensitivityRange.min, max: TouchpadSettings.sensitivityRange.max,
              format: (v) => '${v.toStringAsFixed(1)}x',
              onChanged: (v) => pad.updateSettings(s.copyWith(sensitivity: v), persist: false), onEnd: pad.persistSettings,
            ),
            SliderRow(
              label: 'Touch sensitivity', value: TouchpadSettings.deadzoneRange.max - s.deadzone, min: 0, max: TouchpadSettings.deadzoneRange.max,
              hint: 'Higher: the pointer follows the smallest movement. Lower: tiny movements are ignored, which suits a shaky hand and keeps taps precise.',
              format: (v) => v <= 0.5 ? 'Lowest' : (v >= TouchpadSettings.deadzoneRange.max - 0.5 ? 'Highest' : v.toStringAsFixed(1)),
              onChanged: (v) => pad.updateSettings(s.copyWith(deadzone: TouchpadSettings.deadzoneRange.max - v), persist: false), onEnd: pad.persistSettings,
            ),
            SwitchRow(
              title: 'Pointer acceleration', subtitle: 'Fast swipes travel further',
              value: s.accelEnabled, onChanged: (v) => pad.updateSettings(s.copyWith(accelEnabled: v)),
            ),
            if (s.accelEnabled)
              SliderRow(
                label: 'Acceleration strength', value: s.accelStrength, min: 0, max: 1, format: (v) => '${(v * 100).round()}%',
                onChanged: (v) => pad.updateSettings(s.copyWith(accelStrength: v), persist: false), onEnd: pad.persistSettings,
              ),
            SliderRow(
              label: 'Smoothing', value: s.smoothing, min: TouchpadSettings.smoothingRange.min, max: TouchpadSettings.smoothingRange.max,
              hint: 'Steadier movement, with a little delay',
              format: (v) => '${(v / TouchpadSettings.smoothingRange.max * 100).round()}%',
              onChanged: (v) => pad.updateSettings(s.copyWith(smoothing: v), persist: false), onEnd: pad.persistSettings,
            ),
          ]);
        }),

        const SectionLabel('Scrolling'),
        Obx(() {
          final s = pad.settings.value;
          return RowGroup(children: [
            SliderRow(
              label: 'Scroll speed', value: s.scrollSensitivity, min: TouchpadSettings.scrollRange.min, max: TouchpadSettings.scrollRange.max,
              format: (v) => '${v.toStringAsFixed(1)}x',
              onChanged: (v) => pad.updateSettings(s.copyWith(scrollSensitivity: v), persist: false), onEnd: pad.persistSettings,
            ),
            SwitchRow(
              title: 'Natural scrolling', subtitle: 'Content follows your fingers',
              value: s.naturalScroll, onChanged: (v) => pad.updateSettings(s.copyWith(naturalScroll: v)),
            ),
            SwitchRow(
              title: 'Horizontal scrolling', subtitle: 'Scroll sideways with two fingers',
              value: s.horizontalScroll, onChanged: (v) => pad.updateSettings(s.copyWith(horizontalScroll: v)),
            ),
            if (s.horizontalScroll)
              SwitchRow(
                title: 'Reverse horizontal direction',
                value: s.invertHorizontal, onChanged: (v) => pad.updateSettings(s.copyWith(invertHorizontal: v)),
              ),
          ]);
        }),

        const SectionLabel('Gestures and shortcuts'),
        RowGroup(children: [
          NavRow(icon: Icons.gesture_rounded, title: 'Gestures', subtitle: 'Turn on or off, change thresholds and what swipes do', onTap: () => Get.toNamed<void>(Routes.gestures)),
          NavRow(icon: Icons.bolt_rounded, title: 'Shortcut Center', subtitle: 'Favorites, categories, reordering', onTap: () => Get.toNamed<void>(Routes.shortcuts)),
          NavRow(icon: Icons.ios_share_rounded, title: 'Import or export shortcuts', subtitle: 'Share presets as text', onTap: () => showShortcutPackSheet(context)),
        ]),

        const SectionLabel('More'),
        RowGroup(children: [
          NavRow(icon: Icons.devices_rounded, title: 'Devices', subtitle: 'Paired Mac and connection history', onTap: () => Get.toNamed<void>(Routes.devices)),
          NavRow(icon: Icons.help_outline_rounded, title: 'Help and troubleshooting', onTap: () => Get.toNamed<void>(Routes.help)),
          NavRow(
            icon: Icons.restart_alt_rounded,
            title: 'Reset appearance and behavior',
            subtitle: 'Theme, accent, haptics, hints, orientation, pointer and scrolling',
            onTap: () async {
              final ok = await confirmDialog(
                context,
                title: 'Reset these settings?',
                message: 'Gestures, shortcuts and your paired Mac are not changed.',
                confirm: 'Reset',
              );
              if (!ok) return;
              app.resetAppearanceAndBehaviour();
              await theme.setMode(ThemeMode.system);
              pad.updateSettings(const TouchpadSettings());
            },
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: Tk.s5),
          child: Center(child: Text('MacTouch $version', style: TextStyle(fontSize: 13, color: MtColors.of(context).textDim))),
        ),
      ],
    );
  }
}

class _AccentPicker extends StatelessWidget {
  const _AccentPicker();

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final app = Get.find<SettingsController>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(Tk.s4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Accent color', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
        const SizedBox(height: Tk.s3),
        Obx(() => Wrap(spacing: Tk.s3, runSpacing: Tk.s3, children: [
              for (final o in AccentPalette.options)
                Semantics(
                  button: true,
                  selected: app.accentId.value == o.id,
                  label: '${o.label} accent',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () {
                      Haptics.tap();
                      app.setAccent(o.id);
                    },
                    child: Container(
                      width: Tk.touchTarget,
                      height: Tk.touchTarget,
                      decoration: BoxDecoration(
                        color: dark ? o.dark : o.light,
                        shape: BoxShape.circle,
                        border: Border.all(color: app.accentId.value == o.id ? c.text : Colors.transparent, width: 3),
                      ),
                      child: app.accentId.value == o.id ? Icon(Icons.check_rounded, color: onAccentFor(dark ? o.dark : o.light)) : null,
                    ),
                  ),
                ),
            ])),
      ]),
    );
  }
}
