import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes.dart';
import '../controllers/connection_controller.dart';
import '../controllers/pairing_controller.dart';
import '../controllers/touchpad_controller.dart';
import '../core/format.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import 'widgets/ui_kit.dart';

/// Connection status and the hub for everything else.
class ConnectedView extends StatelessWidget {
  const ConnectedView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final link = Get.find<ConnectionController>();
    final pad = Get.find<TouchpadController>();

    return ScreenFrame(
      title: 'MacTouch',
      actions: [
        IconButton(tooltip: 'Help', onPressed: () => Get.toNamed<void>(Routes.help), icon: Icon(Icons.help_outline_rounded, color: c.textDim)),
      ],
      children: [
        Obx(() {
          final mac = link.mac.value;
          final state = link.state.value;
          final (label, color) = switch (state) {
            LinkState.connected => ('Connected', c.success),
            LinkState.connecting || LinkState.reconnecting => ('Reconnecting\u2026', c.warning),
            LinkState.offline => ('No Wi-Fi', c.danger),
            LinkState.failed => ('Connection lost', c.danger),
            LinkState.idle => ('Disconnected', c.textDim),
          };
          final connected = state == LinkState.connected;
          final needsAction = state == LinkState.failed || state == LinkState.offline || state == LinkState.idle;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Panel(
              gradient: MtGradients.hero(c),
              padding: const EdgeInsets.all(Tk.s5),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                StatusPill(label: label, color: color),
                const SizedBox(height: Tk.s4),
                Semantics(
                  header: true,
                  child: Text(mac?.name ?? 'Your Mac',
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 32, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: -0.8, color: c.text)),
                ),
                if (link.message.value != null && !connected) ...[
                  const SizedBox(height: Tk.s2),
                  Text(link.message.value!, style: TextStyle(fontSize: 15, height: 1.4, color: c.textDim)),
                ],
                if (mac != null) ...[
                  const SizedBox(height: Tk.s4),
                  _Fact(label: 'Address', value: '${mac.host}:${mac.port}'),
                  _Fact(label: 'Paired', value: formatWhen(mac.pairedAt)),
                  if (connected) ValueListenableBuilder<int?>(
                    valueListenable: pad.rtt,
                    builder: (_, ms, __) => _Fact(label: 'Latency', value: ms == null ? 'measuring\u2026' : '$ms ms'),
                  ),
                  if (connected) ValueListenableBuilder<bool?>(
                    valueListenable: pad.macAccessibility,
                    builder: (_, ok, __) => _Fact(
                      label: 'Mac permission',
                      value: ok == null ? 'checking\u2026' : (ok ? 'Allowed' : 'Accessibility needed'),
                      valueColor: ok == false ? c.warning : null,
                    ),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: Tk.s4),
            FilledButton.icon(
              onPressed: connected ? () => Get.toNamed<void>(Routes.touchpad) : null,
              icon: const Icon(Icons.touch_app_rounded),
              label: const Text('Open touchpad'),
            ),
            if (needsAction) ...[
              const SizedBox(height: Tk.s2),
              OutlinedButton(onPressed: () => link.connectSaved(), child: const Text('Reconnect')),
              const SizedBox(height: Tk.s2),
              OutlinedButton(onPressed: Get.find<PairingController>().startScan, child: const Text('Scan a new code')),
            ] else if (connected) ...[
              const SizedBox(height: Tk.s2),
              OutlinedButton(onPressed: link.disconnect, child: const Text('Disconnect')),
            ],
          ]);
        }),
        const SectionLabel('Customize'),
        RowGroup(children: [
          NavRow(icon: Icons.bolt_rounded, title: 'Shortcuts', subtitle: 'Favorites, categories, import and export', onTap: () => Get.toNamed<void>(Routes.shortcuts)),
          NavRow(icon: Icons.gesture_rounded, title: 'Gestures', subtitle: 'Turn on or off, change what swipes do', onTap: () => Get.toNamed<void>(Routes.gestures)),
          NavRow(icon: Icons.devices_rounded, title: 'Devices', subtitle: 'Paired Mac and connection history', onTap: () => Get.toNamed<void>(Routes.devices)),
          NavRow(icon: Icons.settings_rounded, title: 'Settings', subtitle: 'Appearance, pointer, scrolling, haptics', onTap: () => Get.toNamed<void>(Routes.settings)),
        ]),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Tk.s1),
      child: Row(children: [
        Text(label, style: TextStyle(fontSize: 14, color: c.textDim)),
        const Spacer(),
        Flexible(child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: valueColor ?? c.text))),
      ]),
    );
  }
}
