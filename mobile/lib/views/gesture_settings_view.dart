import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/gesture_config_controller.dart';
import '../controllers/shortcut_controller.dart';
import '../controllers/touchpad_controller.dart';
import '../core/shortcuts/system_actions.dart';
import '../core/theme/app_theme.dart';
import '../core/touchpad/gesture_catalog.dart';
import '../core/touchpad/gesture_config.dart';
import '../core/touchpad/touchpad_settings.dart';
import 'widgets/action_picker_sheet.dart';

class GestureSettingsView extends StatelessWidget {
  const GestureSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 32),
          children: [
            Row(children: [
              IconButton(tooltip: 'Back', onPressed: () => Get.back(), icon: Icon(Icons.arrow_back_rounded, color: c.text)),
              Text('Gestures', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.text)),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 0, 12),
              child: Text(
                'Turn gestures on or off, tune how they feel, and choose what swipes do. '
                'Some macOS actions need a setting turned on in System Settings. Each card says which.',
                style: TextStyle(fontSize: 14, height: 1.4, color: c.textDim),
              ),
            ),
            for (final section in GestureCatalog.sections) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 0, 8),
                child: Text(section.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: c.textDim)),
              ),
              for (final g in section.gestures)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 10),
                  child: _GestureCard(info: g),
                ),
            ],
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 16),
              child: OutlinedButton.icon(
                onPressed: () => _confirmRestore(context),
                icon: const Icon(Icons.restore_rounded),
                label: const Text('Restore default gestures'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _confirmRestore(BuildContext context) async {
    final c = MtColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Restore default gestures?'),
        content: const Text('Every gesture goes back to its original on/off state, sensitivity, distance and action. Your shortcuts are not changed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ),
    );
    if (ok != true) return;
    Get.find<GestureConfigController>().restoreDefaults();
    final pad = Get.find<TouchpadController>();
    const d = TouchpadSettings();
    pad.updateSettings(pad.settings.value.copyWith(
      sensitivity: d.sensitivity, scrollSensitivity: d.scrollSensitivity,
      tapToClick: d.tapToClick, twoFingerRightClick: d.twoFingerRightClick, horizontalScroll: d.horizontalScroll,
    ));
  }
}

/// Where a gesture's switch and sensitivity are stored: tap, right-click, horizontal scroll, pointer speed and
/// scroll speed already live in TouchpadSettings (so the existing settings sheet keeps working); the rest in GestureConfig.
class _GestureCard extends StatelessWidget {
  const _GestureCard({required this.info});
  final GestureInfo info;

  static bool _enabled(GestureId id, TouchpadSettings s, GestureConfig cfg) => switch (id) {
        GestureId.oneFingerTap => s.tapToClick,
        GestureId.twoFingerTap => s.twoFingerRightClick,
        GestureId.scrollHorizontal => s.horizontalScroll,
        _ => cfg[id].enabled,
      };

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final cfgCtrl = Get.find<GestureConfigController>();
    final pad = Get.find<TouchpadController>();
    final id = info.id;

    void setEnabled(bool v) {
      switch (id) {
        case GestureId.oneFingerTap:
          pad.updateSettings(pad.settings.value.copyWith(tapToClick: v));
        case GestureId.twoFingerTap:
          pad.updateSettings(pad.settings.value.copyWith(twoFingerRightClick: v));
        case GestureId.scrollHorizontal:
          pad.updateSettings(pad.settings.value.copyWith(horizontalScroll: v));
        default:
          cfgCtrl.updateGesture(id, (s) => s.copyWith(enabled: v));
      }
    }

    return Obx(() {
      final s = pad.settings.value;
      final cfg = cfgCtrl.config.value;
      final setting = cfg[id];
      final enabled = _enabled(id, s, cfg);

      Widget? sensitivity;
      if (info.sensitivityLabel != null) {
        final double value, min, max;
        final void Function(double) onChanged;
        final VoidCallback onEnd;
        if (id == GestureId.oneFingerMove) {
          value = s.sensitivity;
          min = TouchpadSettings.sensitivityRange.min;
          max = TouchpadSettings.sensitivityRange.max;
          onChanged = (v) => pad.updateSettings(s.copyWith(sensitivity: v), persist: false);
          onEnd = pad.persistSettings;
        } else if (id == GestureId.scrollVertical) {
          value = s.scrollSensitivity;
          min = TouchpadSettings.scrollRange.min;
          max = TouchpadSettings.scrollRange.max;
          onChanged = (v) => pad.updateSettings(s.copyWith(scrollSensitivity: v), persist: false);
          onEnd = pad.persistSettings;
        } else {
          value = setting.sensitivity;
          min = GestureSetting.sensitivityRange.min;
          max = GestureSetting.sensitivityRange.max;
          onChanged = (v) => cfgCtrl.updateGesture(id, (x) => x.copyWith(sensitivity: v), persist: false);
          onEnd = cfgCtrl.save;
        }
        sensitivity = _SliderRow(
          label: info.sensitivityLabel!, value: value, min: min, max: max,
          format: (v) => '${v.toStringAsFixed(1)}x', onChanged: onChanged, onEnd: onEnd,
        );
      }

      return Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: c.outline)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(info.icon, color: enabled ? c.accent : c.textDim),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(info.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
                Text(info.description, style: TextStyle(fontSize: 13, height: 1.3, color: c.textDim)),
              ]),
            ),
            Switch(value: enabled, onChanged: setEnabled),
          ]),
          if (enabled) ...[
            if (sensitivity != null) Padding(padding: const EdgeInsets.only(right: 8), child: sensitivity),
            if (info.hasDistance)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _SliderRow(
                  label: 'Swipe distance', value: setting.distance, min: GestureSetting.distanceRange.min, max: GestureSetting.distanceRange.max,
                  format: (v) => '${v.round()} px',
                  onChanged: (v) => cfgCtrl.updateGesture(id, (x) => x.copyWith(distance: v), persist: false), onEnd: cfgCtrl.save,
                ),
              ),
            if (info.hasHold)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _SliderRow(
                  label: 'Hold time', value: setting.holdMs.toDouble(), min: GestureSetting.holdRange.min.toDouble(), max: GestureSetting.holdRange.max.toDouble(),
                  format: (v) => '${v.round()} ms',
                  onChanged: (v) => cfgCtrl.updateGesture(id, (x) => x.copyWith(holdMs: v.round()), persist: false), onEnd: cfgCtrl.save,
                ),
              ),
            if (info.hasAction) _ActionRow(id: id, action: setting.action),
          ],
        ]),
      );
    });
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.id, required this.action});
  final GestureId id;
  final GestureAction? action;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final shortcuts = Get.find<ShortcutController>();
    String title = 'No action';
    String? detail;
    String? warning;
    final a = action;
    if (a is SystemGestureAction) {
      title = SystemActionIds.label(a.action);
      warning = SystemActionIds.requirement(a.action);
    } else if (a is ShortcutGestureAction) {
      final item = shortcuts.library.value.byId(a.shortcutId);
      title = item?.name ?? 'Missing shortcut';
      detail = item == null ? 'That shortcut was deleted. Choose another action.' : item.combo;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Action', style: TextStyle(fontSize: 12, color: c.textDim)),
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: a == null ? c.textDim : c.text)),
              if (detail != null) Text(detail, style: TextStyle(fontSize: 12, color: c.textDim)),
            ]),
          ),
          TextButton(
            onPressed: () async {
              final pick = await showActionPicker(context, action);
              if (pick != null) Get.find<GestureConfigController>().setAction(id, pick.action);
            },
            child: const Text('Change'),
          ),
        ]),
        if (warning != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 16, color: c.warning),
              const SizedBox(width: 6),
              Expanded(child: Text(warning, style: TextStyle(fontSize: 12, height: 1.35, color: c.warning))),
            ]),
          ),
      ]),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({required this.label, required this.value, required this.min, required this.max, required this.format, required this.onChanged, required this.onEnd});
  final String label;
  final double value, min, max;
  final String Function(double) format;
  final ValueChanged<double> onChanged;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [
          Text(label, style: TextStyle(fontSize: 14, color: c.text)),
          const Spacer(),
          Text(format(value), style: TextStyle(fontSize: 13, color: c.textDim)),
        ]),
      ),
      Slider(value: value.clamp(min, max).toDouble(), min: min, max: max, onChanged: onChanged, onChangeEnd: (_) => onEnd()),
    ]);
  }
}
