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
    this.thickness = DragResizeHandle.defaultThickness,
  });

  final LayoutArrangement arrangement;
  final SlotId slot;
  final Axis axis;
  final double thickness;

  static const defaultThickness = 8.0;

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
    final lineColor = _hovered ? tokens.panelActiveBorder : tokens.dividerColor;

    return MouseRegion(
      cursor: widget.axis == Axis.horizontal ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onUp,
        child: Container(
          width: widget.axis == Axis.horizontal ? widget.thickness : null,
          height: widget.axis == Axis.vertical ? widget.thickness : null,
          color: tokens.chromeBackground,
          child: Align(
            alignment: widget.slot == Slots.sidebar ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: widget.axis == Axis.horizontal ? 1 : null,
              height: widget.axis == Axis.vertical ? 1 : null,
              color: lineColor,
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
    final rawDelta = widget.axis == Axis.horizontal ? e.position.dx - startPt.dx : e.position.dy - startPt.dy;
    final delta = widget.slot == Slots.contextPanel ? -rawDelta : rawDelta;
    widget.arrangement.setSize(widget.slot, start + delta);
  }

  void _onUp(PointerUpEvent _) {
    _dragStartSize = null;
    _dragStartPointer = null;
  }
}
