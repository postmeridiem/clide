import 'package:clide/kernel/src/theme/controller.dart';
import 'package:flutter/widgets.dart';

/// Stateless painter producing a single-color icon. Every icon in
/// [icons/] subclasses this; widgets wrap with [ClideIcon] for size +
/// color-from-theme.
abstract class ClideIconPainter {
  const ClideIconPainter();

  /// Paint the icon into a unit square (0,0 .. 1,1).
  void paint(Canvas canvas, Color color);
}

class ClideIcon extends StatelessWidget {
  const ClideIcon(
    this.painter, {
    super.key,
    this.size = 14,
    this.color,
  });

  final ClideIconPainter painter;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? ClideTheme.of(context).surface.globalForeground;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _IconPainterAdapter(painter: painter, color: resolved),
      ),
    );
  }
}

class _IconPainterAdapter extends CustomPainter {
  _IconPainterAdapter({required this.painter, required this.color});

  final ClideIconPainter painter;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width, size.height);
    painter.paint(canvas, color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IconPainterAdapter old) => old.painter != painter || old.color != color;
}
