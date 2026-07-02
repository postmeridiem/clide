/// The interactive vault-graph view (T-323): lays a [VaultGraph] out with the
/// force solver, paints it via [GraphPainter], and wires hover (highlight the
/// neighbourhood) + click (open the note). Pan/zoom + filtering layer on later.
library;

import 'package:clide/builtin/graph/src/graph_painter.dart';
import 'package:clide/src/graph/force_layout.dart';
import 'package:clide/src/graph/vault_graph.dart';
import 'package:clide/widgets/src/clide_settings.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

class GraphView extends StatefulWidget {
  const GraphView({super.key, required this.graph, this.onOpen, this.layoutSize = const Size(800, 600)});

  final VaultGraph graph;

  /// Called with a node's id (its vault-relative path) when it's clicked.
  final void Function(String nodeId)? onOpen;

  final Size layoutSize;

  @override
  State<GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<GraphView> {
  static const double _minZoom = 0.2, _maxZoom = 5;

  late Map<String, GraphPoint> _pos;
  String? _hovered;
  double _zoom = 1;
  Offset _pan = Offset.zero;

  @override
  void initState() {
    super.initState();
    _relayout();
  }

  @override
  void didUpdateWidget(GraphView old) {
    super.didUpdateWidget(old);
    if (!identical(old.graph, widget.graph)) _relayout();
  }

  void _relayout() {
    _pos = ForceLayout.compute(
      [for (final n in widget.graph.nodes) n.id],
      widget.graph.edgePairs,
      width: widget.layoutSize.width,
      height: widget.layoutSize.height,
    );
    _hovered = null;
    // A fresh graph re-fits; drop any user pan/zoom.
    _zoom = 1;
    _pan = Offset.zero;
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
        String? hit(Offset local) => hitTestNode(widget.graph, _pos, local, size, layoutSize: widget.layoutSize, zoom: _zoom, pan: _pan);
        return Listener(
          onPointerSignal: (s) {
            if (s is PointerScrollEvent) _onScroll(s);
          },
          child: MouseRegion(
            onHover: (e) {
              final h = hit(e.localPosition);
              if (h != _hovered) setState(() => _hovered = h);
            },
            onExit: (_) {
              if (_hovered != null) setState(() => _hovered = null);
            },
            child: GestureDetector(
              onTapUp: (d) {
                final h = hit(d.localPosition);
                if (h != null) widget.onOpen?.call(h);
              },
              onPanUpdate: (d) => setState(() => _pan += d.delta),
              child: CustomPaint(
                size: size,
                painter: GraphPainter(
                  graph: widget.graph,
                  positions: _pos,
                  tokens: tokens,
                  highlight: _hovered == null ? null : widget.graph.neighborhood(_hovered!),
                  layoutSize: widget.layoutSize,
                  zoom: _zoom,
                  pan: _pan,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
