import 'dart:math' as math;

import 'package:clide_app/widgets/src/clide_icon.dart';
import 'package:flutter/widgets.dart';

class GearIcon extends ClideIconPainter {
  const GearIcon();

  @override
  void paint(Canvas canvas, Color color) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.08
      ..strokeCap = StrokeCap.round;
    const center = Offset(0.5, 0.5);
    const teeth = 8;
    const innerR = 0.25;
    const outerR = 0.40;

    final path = Path();
    for (var i = 0; i < teeth; i++) {
      final a1 = (i / teeth) * 2 * math.pi;
      final a2 = ((i + 0.5) / teeth) * 2 * math.pi;
      final p1 = center + Offset(math.cos(a1) * innerR, math.sin(a1) * innerR);
      final p2 = center + Offset(math.cos(a1) * outerR, math.sin(a1) * outerR);
      final p3 = center + Offset(math.cos(a2) * outerR, math.sin(a2) * outerR);
      final p4 = center + Offset(math.cos(a2) * innerR, math.sin(a2) * innerR);
      path
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..lineTo(p4.dx, p4.dy);
    }
    canvas.drawPath(path, p);
    canvas.drawCircle(center, 0.12, p);
  }
}
