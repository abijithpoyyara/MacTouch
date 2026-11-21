import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes.dart';
import '../controllers/connection_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/shortcut_controller.dart';
import '../controllers/touchpad_controller.dart';
import '../core/haptics.dart';
import '../core/shortcuts/shortcut_icons.dart';
import '../core/shortcuts/shortcut_model.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import 'widgets/mt_scaffold.dart' show StatusDot;
import 'widgets/touchpad_settings_sheet.dart';

/// The main screen: a large touch surface with a minimal header. Works in portrait and landscape.
class TouchpadView extends StatefulWidget {
  const TouchpadView({super.key});

  @override
  State<TouchpadView> createState() => _TouchpadViewState();
}

class _TouchpadViewState extends State<TouchpadView> with WidgetsBindingObserver {
  final _pad = Get.find<TouchpadController>();
  final _link = Get.find<ConnectionController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pad.onLeave();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pad.onLeave();   // never leave a button held while backgrounded
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          final landscape = box.maxWidth > box.maxHeight;
          final header = _Header(link: _link, pad: _pad);
          final banner = _AccessibilityBanner(pad: _pad);
          final surface = _Surface(pad: _pad, link: _link);
          final pad = EdgeInsets.all(landscape ? Tk.s2 : Tk.s3);

          if (landscape) {
            return Padding(
              padding: pad,
              child: Row(children: [
                Expanded(child: Column(children: [header, banner, const SizedBox(height: Tk.s1), Expanded(child: surface)])),
                const SizedBox(width: Tk.s3),
                SizedBox(
                  width: (box.maxWidth * 0.28).clamp(190.0, 260.0),
                  child: Column(children: [
                    Expanded(child: _QuickBar(pad: _pad, vertical: true)),
                    const SizedBox(height: Tk.s2),
                    _Toggles(pad: _pad),
                    const SizedBox(height: Tk.s2),
                    SizedBox(height: (box.maxHeight * 0.2).clamp(56.0, 84.0), child: _ClickButtons(pad: _pad)),
                  ]),
                ),
              ]),
            );
          }
          return Padding(
            padding: pad,
            child: Column(children: [
              header,
              banner,
              _QuickBar(pad: _pad, vertical: false),
              const SizedBox(height: Tk.s1),
              Expanded(child: surface),
              const SizedBox(height: Tk.s3),
              _Toggles(pad: _pad),
              const SizedBox(height: Tk.s2),
              SizedBox(height: (box.maxHeight * 0.1).clamp(60.0, 88.0), child: _ClickButtons(pad: _pad)),
            ]),
          );
        }),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.link, required this.pad});
  final ConnectionController link;
  final TouchpadController pad;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return Row(children: [
      IconButton(tooltip: 'Back', onPressed: () => Get.back<void>(), icon: Icon(Icons.arrow_back_rounded, color: c.text)),
      Expanded(
        child: Obx(() {
          final state = link.state.value;
          final (label, color) = switch (state) {
            LinkState.connected => ('Connected', c.success),
            LinkState.connecting || LinkState.reconnecting => ('Reconnecting\u2026', c.warning),
            LinkState.offline => ('No Wi-Fi', c.danger),
            LinkState.failed => ('Connection lost', c.danger),
            LinkState.idle => ('Disconnected', c.textDim),
          };
          return Semantics(
            label: '${link.mac.value?.name ?? 'Mac'}, $label',
            excludeSemantics: true,
            child: Row(children: [
              StatusDot(color: color),
              const SizedBox(width: Tk.s2),
              Flexible(
                child: Text('${link.mac.value?.name ?? 'Mac'} \u00b7 $label',
                    overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
              ),
              if (state == LinkState.connected)
                ValueListenableBuilder<int?>(
                  valueListenable: pad.rtt,
                  builder: (_, ms, __) => ms == null
                      ? const SizedBox.shrink()
                      : Padding(padding: const EdgeInsets.only(left: Tk.s2), child: Text('$ms ms', style: TextStyle(fontSize: 12, color: c.textDim))),
                ),
            ]),
          );
        }),
      ),
      PopupMenuButton<String>(
        tooltip: 'More',
        icon: Icon(Icons.more_horiz_rounded, color: c.text),
        onSelected: (v) {
          switch (v) {
            case 'shortcuts':
              Get.toNamed<void>(Routes.shortcuts);
            case 'gestures':
              Get.toNamed<void>(Routes.gestures);
            case 'pointer':
              showTouchpadSettings(context);
            case 'settings':
              Get.toNamed<void>(Routes.settings);
            case 'help':
              Get.toNamed<void>(Routes.help);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'shortcuts', child: Text('Shortcuts')),
          PopupMenuItem(value: 'gestures', child: Text('Gestures')),
          PopupMenuItem(value: 'pointer', child: Text('Pointer and scrolling')),
          PopupMenuItem(value: 'settings', child: Text('Settings')),
          PopupMenuItem(value: 'help', child: Text('Help')),
        ],
      ),
    ]);
  }
}

class _AccessibilityBanner extends StatelessWidget {
  const _AccessibilityBanner({required this.pad});
  final TouchpadController pad;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return ValueListenableBuilder<bool?>(
      valueListenable: pad.macAccessibility,
      builder: (_, allowed, __) {
        if (allowed != false) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(top: Tk.s1, bottom: Tk.s1),
          padding: const EdgeInsets.all(Tk.s3),
          decoration: BoxDecoration(
            color: c.warning.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(Tk.rMd),
            border: Border.all(color: c.warning.withValues(alpha: 0.5)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lock_outline_rounded, color: c.warning, size: 20),
            const SizedBox(width: Tk.s3),
            Expanded(
              child: Text(
                'Your Mac hasn\u2019t allowed MacTouch to control the pointer yet. On the Mac, open System Settings > '
                'Privacy & Security > Accessibility and turn MacTouch on.',
                style: TextStyle(fontSize: 13, height: 1.35, color: c.text),
              ),
            ),
          ]),
        );
      },
    );
  }
}

/// Favorite shortcuts, one tap away. Horizontal in portrait, a vertical list in landscape.
class _QuickBar extends StatelessWidget {
  const _QuickBar({required this.pad, required this.vertical});
  final TouchpadController pad;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final prefs = Get.find<SettingsController>();
    final shortcuts = Get.find<ShortcutController>();
    return Obx(() {
      if (!prefs.prefs.value.showQuickBar) return const SizedBox.shrink();
      final favorites = shortcuts.library.value.items.where((i) => i.favorite).toList();
      final chips = <Widget>[
        for (final item in favorites) _QuickChip(item: item, pad: pad, vertical: vertical),
        _QuickChip.all(vertical: vertical, hasFavorites: favorites.isNotEmpty),
      ];
      if (vertical) {
        return ListView(children: chips);
      }
      return SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal, children: chips));
    });
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required ShortcutItem this.item, required this.pad, required this.vertical}) : _isAll = false, _hasFavorites = true;
  const _QuickChip.all({required this.vertical, required bool hasFavorites})
      : item = null,
        pad = null,
        _isAll = true,
        _hasFavorites = hasFavorites;

  final ShortcutItem? item;
  final TouchpadController? pad;
  final bool vertical;
  final bool _isAll;
  final bool _hasFavorites;

  void _run(BuildContext context) {
    final i = item;
    if (i == null) return;
    final result = pad!.runShortcut(i);
    if (result == ShortcutRunResult.sent) {
      Haptics.tap();
    } else if (result == ShortcutRunResult.invalid) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('This shortcut has no valid key. Edit it in Shortcuts.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final label = _isAll ? (_hasFavorites ? 'All shortcuts' : 'Star shortcuts to pin them here') : item!.name;
    final icon = _isAll ? Icons.bolt_rounded : ShortcutIcons.of(item!.iconKey);
    return Padding(
      padding: EdgeInsets.only(right: vertical ? 0 : Tk.s2, bottom: vertical ? Tk.s2 : 0),
      child: Semantics(
        button: true,
        label: _isAll ? 'Open shortcuts' : 'Run ${item!.name}',
        excludeSemantics: true,
        child: Material(
          color: _isAll ? c.surfaceHigh : c.surface,
          borderRadius: BorderRadius.circular(Tk.rMd),
          child: InkWell(
            borderRadius: BorderRadius.circular(Tk.rMd),
            onTap: _isAll
                ? () {
                    Haptics.tap();
                    Get.toNamed<void>(Routes.shortcuts);
                  }
                : () => _run(context),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: Tk.s3, vertical: Tk.s2),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(Tk.rMd), border: Border.all(color: c.outline)),
              child: Row(mainAxisSize: vertical ? MainAxisSize.max : MainAxisSize.min, children: [
                Icon(icon, size: 18, color: c.accent),
                const SizedBox(width: Tk.s2),
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The big touch surface. A raw [Listener] (not gesture recognizers) so every finger is delivered at once.
class _Surface extends StatelessWidget {
  const _Surface({required this.pad, required this.link});
  final TouchpadController pad;
  final ConnectionController link;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final prefs = Get.find<SettingsController>();
    return Semantics(
      container: true,
      label: 'Touchpad. One finger moves the pointer, tap to click, two fingers scroll, three or four fingers swipe.',
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: pad.onPointerDown,
        onPointerMove: pad.onPointerMove,
        onPointerUp: pad.onPointerUp,
        onPointerCancel: pad.onPointerCancel,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.surface, Color.lerp(c.surface, c.bg, 0.5)!]),
            borderRadius: BorderRadius.circular(Tk.rXl),
            border: Border.all(color: c.outline),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Tk.rXl),
            child: Stack(fit: StackFit.expand, children: [
              CustomPaint(painter: _TouchPainter(pad.touches, c.accent)),
              Center(
                child: Obx(() {
                  final connected = link.state.value == LinkState.connected;
                  if (!connected) {
                    return Padding(
                      padding: const EdgeInsets.all(Tk.s6),
                      child: Text('Not connected.\nGo back and reconnect to your Mac.',
                          textAlign: TextAlign.center, style: TextStyle(fontSize: 15, height: 1.4, color: c.textDim)),
                    );
                  }
                  if (!prefs.prefs.value.showHints) return const SizedBox.shrink();
                  return ValueListenableBuilder<Map<int, Offset>>(
                    valueListenable: pad.touches,
                    builder: (_, touches, __) => AnimatedOpacity(
                      opacity: touches.isEmpty ? 1 : 0,
                      duration: Tk.normal,
                      child: const IgnorePointer(child: _Hints()),
                    ),
                  );
                }),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Hints extends StatelessWidget {
  const _Hints();

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    const rows = [
      (Icons.touch_app_rounded, 'Tap', 'click'),
      (Icons.swap_vert_rounded, 'Two fingers', 'scroll'),
      (Icons.keyboard_double_arrow_up_rounded, 'Three fingers', 'Mission Control and desktops'),
      (Icons.pan_tool_alt_rounded, 'Press and hold', 'drag'),
    ];
    return Padding(
      padding: const EdgeInsets.all(Tk.s6),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(r.$1, size: 20, color: c.textDim.withValues(alpha: 0.8)),
              const SizedBox(width: Tk.s3),
              Text('${r.$2}  ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textDim)),
              Flexible(child: Text(r.$3, style: TextStyle(fontSize: 14, color: c.textDim.withValues(alpha: 0.85)))),
            ]),
          ),
      ]),
    );
  }
}

class _TouchPainter extends CustomPainter {
  _TouchPainter(this.touches, this.color) : super(repaint: touches);
  final ValueNotifier<Map<int, Offset>> touches;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in touches.value.values) {
      canvas.drawCircle(p, 38, Paint()..color = color.withValues(alpha: 0.14));
      canvas.drawCircle(p, 14, Paint()..color = color.withValues(alpha: 0.85));
    }
  }

  @override
  bool shouldRepaint(_TouchPainter old) => old.color != color || old.touches != touches;
}

class _Toggles extends StatelessWidget {
  const _Toggles({required this.pad});
  final TouchpadController pad;

  @override
  Widget build(BuildContext context) {
    return Obx(() => Row(children: [
          Expanded(
            child: _Toggle(
              icon: Icons.open_with_rounded, label: 'Drag', active: pad.dragMode.value,
              onTap: () {
                Haptics.tap();
                pad.setDragMode(!pad.dragMode.value);
              },
            ),
          ),
          const SizedBox(width: Tk.s2),
          Expanded(
            child: _Toggle(
              icon: Icons.lock_rounded, label: 'Drag lock', active: pad.dragLock.value,
              onTap: () {
                Haptics.tap();
                pad.setDragLock(!pad.dragLock.value);
              },
            ),
          ),
        ]));
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return Semantics(
      button: true,
      toggled: active,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Tk.fast,
          height: Tk.touchTarget,
          decoration: BoxDecoration(color: active ? c.accent : c.surfaceHigh, borderRadius: BorderRadius.circular(Tk.rMd)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: active ? c.onAccent : c.textDim),
            const SizedBox(width: Tk.s2),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: active ? c.onAccent : c.text))),
          ]),
        ),
      ),
    );
  }
}

class _ClickButtons extends StatelessWidget {
  const _ClickButtons({required this.pad});
  final TouchpadController pad;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        flex: 3,
        child: _HoldButton(label: 'Left click', pressed: pad.leftPressed, onDown: pad.pressLeft, onUp: pad.releaseLeft),
      ),
      const SizedBox(width: Tk.s3),
      Expanded(
        flex: 2,
        child: _HoldButton(label: 'Right click', pressed: pad.rightPressed, onDown: pad.pressRight, onUp: pad.releaseRight, subtle: true),
      ),
    ]);
  }
}

/// Press = button down, release = button up; stays pressed while held so you can drag with another finger.
class _HoldButton extends StatelessWidget {
  const _HoldButton({required this.label, required this.pressed, required this.onDown, required this.onUp, this.subtle = false});
  final String label;
  final RxBool pressed;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return Semantics(
      button: true,
      label: label,
      hint: 'Press and hold to keep the button down',
      excludeSemantics: true,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => onDown(),
        onPointerUp: (_) => onUp(),
        onPointerCancel: (_) => onUp(),
        child: Obx(() {
          final down = pressed.value;
          return AnimatedContainer(
            duration: Tk.fast,
            decoration: BoxDecoration(
              color: down ? c.accent : (subtle ? c.surfaceHigh : c.surface),
              borderRadius: BorderRadius.circular(Tk.rLg),
              border: Border.all(color: down ? c.accent : c.outline),
            ),
            alignment: Alignment.center,
            child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: down ? c.onAccent : c.text)),
          );
        }),
      ),
    );
  }
}
