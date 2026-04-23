import 'package:clide/kernel/src/panels/arrangement.dart';
import 'package:clide/kernel/src/panels/slot_id.dart';
import 'package:clide/kernel/src/theme/controller.dart';
import 'package:flutter/widgets.dart';

/// A 4-px draggable splitter that adjusts the size of [slot] in the
/// given [arrangement]. Slot hosts wrap this around their edges to make
/// the three-column layout resizable.
class DragResizeHandle extends StatefulWidget {
  const DragResizeHandle({
    super.key,
    required this.arrangement,
    required this.slot,
    required this.axis,
    this.thickness = 4.0,
  });

  final LayoutArrangement arrangement;
  final SlotId slot;
  final Axis axis;
  final double thickness;

  @override
  State<DragResizeHandle> createState() => _DragResizeHandleState();
}

class _DragResizeHandleState extends State<DragResizeHandle> {
  bool _hovered = false;
  double? _dragStartSize;
  Offset? _dragStartPointer;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final color = _hovered ? tokens.panelActiveBorder : tokens.panelBorder;

    return MouseRegion(
      cursor: widget.axis == Axis.horizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onUp,
        child: SizedBox(
          width: widget.axis == Axis.horizontal ? widget.thickness : null,
          height: widget.axis == Axis.vertical ? widget.thickness : null,
          child: Center(
            child: Container(
              width: widget.axis == Axis.horizontal ? 1 : null,
              height: widget.axis == Axis.vertical ? 1 : null,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  void _onDown(PointerDownEvent e) {
    _dragStartSize = widget.arrangement.sizeOf(widget.slot);
    _dragStartPointer = e.position;
  }

  void _onMove(PointerMoveEvent e) {
    final start = _dragStartSize;
    final startPt = _dragStartPointer;
    if (start == null || startPt == null) return;
    final delta = widget.axis == Axis.horizontal
        ? e.position.dx - startPt.dx
        : e.position.dy - startPt.dy;
    widget.arrangement.setSize(widget.slot, start + delta);
  }

  void _onUp(PointerUpEvent _) {
    _dragStartSize = null;
    _dragStartPointer = null;
  }
}
