import 'package:clide_app/widgets/src/clide_icon.dart';
import 'package:flutter/widgets.dart';

class ChevronRightIcon extends ClideIconPainter {
  const ChevronRightIcon();

  @override
  void paint(Canvas canvas, Color color) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(0.36, 0.22)
      ..lineTo(0.66, 0.50)
      ..lineTo(0.36, 0.78);
    canvas.drawPath(path, p);
  }
}

class ChevronDownIcon extends ClideIconPainter {
  const ChevronDownIcon();

  @override
  void paint(Canvas canvas, Color color) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(0.22, 0.36)
      ..lineTo(0.50, 0.66)
      ..lineTo(0.78, 0.36);
    canvas.drawPath(path, p);
  }
}
