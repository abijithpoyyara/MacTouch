import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/shortcut_controller.dart';
import '../../core/shortcuts/key_catalog.dart';
import '../../core/theme/app_theme.dart';

/// Lets the user change which macOS key code each key sends (for other keyboard layouts).
Future<void> showKeyMappingSheet(BuildContext context) {
  final c = MtColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const _KeyMapping(),
  );
}

class _KeyMapping extends StatefulWidget {
  const _KeyMapping();
  @override
  State<_KeyMapping> createState() => _KeyMappingState();
}

class _KeyMappingState extends State<_KeyMapping> {
  String _query = '';

  Future<void> _edit(ShortcutController ctrl, KeyDef key) async {
    final map = ctrl.keyMap.value;
    final field = TextEditingController(text: '${map.codeFor(key.id) ?? key.code}');
    final code = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Key code for ${key.label}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('macOS virtual key code, 0\u2013255. Default for this key: '),
            Text('${key.code}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(controller: field, keyboardType: TextInputType.number, autofocus: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final v = int.tryParse(field.text.trim());
              if (v != null && v >= 0 && v <= 255) Navigator.pop(ctx, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (code != null) ctrl.setKeyCode(key.id, code);
  }

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final ctrl = Get.find<ShortcutController>();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, scroll) => Obx(() {
        final map = ctrl.keyMap.value;
        final keys = KeyCatalog.search(_query);
        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Row(children: [
              Expanded(child: Text('Key mapping', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.text))),
              TextButton(onPressed: map.overrides.isEmpty ? null : ctrl.resetKeyMap, child: const Text('Reset all')),
            ]),
            Text(
              'Shortcuts send macOS key codes, which are physical key positions (US layout by default). '
              'If a shortcut types the wrong key on your keyboard layout, change that key\u2019s code here.',
              style: TextStyle(fontSize: 13, height: 1.4, color: c.textDim),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search keys', border: OutlineInputBorder()),
              onChanged: (v) => setState(() => _query = v),
            ),
            for (final k in keys)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${k.label}   (${k.group})', style: TextStyle(color: c.text)),
                subtitle: map.isOverridden(k.id) ? Text('Changed from ${k.code}', style: TextStyle(color: c.warning, fontSize: 12)) : null,
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${map.codeFor(k.id)}', style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                  if (map.isOverridden(k.id))
                    IconButton(tooltip: 'Reset', icon: const Icon(Icons.restart_alt_rounded), onPressed: () => ctrl.resetKey(k.id)),
                ]),
                onTap: () => _edit(ctrl, k),
              ),
          ],
        );
      }),
    );
  }
}
