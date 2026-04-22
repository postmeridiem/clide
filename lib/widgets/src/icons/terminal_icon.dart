import 'dart:ui';
import 'package:clide/widgets/src/clide_icon.dart';

class TerminalIcon extends ClideIconPainter {
  const TerminalIcon();

  @override
  void paint(Canvas canvas, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.08
      ..strokeCap = StrokeCap.round;
    // Prompt chevron >_
    canvas.drawLine(const Offset(0.2, 0.3), const Offset(0.45, 0.5), paint);
    canvas.drawLine(const Offset(0.45, 0.5), const Offset(0.2, 0.7), paint);
    // Cursor line
    canvas.drawLine(const Offset(0.5, 0.7), const Offset(0.8, 0.7), paint);
  }
}
