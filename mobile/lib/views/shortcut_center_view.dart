import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/shortcut_controller.dart';
import '../controllers/touchpad_controller.dart';
import '../core/haptics.dart';
import '../core/shortcuts/shortcut_icons.dart';
import '../core/shortcuts/shortcut_model.dart';
import '../core/theme/app_theme.dart';
import 'widgets/category_manager_sheet.dart';
import 'widgets/key_mapping_sheet.dart';
import 'widgets/shortcut_editor_sheet.dart';
import 'widgets/shortcut_pack_sheet.dart';

class ShortcutCenterView extends StatelessWidget {
  const ShortcutCenterView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final ctrl = Get.find<ShortcutController>();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showShortcutEditor(context, defaultCategory: ctrl.category.value, defaultGroup: ctrl.group.value),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New shortcut'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(children: [
                IconButton(tooltip: 'Back', onPressed: () => Get.back(), icon: Icon(Icons.arrow_back_rounded, color: c.text)),
                Expanded(child: Text('Shortcuts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.text))),
                Obx(() => IconButton(
                      tooltip: ctrl.reorderMode.value ? 'Done reordering' : 'Reorder',
                      onPressed: () => ctrl.reorderMode.value = !ctrl.reorderMode.value,
                      icon: Icon(ctrl.reorderMode.value ? Icons.check_rounded : Icons.drag_handle_rounded,
                          color: ctrl.reorderMode.value ? c.accent : c.text),
                    )),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (v) {
                    if (v == 'keys') showKeyMappingSheet(context);
                    if (v == 'pack') showShortcutPackSheet(context);
                    if (v == 'groups') showCategoryManager(context);
                    if (v == 'restore') _confirmRestore(context, ctrl);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'pack', child: Text('Import or export\u2026')),
                    PopupMenuItem(value: 'groups', child: Text('Manage categories\u2026')),
                    PopupMenuItem(value: 'keys', child: Text('Key mapping\u2026')),
                    PopupMenuItem(value: 'restore', child: Text('Restore default shortcuts')),
                  ],
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                onChanged: (v) => ctrl.query.value = v,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Search shortcuts, keys or apps',
                  filled: true,
                  fillColor: c.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.outline)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.outline)),
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: Obx(() => ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _chip('All', ctrl.category.value == null && !ctrl.favoritesOnly.value, () {
                        ctrl.category.value = null;
                        ctrl.group.value = null;
                        ctrl.favoritesOnly.value = false;
                      }),
                      _chip('Favorites', ctrl.favoritesOnly.value, () {
                        ctrl.category.value = null;
                        ctrl.group.value = null;
                        ctrl.favoritesOnly.value = true;
                      }),
                      for (final cat in ShortcutCategory.values)
                        _chip(cat.label, ctrl.category.value == cat && ctrl.group.value == null, () {
                          ctrl.category.value = cat;
                          ctrl.group.value = null;
                          ctrl.favoritesOnly.value = false;
                        }),
                      for (final g in ctrl.allGroups)
                        _chip(g, ctrl.group.value == g, () {
                          ctrl.category.value = ShortcutCategory.custom;
                          ctrl.group.value = g;
                          ctrl.favoritesOnly.value = false;
                        }),
                    ],
                  )),
            ),
            // GetX only tracks what is read inside this closure, so every observable the list depends on is read here.
            Expanded(child: Obx(() {
              ctrl.library.value;
              ctrl.keyMap.value;
              final query = ctrl.query.value.trim();
              final reorder = ctrl.reorderMode.value && ctrl.canReorder;
              return _List(ctrl: ctrl, items: ctrl.visible, query: query, reorder: reorder);
            })),
          ],
        ),
      ),
    );
  }

  static Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
      );

  static Future<void> _confirmRestore(BuildContext context, ShortcutController ctrl) async {
    final c = MtColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Restore default shortcuts?'),
        content: const Text('Built-in shortcuts are reset to their originals and any you deleted come back. Shortcuts you created are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ),
    );
    if (ok == true) ctrl.restoreDefaults();
  }
}

class _List extends StatelessWidget {
  const _List({required this.ctrl, required this.items, required this.query, required this.reorder});
  final ShortcutController ctrl;
  final List<ShortcutItem> items;
  final String query;
  final bool reorder;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.keyboard_rounded, size: 44, color: c.textDim),
            const SizedBox(height: 12),
            Text(query.isEmpty ? 'Nothing here yet.' : 'No shortcuts match \u201c$query\u201d.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: c.textDim)),
          ]),
        ),
      );
    }

    if (reorder) {
      return ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        buildDefaultDragHandles: false,
        itemCount: items.length,
        // ignore: deprecated_member_use
        onReorder: ctrl.reorder,
        itemBuilder: (_, i) => KeyedSubtree(
          key: ValueKey(items[i].id),
          child: _Tile(item: items[i], ctrl: ctrl, dragIndex: i),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: items.length,
      itemBuilder: (_, i) => _Tile(item: items[i], ctrl: ctrl),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item, required this.ctrl, this.dragIndex});
  final ShortcutItem item;
  final ShortcutController ctrl;
  final int? dragIndex;

  void _run(BuildContext context) {
    final result = Get.find<TouchpadController>().runShortcut(item);
    final text = switch (result) {
      ShortcutRunResult.sent => null,
      ShortcutRunResult.notConnected => 'Connect to your Mac first.',
      ShortcutRunResult.invalid => 'This shortcut has no valid key. Edit it to fix that.',
    };
    if (result == ShortcutRunResult.sent) Haptics.tap();
    if (text != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _delete(BuildContext context) async {
    final c = MtColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Delete \u201c${item.name}\u201d?'),
        content: Text(item.preset ? 'You can bring it back with \u201cRestore default shortcuts\u201d.' : 'This can\u2019t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: c.danger))),
        ],
      ),
    );
    if (ok == true) ctrl.delete(item.id);
  }

  void _showNote(BuildContext context) {
    final c = MtColors.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(item.name),
        content: Text(item.note ?? ''),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: dragIndex != null ? null : () => _run(context),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: c.outline)),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(14)),
                child: Icon(ShortcutIcons.of(item.iconKey), color: c.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
                  const SizedBox(height: 2),
                  Text('${item.categoryLabel}  \u00b7  ${item.combo}${item.holdMs > 0 ? '  \u00b7  hold ${item.holdMs} ms' : ''}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.textDim)),
                ]),
              ),
              if (item.note != null)
                IconButton(
                  tooltip: 'Requirements and notes',
                  onPressed: () => _showNote(context),
                  icon: Icon(Icons.info_outline_rounded, size: 20, color: item.kind == ShortcutKind.system && item.note != null ? c.warning : c.textDim),
                ),
              if (dragIndex != null)
                ReorderableDragStartListener(index: dragIndex!, child: Padding(padding: const EdgeInsets.all(12), child: Icon(Icons.drag_handle_rounded, color: c.textDim)))
              else ...[
                IconButton(
                  tooltip: item.favorite ? 'Remove from favorites' : 'Add to favorites',
                  onPressed: () => ctrl.toggleFavorite(item.id),
                  icon: Icon(item.favorite ? Icons.star_rounded : Icons.star_border_rounded, color: item.favorite ? c.warning : c.textDim),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (v) {
                    if (v == 'edit') showShortcutEditor(context, existing: item);
                    if (v == 'delete') _delete(context);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
