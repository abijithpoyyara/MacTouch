import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes.dart';
import '../controllers/connection_controller.dart';
import '../controllers/connection_history_controller.dart';
import '../controllers/pairing_controller.dart';
import '../core/format.dart';
import '../core/history/connection_history.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import 'widgets/ui_kit.dart';

/// The paired Mac and a log of connection events. This phone remembers one Mac at a time.
class DevicesView extends StatelessWidget {
  const DevicesView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final link = Get.find<ConnectionController>();
    final history = Get.find<ConnectionHistoryController>();

    return ScreenFrame(
      title: 'Devices',
      children: [
        const SectionLabel('Paired Mac'),
        Obx(() {
          final mac = link.mac.value;
          if (mac == null) {
            return Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('No Mac paired yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: c.text)),
                const SizedBox(height: Tk.s1),
                Text('Open MacTouch on your Mac and scan the code it shows.', style: TextStyle(fontSize: 14, height: 1.4, color: c.textDim)),
                const SizedBox(height: Tk.s4),
                FilledButton.icon(onPressed: Get.find<PairingController>().startScan, icon: const Icon(Icons.qr_code_scanner_rounded), label: const Text('Scan QR code')),
              ]),
            );
          }
          final state = link.state.value;
          final connected = state == LinkState.connected;
          final busy = state == LinkState.connecting || state == LinkState.reconnecting;
          final (label, color) = switch (state) {
            LinkState.connected => ('Connected', c.success),
            LinkState.connecting || LinkState.reconnecting => ('Reconnecting\u2026', c.warning),
            LinkState.offline => ('No Wi-Fi', c.danger),
            LinkState.failed => ('Not reachable', c.danger),
            LinkState.idle => ('Not connected', c.textDim),
          };
          return Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.desktop_mac_rounded, color: c.textDim),
                const SizedBox(width: Tk.s3),
                Expanded(child: Text(mac.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.text))),
                StatusPill(label: label, color: color),
              ]),
              const SizedBox(height: Tk.s4),
              _Detail('Address', '${mac.host}:${mac.port}'),
              _Detail('Paired', formatWhen(mac.pairedAt)),
              _Detail('Last connected', formatWhen(mac.lastConnectedAt)),
              const SizedBox(height: Tk.s4),
              if (connected)
                OutlinedButton(onPressed: link.disconnect, child: const Text('Disconnect'))
              else
                FilledButton(onPressed: busy ? null : () => link.connectSaved(), child: const Text('Reconnect')),
              const SizedBox(height: Tk.s2),
              OutlinedButton(onPressed: Get.find<PairingController>().startScan, child: const Text('Pair a different Mac')),
              const SizedBox(height: Tk.s1),
              TextButton(
                onPressed: () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'Forget ${mac.name}?',
                    message: 'You\u2019ll need to scan a new QR code to connect again. The stored key for this Mac is deleted from this phone.',
                    confirm: 'Forget',
                    destructive: true,
                  );
                  if (ok) await link.forget();
                },
                child: Text('Forget this Mac', style: TextStyle(color: c.danger)),
              ),
            ]),
          );
        }),
        Padding(
          padding: const EdgeInsets.only(top: Tk.s3, left: Tk.s1),
          child: Text('This phone remembers one Mac at a time. Pairing a different Mac replaces this one.',
              style: TextStyle(fontSize: 13, height: 1.4, color: c.textDim)),
        ),
        Row(children: [
          const Expanded(child: SectionLabel('Connection history')),
          Obx(() => TextButton(
                onPressed: history.history.value.entries.isEmpty
                    ? null
                    : () async {
                        final ok = await confirmDialog(context, title: 'Clear history?', message: 'This only removes the log. Your paired Mac is not affected.', confirm: 'Clear');
                        if (ok) history.clear();
                      },
                child: const Text('Clear'),
              )),
        ]),
        Obx(() {
          final entries = history.history.value.entries;
          if (entries.isEmpty) {
            return Panel(child: Text('Nothing yet. Connections, disconnections and failures will appear here.', style: TextStyle(fontSize: 14, height: 1.4, color: c.textDim)));
          }
          return RowGroup(children: [for (final e in entries) _HistoryRow(entry: e)]);
        }),
        const SizedBox(height: Tk.s4),
        TextButton(onPressed: () => Get.toNamed<void>(Routes.help), child: const Text('Having trouble connecting? Open Help')),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Tk.s1),
      child: Row(children: [
        Text(label, style: TextStyle(fontSize: 14, color: c.textDim)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.text)),
      ]),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});
  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final (icon, color) = switch (entry.kind) {
      HistoryKind.paired => (Icons.link_rounded, c.accent),
      HistoryKind.connected => (Icons.check_circle_rounded, c.success),
      HistoryKind.disconnected => (Icons.link_off_rounded, c.textDim),
      HistoryKind.lost => (Icons.signal_wifi_off_rounded, c.warning),
      HistoryKind.failed => (Icons.error_outline_rounded, c.danger),
      HistoryKind.forgotten => (Icons.delete_outline_rounded, c.textDim),
    };
    return Semantics(
      label: '${entry.kind.label}, ${entry.device}, ${formatWhen(entry.at)}${entry.detail == null ? '' : ', ${entry.detail}'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tk.s4, vertical: Tk.s3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: Tk.s3),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${entry.kind.label}  \u00b7  ${entry.device}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.text)),
              if (entry.detail != null) Text(entry.detail!, style: TextStyle(fontSize: 13, height: 1.3, color: c.textDim)),
            ]),
          ),
          const SizedBox(width: Tk.s2),
          Text(formatWhen(entry.at), style: TextStyle(fontSize: 12, color: c.textDim)),
        ]),
      ),
    );
  }
}
