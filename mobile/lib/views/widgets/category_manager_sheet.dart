import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/shortcut_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import 'ui_kit.dart';

/// Create, rename and delete your own shortcut categories. Deleting a category keeps its shortcuts as plain Custom ones.
Future<void> showCategoryManager(BuildContext context) {
  final c = MtColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Tk.rXl))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: const _CategoryManager(),
    ),
  );
}

class _CategoryManager extends StatefulWidget {
  const _CategoryManager();
  @override
  State<_CategoryManager> createState() => _CategoryManagerState();
}

class _CategoryManagerState extends State<_CategoryManager> {
  final _ctrl = Get.find<ShortcutController>();
  final _field = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _add() {
    final problem = _ctrl.addGroup(_field.text);
    setState(() => _error = problem);
    if (problem == null) _field.clear();
  }

  Future<void> _rename(String name) async {
    final field = TextEditingController(text: name);
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Rename category'),
          content: TextField(controller: field, autofocus: true, maxLength: 30, decoration: InputDecoration(errorText: error)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final problem = _ctrl.renameGroup(name, field.text);
                if (problem != null) {
                  setLocal(() => error = problem);
                } else {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    field.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(Tk.s5),
        children: [
          Text('Categories', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.text)),
          const SizedBox(height: Tk.s2),
          Text('Built-in categories can\u2019t be changed. Your own categories appear as extra filters and in the shortcut editor.',
              style: TextStyle(fontSize: 14, height: 1.4, color: c.textDim)),
          const SizedBox(height: Tk.s4),
          Obx(() {
            final groups = _ctrl.allGroups;
            if (groups.isEmpty) {
              return Padding(padding: const EdgeInsets.symmetric(vertical: Tk.s3), child: Text('You have no categories yet.', style: TextStyle(color: c.textDim)));
            }
            return Column(children: [
              for (final g in groups)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(g, style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
                  subtitle: Text('${_ctrl.library.value.items.where((i) => i.group == g).length} shortcuts', style: TextStyle(color: c.textDim)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(tooltip: 'Rename $g', icon: const Icon(Icons.edit_rounded), onPressed: () => _rename(g)),
                    IconButton(
                      tooltip: 'Delete $g',
                      icon: Icon(Icons.delete_outline_rounded, color: c.danger),
                      onPressed: () async {
                        final ok = await confirmDialog(context,
                            title: 'Delete \u201c$g\u201d?', message: 'Its shortcuts are kept as plain Custom shortcuts.', confirm: 'Delete', destructive: true);
                        if (ok) _ctrl.deleteGroup(g);
                      },
                    ),
                  ]),
                ),
            ]);
          }),
          const SizedBox(height: Tk.s3),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextField(
                controller: _field,
                maxLength: 30,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
                decoration: InputDecoration(labelText: 'New category', errorText: _error, border: const OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: Tk.s3),
            Padding(padding: const EdgeInsets.only(top: 6), child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(80, 52)), onPressed: _add, child: const Text('Add'))),
          ]),
        ],
      ),
    );
  }
}
