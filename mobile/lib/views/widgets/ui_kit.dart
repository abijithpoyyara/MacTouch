import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/haptics.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// Standard screen: safe area, back button, title, optional actions, and a readable column that is centered on wide
/// screens and in landscape.
class ScreenFrame extends StatelessWidget {
  const ScreenFrame({super.key, required this.title, required this.children, this.actions = const [], this.bottom, this.padding});
  final String title;
  final List<Widget> children;
  final List<Widget> actions;
  /// Pinned below the scrolling content (for example a primary button).
  final Widget? bottom;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Tk.maxContentWidth),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Tk.s2, Tk.s1, Tk.s2, 0),
                  child: Row(children: [
                    if (Navigator.of(context).canPop())
                      IconButton(tooltip: 'Back', onPressed: () => Get.back<void>(), icon: Icon(Icons.arrow_back_rounded, color: c.text))
                    else
                      const SizedBox(width: Tk.s4),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: c.text)),
                      ),
                    ),
                    ...actions,
                  ]),
                ),
                Expanded(
                  child: ListView(
                    padding: padding ?? const EdgeInsets.fromLTRB(Tk.s5, Tk.s3, Tk.s5, Tk.s8),
                    children: children,
                  ),
                ),
                if (bottom != null) Padding(padding: const EdgeInsets.fromLTRB(Tk.s5, Tk.s2, Tk.s5, Tk.s4), child: bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tk.s1, Tk.s6, 0, Tk.s2),
      child: Semantics(
        header: true,
        child: Text(text.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: c.textDim)),
      ),
    );
  }
}

/// Rounded card. Pass [gradient] for the one hero card on a screen.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(Tk.s4), this.gradient});
  final Widget child;
  final EdgeInsets padding;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? c.surface : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(Tk.rLg),
        border: Border.all(color: c.outline),
      ),
      child: child,
    );
  }
}

/// Several rows in one card, separated by hairlines.
class RowGroup extends StatelessWidget {
  const RowGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return Container(
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Tk.rLg), border: Border.all(color: c.outline)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, indent: Tk.s4, color: c.outline),
          children[i],
        ],
      ]),
    );
  }
}

class NavRow extends StatelessWidget {
  const NavRow({super.key, required this.icon, required this.title, this.subtitle, this.onTap, this.trailing});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return Semantics(
      button: onTap != null,
      label: subtitle == null ? title : '$title, $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                Haptics.tap();
                onTap!();
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Tk.touchTarget + 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tk.s4, vertical: Tk.s3),
            child: Row(children: [
              Icon(icon, color: c.accent),
              const SizedBox(width: Tk.s3),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
                  if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 13, height: 1.3, color: c.textDim)),
                ]),
              ),
              if (trailing != null) trailing! else if (onTap != null) Icon(Icons.chevron_right_rounded, color: c.textDim),
            ]),
          ),
        ),
      ),
    );
  }
}

class SwitchRow extends StatelessWidget {
  const SwitchRow({super.key, required this.title, this.subtitle, required this.value, required this.onChanged});
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Tk.touchTarget + 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Tk.s4, Tk.s2, Tk.s3, Tk.s2),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
                if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 13, height: 1.3, color: c.textDim)),
              ]),
            ),
            Switch(
              value: value,
              onChanged: (v) {
                Haptics.tap();
                onChanged(v);
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class SliderRow extends StatelessWidget {
  const SliderRow({
    super.key, required this.label, required this.value, required this.min, required this.max,
    required this.format, required this.onChanged, this.onEnd, this.hint,
  });
  final String label;
  final double value, min, max;
  final String Function(double) format;
  final ValueChanged<double> onChanged;
  final VoidCallback? onEnd;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tk.s4, Tk.s3, Tk.s3, Tk.s1),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text))),
          Text(format(value), style: TextStyle(fontSize: 14, color: c.textDim)),
        ]),
        if (hint != null) Text(hint!, style: TextStyle(fontSize: 13, height: 1.3, color: c.textDim)),
        Semantics(
          label: label,
          value: format(value),
          child: Slider(value: value.clamp(min, max).toDouble(), min: min, max: max, onChanged: onChanged, onChangeEnd: onEnd == null ? null : (_) => onEnd!()),
        ),
      ]),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Tk.s3, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}

/// A row of mutually exclusive choices (theme mode, orientation).
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({super.key, required this.label, required this.value, required this.options, required this.onChanged});
  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(Tk.s4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
        const SizedBox(height: Tk.s3),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<T>(
            showSelectedIcon: false,
            segments: [for (final e in options.entries) ButtonSegment<T>(value: e.key, label: Text(e.value))],
            selected: {value},
            onSelectionChanged: (s) {
              Haptics.tap();
              onChanged(s.first);
            },
          ),
        ),
      ]),
    );
  }
}

Future<bool> confirmDialog(BuildContext context, {required String title, required String message, required String confirm, bool destructive = false}) async {
  final c = MtColors.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tk.rXl)),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(confirm, style: TextStyle(color: destructive ? c.danger : null))),
      ],
    ),
  );
  return ok == true;
}
