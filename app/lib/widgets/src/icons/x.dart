import 'package:clide_app/widgets/src/clide_icon.dart';
import 'package:flutter/widgets.dart';

class CloseIcon extends ClideIconPainter {
  const CloseIcon();

  @override
  void paint(Canvas canvas, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 0.10
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(const Offset(0.22, 0.22), const Offset(0.78, 0.78), p)
      ..drawLine(const Offset(0.78, 0.22), const Offset(0.22, 0.78), p);
  }
}
