import 'package:clide/widgets/src/clide_icon.dart';
import 'package:flutter/widgets.dart';

/// Plug-shaped connection icon. Used by the ipc-status statusbar item
/// and by future connection-state affordances.
class PlugIcon extends ClideIconPainter {
  const PlugIcon();

  @override
  void paint(Canvas canvas, Color color) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.10
      ..strokeCap = StrokeCap.round;
    // body
    final body = Path()
      ..moveTo(0.30, 0.30)
      ..lineTo(0.60, 0.30)
      ..lineTo(0.60, 0.55)
      ..arcToPoint(const Offset(0.30, 0.55), radius: const Radius.circular(0.15), clockwise: false)
      ..close();
    canvas.drawPath(body, p);
    // cord
    canvas.drawLine(const Offset(0.45, 0.60), const Offset(0.45, 0.88), p);
    // prongs
    canvas.drawLine(const Offset(0.38, 0.18), const Offset(0.38, 0.30), p);
    canvas.drawLine(const Offset(0.52, 0.18), const Offset(0.52, 0.30), p);
  }
}
