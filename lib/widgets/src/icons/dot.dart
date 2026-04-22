import 'package:clide/widgets/src/clide_icon.dart';
import 'package:flutter/widgets.dart';

class DotIcon extends ClideIconPainter {
  const DotIcon();

  @override
  void paint(Canvas canvas, Color color) {
    canvas.drawCircle(const Offset(0.5, 0.5), 0.18, Paint()..color = color);
  }
}
