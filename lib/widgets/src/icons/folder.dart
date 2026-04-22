import 'package:clide/widgets/src/clide_icon.dart';
import 'package:flutter/widgets.dart';

class FolderIcon extends ClideIconPainter {
  const FolderIcon();

  @override
  void paint(Canvas canvas, Color color) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.08;
    final path = Path()
      ..moveTo(0.08, 0.30)
      ..lineTo(0.40, 0.30)
      ..lineTo(0.48, 0.22)
      ..lineTo(0.92, 0.22)
      ..lineTo(0.92, 0.80)
      ..lineTo(0.08, 0.80)
      ..close();
    canvas.drawPath(path, p);
  }
}
