import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A trackpad-proportioned slab. The pointer traces one stroke when the screen opens, then rests.
class TrackpadHero extends StatelessWidget {
  const TrackpadHero({super.key});

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AspectRatio(
      aspectRatio: 1.35,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: c.outline),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 2200),
            curve: Curves.easeInOutCubic,
            builder: (_, t, __) => CustomPaint(painter: _TracePainter(t, c), size: Size.infinite),
          ),
        ),
      ),
    );
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter(this.t, this.c);
  final double t;
  final MtColors c;

  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()
      ..moveTo(s.width * 0.14, s.height * 0.72)
      ..cubicTo(s.width * 0.28, s.height * 0.18, s.width * 0.46, s.height * 0.98, s.width * 0.62, s.height * 0.46)
      ..cubicTo(s.width * 0.70, s.height * 0.22, s.width * 0.80, s.height * 0.30, s.width * 0.86, s.height * 0.34);
    final PathMetric metric = path.computeMetrics().first;
    final length = metric.length * t;

    final trail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = c.accent.withValues(alpha: 0.5);
    canvas.drawPath(metric.extractPath(0, length), trail);

    final tangent = metric.getTangentForOffset(length);
    if (tangent == null) return;
    canvas.drawCircle(tangent.position, 22, Paint()..color = c.accent.withValues(alpha: 0.16));
    canvas.drawCircle(tangent.position, 9, Paint()..color = c.accent);
  }

  @override
  bool shouldRepaint(_TracePainter old) => old.t != t || old.c != c;
}
