import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/touchpad_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/touchpad/touchpad_settings.dart';

Future<void> showTouchpadSettings(BuildContext context) {
  final c = MtColors.of(context);
  final pad = Get.find<TouchpadController>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (_, scroll) => Obx(() {
        final s = pad.settings.value;
        void set(TouchpadSettings n, {bool persist = true}) => pad.updateSettings(n, persist: persist);
        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            Text('Touchpad settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.text)),
            const SizedBox(height: 16),
            _SliderRow(
              label: 'Pointer speed', value: s.sensitivity, min: TouchpadSettings.sensitivityRange.min,
              max: TouchpadSettings.sensitivityRange.max, format: (v) => '${v.toStringAsFixed(1)}x',
              onChanged: (v) => set(s.copyWith(sensitivity: v), persist: false), onEnd: pad.persistSettings,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero, title: const Text('Pointer acceleration'),
              subtitle: const Text('Fast swipes travel further'),
              value: s.accelEnabled, onChanged: (v) => set(s.copyWith(accelEnabled: v)),
            ),
            if (s.accelEnabled)
              _SliderRow(
                label: 'Acceleration', value: s.accelStrength, min: 0, max: 1,
                format: (v) => '${(v * 100).round()}%',
                onChanged: (v) => set(s.copyWith(accelStrength: v), persist: false), onEnd: pad.persistSettings,
              ),
            _SliderRow(
              label: 'Smoothing', value: s.smoothing, min: TouchpadSettings.smoothingRange.min,
              max: TouchpadSettings.smoothingRange.max, format: (v) => '${(v / 0.8 * 100).round()}%',
              onChanged: (v) => set(s.copyWith(smoothing: v), persist: false), onEnd: pad.persistSettings,
            ),
            const Divider(height: 32),
            _SliderRow(
              label: 'Scroll speed', value: s.scrollSensitivity, min: TouchpadSettings.scrollRange.min,
              max: TouchpadSettings.scrollRange.max, format: (v) => '${v.toStringAsFixed(1)}x',
              onChanged: (v) => set(s.copyWith(scrollSensitivity: v), persist: false), onEnd: pad.persistSettings,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero, title: const Text('Natural scrolling'),
              subtitle: const Text('Content follows your fingers'),
              value: s.naturalScroll, onChanged: (v) => set(s.copyWith(naturalScroll: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero, title: const Text('Horizontal scrolling'),
              value: s.horizontalScroll, onChanged: (v) => set(s.copyWith(horizontalScroll: v)),
            ),
            if (s.horizontalScroll)
              SwitchListTile(
                contentPadding: EdgeInsets.zero, title: const Text('Reverse horizontal direction'),
                value: s.invertHorizontal, onChanged: (v) => set(s.copyWith(invertHorizontal: v)),
              ),
            const Divider(height: 32),
            SwitchListTile(
              contentPadding: EdgeInsets.zero, title: const Text('Tap to click'),
              value: s.tapToClick, onChanged: (v) => set(s.copyWith(tapToClick: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero, title: const Text('Two-finger tap for right-click'),
              value: s.twoFingerRightClick, onChanged: (v) => set(s.copyWith(twoFingerRightClick: v)),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => set(const TouchpadSettings()), child: const Text('Reset to defaults')),
          ],
        );
      }),
    ),
  );
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label, required this.value, required this.min, required this.max,
    required this.format, required this.onChanged, required this.onEnd,
  });
  final String label;
  final double value, min, max;
  final String Function(double) format;
  final ValueChanged<double> onChanged;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label, style: TextStyle(fontSize: 15, color: c.text)),
          const Spacer(),
          Text(format(value), style: TextStyle(fontSize: 14, color: c.textDim)),
        ]),
        Slider(value: value.clamp(min, max).toDouble(), min: min, max: max, onChanged: onChanged, onChangeEnd: (_) => onEnd()),
      ],
    );
  }
}
