import 'package:clide/kernel/src/window_controls.dart';
import 'package:flutter/widgets.dart';

class ClideResizeBorder extends StatelessWidget {
  const ClideResizeBorder({super.key, required this.windowControls, required this.child});

  final WindowControls windowControls;
  final Widget child;

  static const double _edge = 6;
  static const double _corner = 12;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        // Corners
        _zone(Alignment.topLeft, _corner, _corner, SystemMouseCursors.resizeUpLeft, ResizeEdge.topLeft),
        _zone(Alignment.topRight, _corner, _corner, SystemMouseCursors.resizeUpRight, ResizeEdge.topRight),
        _zone(Alignment.bottomLeft, _corner, _corner, SystemMouseCursors.resizeDownLeft, ResizeEdge.bottomLeft),
        _zone(Alignment.bottomRight, _corner, _corner, SystemMouseCursors.resizeDownRight, ResizeEdge.bottomRight),
        // Edges
        Positioned(top: _corner, bottom: _corner, left: 0, width: _edge, child: _edgeZone(SystemMouseCursors.resizeLeft, ResizeEdge.left)),
        Positioned(top: _corner, bottom: _corner, right: 0, width: _edge, child: _edgeZone(SystemMouseCursors.resizeRight, ResizeEdge.right)),
        Positioned(left: _corner, right: _corner, top: 0, height: _edge, child: _edgeZone(SystemMouseCursors.resizeUp, ResizeEdge.top)),
        Positioned(left: _corner, right: _corner, bottom: 0, height: _edge, child: _edgeZone(SystemMouseCursors.resizeDown, ResizeEdge.bottom)),
      ],
    );
  }

  Widget _zone(Alignment alignment, double w, double h, MouseCursor cursor, ResizeEdge edge) {
    return Positioned(
      left: alignment.x < 0 ? 0 : null,
      right: alignment.x > 0 ? 0 : null,
      top: alignment.y < 0 ? 0 : null,
      bottom: alignment.y > 0 ? 0 : null,
      width: w,
      height: h,
      child: _edgeZone(cursor, edge),
    );
  }

  Widget _edgeZone(MouseCursor cursor, ResizeEdge edge) {
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        onPanStart: (d) => windowControls.startResize(edge, d.globalPosition),
        child: const ColoredBox(color: Color(0x00000000)),
      ),
    );
  }
}
