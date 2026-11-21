import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/shortcut_controller.dart';
import '../../core/shortcuts/key_catalog.dart';
import '../../core/shortcuts/shortcut_icons.dart';
import '../../core/shortcuts/shortcut_model.dart';
import '../../core/theme/app_theme.dart';

/// Create ([existing] == null) or edit a shortcut. Saves straight into the library.
Future<void> showShortcutEditor(BuildContext context, {ShortcutItem? existing, ShortcutCategory? defaultCategory, String? defaultGroup}) {
  final c = MtColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _Editor(existing: existing, defaultCategory: defaultCategory, defaultGroup: defaultGroup),
    ),
  );
}

class _Editor extends StatefulWidget {
  const _Editor({this.existing, this.defaultCategory, this.defaultGroup});
  final ShortcutItem? existing;
  final ShortcutCategory? defaultCategory;
  final String? defaultGroup;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  final _ctrl = Get.find<ShortcutController>();
  late final TextEditingController _name;
  late String _icon;
  late ShortcutCategory _category;
  String? _group;
  late int _mods;
  late String _keyId;
  late int _hold;
  late bool _favorite;
  String? _error;

  bool get _isSystem => widget.existing?.kind == ShortcutKind.system;

  String get _categoryValue =>
      _category == ShortcutCategory.custom && _group != null && _ctrl.allGroups.contains(_group) ? 'g:$_group' : _category.id;

  Future<void> _onCategoryChanged(String? v) async {
    if (v == null) return;
    if (v == '__new__') {
      final name = await _askNewCategory();
      if (name != null) {
        setState(() {
          _category = ShortcutCategory.custom;
          _group = name;
        });
      }
    } else if (v.startsWith('g:')) {
      setState(() {
        _category = ShortcutCategory.custom;
        _group = v.substring(2);
      });
    } else {
      setState(() {
        _category = ShortcutCategory.fromId(v) ?? ShortcutCategory.custom;
        _group = null;
      });
    }
  }

  /// Creates the category and returns its name, or null if cancelled or invalid.
  Future<String?> _askNewCategory() async {
    final field = TextEditingController();
    String? error;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New category'),
          content: TextField(
            controller: field,
            autofocus: true,
            maxLength: ShortcutItem.maxGroupLength,
            decoration: InputDecoration(labelText: 'Name', errorText: error),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final problem = _ctrl.addGroup(field.text);
                if (problem != null) {
                  setLocal(() => error = problem);
                } else {
                  Navigator.pop(ctx, ShortcutItem.cleanGroup(field.text));
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    return name;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _icon = e?.iconKey ?? 'bolt';
    _category = e?.category ?? widget.defaultCategory ?? ShortcutCategory.custom;
    _group = e != null ? e.group : widget.defaultGroup;
    _mods = e?.modifiers ?? 0;
    _keyId = e?.keyId ?? '';
    _hold = e?.holdMs ?? 0;
    _favorite = e?.favorite ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  ShortcutItem _build() {
    final e = widget.existing;
    return ShortcutItem(
      id: e?.id ?? _ctrl.newId(),
      name: _name.text.trim(),
      category: _category,
      group: _category == ShortcutCategory.custom ? _group : null,
      iconKey: _icon,
      kind: e?.kind ?? ShortcutKind.key,
      systemAction: e?.systemAction,
      modifiers: _mods,
      keyId: _keyId,
      holdMs: _hold,
      favorite: _favorite,
      order: e?.order ?? 0,
      note: e?.note,
      preset: e?.preset ?? false,
    );
  }

  void _save() {
    final item = _build();
    final problem = item.validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    widget.existing == null ? _ctrl.add(item) : _ctrl.updateItem(item);
    Navigator.pop(context);
  }

  Future<void> _chooseKey() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MtColors.of(context).surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _KeyPicker(selected: _keyId),
    );
    if (picked != null) setState(() => _keyId = picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final preview = _build();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Text(widget.existing == null ? 'New shortcut' : 'Edit shortcut',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.text)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Text('Icon', style: TextStyle(fontWeight: FontWeight.w600, color: c.textDim)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in ShortcutIcons.all.entries)
              Semantics(
                label: 'Icon ${e.key}',
                selected: _icon == e.key,
                button: true,
                child: GestureDetector(
                  onTap: () => setState(() => _icon = e.key),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _icon == e.key ? c.accent : c.surfaceHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(e.value, color: _icon == e.key ? c.onAccent : c.textDim),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: _categoryValue,
            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
            items: [
              for (final cat in ShortcutCategory.values) DropdownMenuItem(value: cat.id, child: Text(cat.label)),
              for (final g in _ctrl.allGroups) DropdownMenuItem(value: 'g:$g', child: Text('Custom \u203a $g')),
              const DropdownMenuItem(value: '__new__', child: Text('New category\u2026')),
            ],
            onChanged: _onCategoryChanged,
          ),
          if (_isSystem)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: MtNote(text: 'This runs a macOS system action. Its keys can\u2019t be edited.${widget.existing?.note == null ? '' : '\n${widget.existing!.note}'}'),
            )
          else ...[
            const SizedBox(height: 16),
            Text('Modifiers', style: TextStyle(fontWeight: FontWeight.w600, color: c.textDim)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final bit in Mod.ordered)
                FilterChip(
                  label: Text('${Mod.symbols(bit)} ${Mod.name(bit)}'),
                  selected: _mods & bit != 0,
                  onSelected: (on) => setState(() => _mods = on ? (_mods | bit) : (_mods & ~bit)),
                ),
            ]),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _chooseKey,
              icon: const Icon(Icons.keyboard_rounded),
              label: Text(_keyId.isEmpty ? 'Choose key' : 'Key: ${KeyCatalog.label(_keyId)}'),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text('Hold keys down', style: TextStyle(fontWeight: FontWeight.w600, color: c.text))),
              Text(_hold == 0 ? 'Tap' : '$_hold ms', style: TextStyle(color: c.textDim)),
            ]),
            Slider(value: _hold.toDouble(), min: 0, max: 3000, divisions: 60, onChanged: (v) => setState(() => _hold = v.round())),
            Text('0 = a quick tap. A longer hold keeps the keys pressed, for example Command-Tab with the app switcher left open.',
                style: TextStyle(fontSize: 12, height: 1.35, color: c.textDim)),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Favorite'),
            value: _favorite,
            onChanged: (v) => setState(() => _favorite = v),
          ),
          const SizedBox(height: 4),
          Center(child: Text(preview.combo.isEmpty ? '\u2013' : preview.combo, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: c.text))),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: c.danger))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(onPressed: _save, child: const Text('Save'))),
          ]),
        ],
      ),
    );
  }
}

class MtNote extends StatelessWidget {
  const MtNote({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(14)),
      child: Text(text, style: TextStyle(fontSize: 13, height: 1.4, color: c.textDim)),
    );
  }
}

class _KeyPicker extends StatefulWidget {
  const _KeyPicker({required this.selected});
  final String selected;
  @override
  State<_KeyPicker> createState() => _KeyPickerState();
}

class _KeyPickerState extends State<_KeyPicker> {
  String _query = '';

  Future<void> _custom() async {
    final field = TextEditingController();
    final code = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom key code'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Enter a macOS virtual key code (0\u2013255) for a key that is not in the list.'),
          const SizedBox(height: 12),
          TextField(controller: field, keyboardType: TextInputType.number, autofocus: true),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final v = int.tryParse(field.text.trim());
              if (v != null && v >= 0 && v <= 255) Navigator.pop(ctx, v);
            },
            child: const Text('Use'),
          ),
        ],
      ),
    );
    if (code != null && mounted) Navigator.pop(context, KeyCatalog.rawId(code));
  }

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final map = Get.find<ShortcutController>().keyMap.value;
    final keys = KeyCatalog.search(_query);
    // The first key of each group gets a heading.
    final firstOfGroup = <String>{};
    String? seenGroup;
    for (final k in keys) {
      if (k.group != seenGroup) {
        seenGroup = k.group;
        firstOfGroup.add(k.id);
      }
    }
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text('Choose key', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.text)),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search keys', border: OutlineInputBorder()),
            onChanged: (v) => setState(() => _query = v),
          ),
          TextButton.icon(onPressed: _custom, icon: const Icon(Icons.pin_rounded), label: const Text('Custom key code\u2026')),
          for (final k in keys) ...[
            if (firstOfGroup.contains(k.id))
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Text(k.group, style: TextStyle(fontWeight: FontWeight.w700, color: c.textDim)),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(k.label, style: TextStyle(fontWeight: widget.selected == k.id ? FontWeight.w700 : FontWeight.w500, color: c.text)),
              trailing: Text('code ${map.codeFor(k.id)}', style: TextStyle(color: c.textDim, fontSize: 12)),
              selected: widget.selected == k.id,
              onTap: () => Navigator.pop(context, k.id),
            ),
          ],
        ],
      ),
    );
  }
}
