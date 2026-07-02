/// The interactive `.canvas` view (T-322): lays a [CanvasDoc] out with
/// [CanvasPainter] and wires pan (drag), zoom (scroll wheel), and click-select
/// via [hitTestCanvasNode] so the selection ring lands on what's drawn. Node
/// drag/resize and edit affordances layer on later.
library;

import 'package:clide/builtin/canvas/src/canvas_painter.dart';
import 'package:clide/src/canvas/json_canvas.dart';
import 'package:clide/widgets/src/clide_settings.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

class CanvasView extends StatefulWidget {
  const CanvasView({super.key, required this.doc, this.onSelect});

  final CanvasDoc doc;

  /// Fired with the selected node's id (or null when the click misses).
  final void Function(String? nodeId)? onSelect;

  @override
  State<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends State<CanvasView> {
  static const double _minZoom = 0.2, _maxZoom = 5;

  double _zoom = 1;
  Offset _pan = Offset.zero;
  String? _selected;

  @override
  void didUpdateWidget(CanvasView old) {
    super.didUpdateWidget(old);
    if (!identical(old.doc, widget.doc)) {
      _zoom = 1;
      _pan = Offset.zero;
      _selected = null;
    }
  }

  void _onScroll(PointerScrollEvent e) {
    final factor = e.scrollDelta.dy < 0 ? 1.1 : 0.9;
    final next = (_zoom * factor).clamp(_minZoom, _maxZoom);
    if (next != _zoom) setState(() => _zoom = next);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final size = constraints.biggest;
        return Listener(
          onPointerSignal: (s) {
            if (s is PointerScrollEvent) _onScroll(s);
          },
          child: GestureDetector(
            onTapUp: (d) {
              final hit = hitTestCanvasNode(widget.doc, d.localPosition, size, zoom: _zoom, pan: _pan);
              if (hit != _selected) setState(() => _selected = hit);
              widget.onSelect?.call(hit);
            },
            onPanUpdate: (d) => setState(() => _pan += d.delta),
            child: CustomPaint(
              size: size,
              painter: CanvasPainter(doc: widget.doc, tokens: tokens, zoom: _zoom, pan: _pan, selected: _selected),
            ),
          ),
        );
      },
    );
  }
}
