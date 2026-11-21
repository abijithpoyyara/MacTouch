import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../app/routes.dart';
import '../controllers/connection_controller.dart';
import '../controllers/touchpad_controller.dart';
import '../core/format.dart';
import '../core/shortcuts/system_actions.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import 'settings_view.dart';
import 'widgets/ui_kit.dart';

class HelpView extends StatelessWidget {
  const HelpView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return ScreenFrame(
      title: 'Help',
      children: [
        const SectionLabel('Check your connection'),
        const _Diagnostics(),
        const SectionLabel('Common problems'),
        RowGroup(children: [
          const _Topic(
            icon: Icons.wifi_off_rounded,
            title: 'My phone can\u2019t find my Mac',
            lines: [
              'Both devices must be on the same Wi-Fi network. Guest networks and some routers block devices from talking to each other.',
              'Turn off any VPN on either device.',
              'On the Mac, MacTouch must be running and the server started. Its window shows a QR code when it is ready.',
              'If macOS asks whether MacTouch may accept incoming connections, choose Allow.',
              'If the Mac got a new address from your router, scan the QR code again.',
            ],
          ),
          const _Topic(
            icon: Icons.qr_code_2_rounded,
            title: 'The QR code won\u2019t scan',
            lines: [
              'Hold the phone about 20 cm from the screen and keep the whole code inside the frame.',
              'Codes expire after 2 minutes. If it says the code expired, scan the new one.',
              'Turn on the flashlight if the room is dark, or raise the screen brightness on the Mac.',
              'If the camera is black, allow camera access for MacTouch in Android Settings.',
            ],
          ),
          const _Topic(
            icon: Icons.lock_outline_rounded,
            title: 'The cursor doesn\u2019t move',
            lines: [
              'macOS must allow MacTouch to control the pointer: System Settings > Privacy & Security > Accessibility.',
              'If you started the Mac app from Terminal, allow Terminal there instead of MacTouch.',
              'After rebuilding the Mac app, remove MacTouch from the list and add it again.',
              'The touchpad screen shows an orange notice while the permission is missing.',
            ],
          ),
          const _Topic(
            icon: Icons.touch_app_rounded,
            title: 'Gestures feel wrong',
            lines: [
              'Taps register too easily or not at all: change Tap tolerance on the Gestures screen.',
              'Pointer too fast or slow: Settings > Pointer speed. Pointer jitters when you touch or your hand shakes: lower Touch sensitivity.',
              'Scrolling goes the wrong way: Settings > Natural scrolling.',
              'Swipes do nothing: check that the gesture is turned on and has an action, and that the Mac setting it needs is enabled (see Mac settings below).',
            ],
          ),
          _Topic(
            icon: Icons.desktop_mac_rounded,
            title: 'Mac settings some actions need',
            lines: [
              for (final id in SystemActionIds.all) '${SystemActionIds.label(id)}: ${SystemActionIds.requirement(id) ?? 'nothing to set up.'}',
              'Shortcuts only work in apps that define them. MacTouch sends the keys; it cannot tell whether the front app reacts.',
            ],
          ),
          const _Topic(
            icon: Icons.sync_problem_rounded,
            title: 'It keeps disconnecting',
            lines: [
              'Check that the phone is not switching between Wi-Fi and mobile data. Turn on Wi-Fi only if you can.',
              'Disable battery optimization for MacTouch in Android Settings so the connection isn\u2019t paused.',
              'The Devices screen lists every connection and the reason it ended.',
            ],
          ),
        ]),
        const SectionLabel('Guides'),
        RowGroup(children: [
          NavRow(
            icon: Icons.slideshow_rounded,
            title: 'Replay the introduction',
            onTap: () => Get.toNamed<void>(Routes.onboarding),
          ),
          NavRow(icon: Icons.gesture_rounded, title: 'Gestures', subtitle: 'See and change every gesture', onTap: () => Get.toNamed<void>(Routes.gestures)),
          NavRow(icon: Icons.devices_rounded, title: 'Devices and history', onTap: () => Get.toNamed<void>(Routes.devices)),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: Tk.s5),
          child: Center(child: Text('MacTouch ${SettingsView.version}', style: TextStyle(fontSize: 13, color: c.textDim))),
        ),
      ],
    );
  }
}

class _Topic extends StatelessWidget {
  const _Topic({required this.icon, required this.title, required this.lines});
  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(icon, color: c.accent),
        title: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
        childrenPadding: const EdgeInsets.fromLTRB(Tk.s4, 0, Tk.s4, Tk.s4),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: Tk.s2),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('\u2022  ', style: TextStyle(color: c.textDim)),
                Expanded(child: Text(l, style: TextStyle(fontSize: 14, height: 1.45, color: c.textDim))),
              ]),
            ),
        ],
      ),
    );
  }
}

/// A live look at everything that decides whether the phone can control the Mac, with a copy button for support.
class _Diagnostics extends StatefulWidget {
  const _Diagnostics();

  @override
  State<_Diagnostics> createState() => _DiagnosticsState();
}

class _DiagnosticsState extends State<_Diagnostics> {
  late Future<List<ConnectivityResult>> _network = Connectivity().checkConnectivity();

  void _recheck() {
    setState(() {
      _network = Connectivity().checkConnectivity();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final link = Get.find<ConnectionController>();
    final pad = Get.find<TouchpadController>();

    return Panel(
      child: FutureBuilder<List<ConnectivityResult>>(
        future: _network,
        builder: (context, snap) {
          final results = snap.data;
          final wifiOk = results == null ? null : (results.contains(ConnectivityResult.wifi) || results.contains(ConnectivityResult.ethernet));
          return Obx(() {
            final mac = link.mac.value;
            final state = link.state.value;
            return ValueListenableBuilder<int?>(
              valueListenable: pad.rtt,
              builder: (_, ms, __) => ValueListenableBuilder<bool?>(
                valueListenable: pad.macAccessibility,
                builder: (_, access, __) {
                  final rows = <(String, String, bool?)>[
                    ('Wi-Fi', wifiOk == null ? 'checking\u2026' : (wifiOk ? 'Connected' : 'Not on Wi-Fi'), wifiOk),
                    ('Paired Mac', mac?.name ?? 'None', mac != null),
                    ('Connection', _stateLabel(state), state == LinkState.connected),
                    ('Latency', ms == null ? '\u2013' : '$ms ms', ms == null ? null : true),
                    ('Mac permission', access == null ? 'unknown' : (access ? 'Accessibility allowed' : 'Accessibility needed'), access),
                  ];
                  final text = StringBuffer('MacTouch ${SettingsView.version}\nProtocol 1\n${formatWhen(DateTime.now())}\n')
                    ..writeAll([for (final r in rows) '${r.$1}: ${r.$2}'], '\n');
                  if (mac != null) text.write('\nMac address: ${mac.host}:${mac.port}');
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final r in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Semantics(
                          label: '${r.$1}: ${r.$2}',
                          excludeSemantics: true,
                          child: Row(children: [
                            Icon(
                              r.$3 == null ? Icons.remove_circle_outline_rounded : (r.$3! ? Icons.check_circle_rounded : Icons.error_rounded),
                              size: 20,
                              color: r.$3 == null ? c.textDim : (r.$3! ? c.success : c.warning),
                            ),
                            const SizedBox(width: Tk.s3),
                            Text(r.$1, style: TextStyle(fontSize: 15, color: c.text)),
                            const Spacer(),
                            Flexible(child: Text(r.$2, textAlign: TextAlign.end, style: TextStyle(fontSize: 14, color: c.textDim))),
                          ]),
                        ),
                      ),
                    const SizedBox(height: Tk.s3),
                    Row(children: [
                      Expanded(child: OutlinedButton(onPressed: _recheck, child: const Text('Check again'))),
                      const SizedBox(width: Tk.s3),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: text.toString()));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(const SnackBar(content: Text('Copied. It contains no passwords or keys.')));
                            }
                          },
                          child: const Text('Copy details'),
                        ),
                      ),
                    ]),
                    if (state != LinkState.connected && mac != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Tk.s2),
                        child: FilledButton(onPressed: () => link.connectSaved(), child: const Text('Try reconnecting')),
                      ),
                  ]);
                },
              ),
            );
          });
        },
      ),
    );
  }

  static String _stateLabel(LinkState s) => switch (s) {
        LinkState.connected => 'Connected',
        LinkState.connecting => 'Connecting\u2026',
        LinkState.reconnecting => 'Reconnecting\u2026',
        LinkState.offline => 'No Wi-Fi',
        LinkState.failed => 'Not reachable',
        LinkState.idle => 'Not connected',
      };
}
