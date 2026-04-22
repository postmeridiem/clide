import 'dart:ui';
import 'package:clide_app/widgets/src/clide_icon.dart';

class GitBranchIcon extends ClideIconPainter {
  const GitBranchIcon();

  @override
  void paint(Canvas canvas, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.08
      ..strokeCap = StrokeCap.round;
    // Trunk line
    canvas.drawLine(const Offset(0.35, 0.2), const Offset(0.35, 0.8), paint);
    // Branch line
    canvas.drawLine(const Offset(0.65, 0.3), const Offset(0.65, 0.5), paint);
    canvas.drawLine(const Offset(0.65, 0.5), const Offset(0.35, 0.6), paint);
    // Dots at nodes
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(0.35, 0.2), 0.06, dot);
    canvas.drawCircle(const Offset(0.35, 0.8), 0.06, dot);
    canvas.drawCircle(const Offset(0.65, 0.3), 0.06, dot);
  }
}
