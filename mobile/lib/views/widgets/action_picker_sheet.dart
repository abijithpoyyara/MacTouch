import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/shortcut_controller.dart';
import '../../core/shortcuts/shortcut_icons.dart';
import '../../core/shortcuts/system_actions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/touchpad/gesture_config.dart';

/// Wraps the choice so "no action" can be told apart from "dismissed".
class ActionPick {
  const ActionPick(this.action);
  final GestureAction? action;
}

Future<ActionPick?> showActionPicker(BuildContext context, GestureAction? current) {
  final c = MtColors.of(context);
  return showModalBottomSheet<ActionPick>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _ActionPicker(current: current),
  );
}

class _ActionPicker extends StatefulWidget {
  const _ActionPicker({required this.current});
  final GestureAction? current;

  @override
  State<_ActionPicker> createState() => _ActionPickerState();
}

class _ActionPickerState extends State<_ActionPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final shortcuts = Get.find<ShortcutController>();
    final matches = shortcuts.library.value.search(query: _query);

    Widget tile({required String title, String? subtitle, IconData? icon, required bool selected, required GestureAction? value}) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: icon == null ? null : Icon(icon, color: selected ? c.accent : c.textDim),
        title: Text(title, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: c.text)),
        subtitle: subtitle == null ? null : Text(subtitle, style: TextStyle(fontSize: 12, color: c.textDim)),
        trailing: selected ? Icon(Icons.check_rounded, color: c.accent) : null,
        onTap: () => Navigator.pop(context, ActionPick(value)),
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text('Choose an action', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.text)),
          const SizedBox(height: 8),
          tile(title: 'No action', icon: Icons.block_rounded, selected: widget.current == null, value: null),
          const Divider(height: 24),
          Text('macOS actions', style: TextStyle(fontWeight: FontWeight.w700, color: c.textDim)),
          for (final id in SystemActionIds.all)
            tile(
              title: SystemActionIds.label(id),
              subtitle: SystemActionIds.requirement(id) ?? 'No setup needed.',
              icon: Icons.desktop_mac_rounded,
              selected: widget.current == SystemGestureAction(id),
              value: SystemGestureAction(id),
            ),
          const Divider(height: 24),
          Text('Shortcuts', style: TextStyle(fontWeight: FontWeight.w700, color: c.textDim)),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search shortcuts', border: OutlineInputBorder()),
            onChanged: (v) => setState(() => _query = v),
          ),
          for (final s in matches)
            tile(
              title: s.name,
              subtitle: '${s.category.label}  \u00b7  ${s.combo}',
              icon: ShortcutIcons.of(s.iconKey),
              selected: widget.current == ShortcutGestureAction(s.id),
              value: ShortcutGestureAction(s.id),
            ),
          if (matches.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text('No shortcuts match.', style: TextStyle(color: c.textDim))),
        ],
      ),
    );
  }
}
