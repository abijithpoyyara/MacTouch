import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/shortcut_controller.dart';
import '../../core/shortcuts/shortcut_pack.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// Export shortcuts as text to copy, or paste text to import them.
Future<void> showShortcutPackSheet(BuildContext context) {
  final c = MtColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Tk.rXl))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: const _PackSheet(),
    ),
  );
}

class _PackSheet extends StatefulWidget {
  const _PackSheet();
  @override
  State<_PackSheet> createState() => _PackSheetState();
}

class _PackSheetState extends State<_PackSheet> {
  final _ctrl = Get.find<ShortcutController>();
  final _importField = TextEditingController();
  bool _includeBuiltIn = false;
  PackImport? _preview;

  @override
  void dispose() {
    _importField.dispose();
    super.dispose();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _copy() async {
    final text = _ctrl.exportText(includeBuiltIn: _includeBuiltIn);
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _snack('Copied. Paste it into a note, message or file to keep or share it.');
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    _importField.text = data!.text!;
    _check();
  }

  void _check() => setState(() => _preview = _ctrl.readPack(_importField.text));

  void _import() {
    final pack = _preview;
    if (pack == null || pack.error != null) return;
    final added = _ctrl.importPack(pack);
    _importField.clear();
    setState(() => _preview = null);
    _snack('Imported $added shortcut${added == 1 ? '' : 's'}.');
  }

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final userCount = _ctrl.library.value.items.where((i) => !i.preset).length;
    final preview = _preview;
    return DefaultTabController(
      length: 2,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: Tk.s4),
          Text('Import or export shortcuts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.text)),
          const TabBar(tabs: [Tab(text: 'Export'), Tab(text: 'Import')]),
          Flexible(
            child: TabBarView(children: [
              // ---- export
              ListView(padding: const EdgeInsets.all(Tk.s5), children: [
                Text('Copies your shortcuts and categories as text. Paste it into a note or message to back it up or move it to another phone.',
                    style: TextStyle(fontSize: 14, height: 1.4, color: c.textDim)),
                const SizedBox(height: Tk.s3),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include built-in shortcuts'),
                  subtitle: Text(_includeBuiltIn ? 'Everything in the library' : '$userCount of your own shortcut${userCount == 1 ? '' : 's'}'),
                  value: _includeBuiltIn,
                  onChanged: (v) => setState(() => _includeBuiltIn = v),
                ),
                const SizedBox(height: Tk.s2),
                FilledButton.icon(
                  onPressed: (_includeBuiltIn || userCount > 0) ? _copy : null,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy to clipboard'),
                ),
                if (!_includeBuiltIn && userCount == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: Tk.s2),
                    child: Text('You haven\u2019t created any shortcuts yet. Turn on \u201cInclude built-in shortcuts\u201d or create one first.',
                        style: TextStyle(fontSize: 13, height: 1.4, color: c.textDim)),
                  ),
              ]),
              // ---- import
              ListView(padding: const EdgeInsets.all(Tk.s5), children: [
                Text('Paste text that was exported from MacTouch. Imported shortcuts are added to your library; nothing is replaced.',
                    style: TextStyle(fontSize: 14, height: 1.4, color: c.textDim)),
                const SizedBox(height: Tk.s3),
                TextField(
                  controller: _importField,
                  minLines: 4,
                  maxLines: 8,
                  onChanged: (_) => setState(() => _preview = null),
                  decoration: const InputDecoration(hintText: 'Paste here', border: OutlineInputBorder()),
                ),
                const SizedBox(height: Tk.s3),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: _paste, icon: const Icon(Icons.content_paste_rounded), label: const Text('Paste'))),
                  const SizedBox(width: Tk.s3),
                  Expanded(child: OutlinedButton(onPressed: _check, child: const Text('Check'))),
                ]),
                if (preview != null) ...[
                  const SizedBox(height: Tk.s3),
                  if (preview.error != null)
                    Text(preview.error!, style: TextStyle(color: c.danger, fontSize: 14, height: 1.4))
                  else ...[
                    Text(
                      '${preview.items.length} shortcut${preview.items.length == 1 ? '' : 's'} ready'
                      '${preview.groups.isEmpty ? '' : ' in ${preview.groups.length} categor${preview.groups.length == 1 ? 'y' : 'ies'}'}'
                      '${preview.skipped == 0 ? '' : ' (${preview.skipped} skipped because they were invalid)'}.',
                      style: TextStyle(fontSize: 14, color: c.text),
                    ),
                    const SizedBox(height: Tk.s3),
                    FilledButton(onPressed: _import, child: const Text('Import')),
                  ],
                ],
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
