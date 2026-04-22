import 'dart:ui';
import 'package:clide_app/widgets/src/clide_icon.dart';

class WarningIcon extends ClideIconPainter {
  const WarningIcon();

  @override
  void paint(Canvas canvas, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(0.5, 0.15)
      ..lineTo(0.85, 0.8)
      ..lineTo(0.15, 0.8)
      ..close();
    canvas.drawPath(path, paint);
    // Exclamation
    canvas.drawLine(const Offset(0.5, 0.4), const Offset(0.5, 0.58), paint);
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(0.5, 0.68), 0.035, dot);
  }
}
