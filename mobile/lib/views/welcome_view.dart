import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes.dart';
import '../controllers/connection_controller.dart';
import '../controllers/pairing_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import 'widgets/trackpad_hero.dart';
import 'widgets/ui_kit.dart';

/// Pairing entry: scan a QR code, or reconnect to the Mac this phone already knows.
class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;

    final hero = Panel(
      gradient: MtGradients.hero(c),
      padding: const EdgeInsets.all(Tk.s4),
      child: const TrackpadHero(),
    );
    final content = _Content(landscape: landscape);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: landscape ? 900 : Tk.maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Tk.s5, Tk.s2, Tk.s5, Tk.s4),
              child: Column(
                children: [
                  Row(children: [
                    Text('MacTouch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: c.text)),
                    const Spacer(),
                    IconButton(tooltip: 'Help', onPressed: () => Get.toNamed<void>(Routes.help), icon: Icon(Icons.help_outline_rounded, color: c.textDim)),
                    IconButton(tooltip: 'Settings', onPressed: () => Get.toNamed<void>(Routes.settings), icon: Icon(Icons.settings_rounded, color: c.textDim)),
                  ]),
                  Expanded(
                    child: landscape
                        ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                            Expanded(child: hero),
                            const SizedBox(width: Tk.s6),
                            Expanded(child: SingleChildScrollView(child: content)),
                          ])
                        : SingleChildScrollView(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              const SizedBox(height: Tk.s2),
                              hero,
                              const SizedBox(height: Tk.s6),
                              content,
                            ]),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.landscape});
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final link = Get.find<ConnectionController>();
    final pairing = Get.find<PairingController>();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
        header: true,
        child: Text('Your phone is the trackpad',
            style: TextStyle(fontSize: landscape ? 28 : 32, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: -0.8, color: c.text)),
      ),
      const SizedBox(height: Tk.s3),
      Text('Open MacTouch on your Mac, then scan the code it shows. Both devices need to be on the same Wi-Fi.',
          style: TextStyle(fontSize: 16, height: 1.45, color: c.textDim)),
      const SizedBox(height: Tk.s6),
      Obx(() {
        final mac = link.mac.value;
        if (mac == null) {
          return FilledButton.icon(
            onPressed: pairing.startScan,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Scan QR code'),
          );
        }
        final state = link.state.value;
        final busy = state == LinkState.connecting || state == LinkState.reconnecting;
        final (status, color) = switch (state) {
          LinkState.connecting => ('Connecting\u2026', c.warning),
          LinkState.reconnecting => ('Reconnecting\u2026', c.warning),
          LinkState.offline || LinkState.failed => (link.message.value ?? 'Not connected', c.danger),
          LinkState.connected => ('Connected', c.success),
          LinkState.idle => ('Paired', c.textDim),
        };
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Panel(
            child: Row(children: [
              Icon(Icons.desktop_mac_rounded, color: c.textDim),
              const SizedBox(width: Tk.s3),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(mac.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
                  const SizedBox(height: 2),
                  Text(status, style: TextStyle(fontSize: 13, color: color)),
                ]),
              ),
              if (busy) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
            ]),
          ),
          const SizedBox(height: Tk.s3),
          FilledButton(
            onPressed: busy ? null : () => link.connectSaved(),
            child: Text('Reconnect to ${mac.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: Tk.s2),
          OutlinedButton(onPressed: pairing.startScan, child: const Text('Pair a different Mac')),
        ]);
      }),
      const SizedBox(height: Tk.s3),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        TextButton(onPressed: () => Get.toNamed<void>(Routes.devices), child: const Text('Devices')),
        TextButton(onPressed: () => Get.toNamed<void>(Routes.shortcuts), child: const Text('Shortcuts')),
        TextButton(onPressed: () => Get.toNamed<void>(Routes.gestures), child: const Text('Gestures')),
      ]),
    ]);
  }
}
