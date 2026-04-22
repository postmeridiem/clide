import 'dart:ui';
import 'package:clide/widgets/src/clide_icon.dart';

class SearchIcon extends ClideIconPainter {
  const SearchIcon();

  @override
  void paint(Canvas canvas, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(0.42, 0.42), 0.22, paint);
    canvas.drawLine(const Offset(0.58, 0.58), const Offset(0.78, 0.78), paint);
  }
}
