import 'package:clide_app/widgets/src/clide_icon.dart';
import 'package:flutter/widgets.dart';

class CheckIcon extends ClideIconPainter {
  const CheckIcon();

  @override
  void paint(Canvas canvas, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 0.14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(0.18, 0.52)
      ..lineTo(0.42, 0.74)
      ..lineTo(0.82, 0.30);
    canvas.drawPath(path, p);
  }
}
