import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/theme_controller.dart';
import '../../core/theme/app_theme.dart';

/// Standard screen frame: safe area, generous padding, optional wordmark row with the theme toggle.
class MtScaffold extends StatelessWidget {
  const MtScaffold({super.key, required this.child, this.showHeader = true, this.leading});
  final Widget child;
  final bool showHeader;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final theme = Get.find<ThemeController>();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showHeader)
                Row(
                  children: [
                    if (leading != null) leading!,
                    Text('MacTouch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: c.text)),
                    const Spacer(),
                    Obx(() => IconButton(
                          tooltip: theme.label,
                          onPressed: theme.cycle,
                          icon: Icon(theme.icon, color: c.textDim),
                        )),
                  ],
                ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class MtCard extends StatelessWidget {
  const MtCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.outline),
      ),
      child: child,
    );
  }
}

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
