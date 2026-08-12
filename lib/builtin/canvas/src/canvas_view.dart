/// The interactive `.canvas` view (T-322): lays a [CanvasDoc] out with
/// [CanvasPainter] and wires pan (drag on empty space), zoom (scroll wheel),
/// click-select via [hitTestCanvasNode], and editing — drag a node to move
/// it, drag a corner handle to resize it.
///
/// The view owns the working document. [onChanged] fires once per completed
/// gesture, not per frame, so a drag repaints freely but persists once.
library;

import 'dart:math' as math;

import 'package:clide/builtin/canvas/src/canvas_painter.dart';
import 'package:clide/builtin/canvas/src/canvas_toolbar.dart';
import 'package:clide/src/canvas/json_canvas.dart';
import 'package:clide/widgets/src/clide_settings.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// What the in-flight drag is doing.
enum _Grab { pan, move, resize, connect, toolbar }

class CanvasView extends StatefulWidget {
  const CanvasView({super.key, required this.doc, this.onSelect, this.onChanged, this.editable = true});

  final CanvasDoc doc;

  /// Fired with the selected node's id (or null when the click misses).
  final void Function(String? nodeId)? onSelect;

  /// Fired with the edited document at the END of a move/resize gesture.
  /// Null (or `editable: false`) leaves the view read-only.
  final void Function(CanvasDoc doc)? onChanged;

  /// Whether node move/resize is offered at all.
  final bool editable;

  @override
  State<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends State<CanvasView> {
  static const double _minZoom = 0.2, _maxZoom = 5;

  /// Floor on a resized node, in canvas units — a zero-size node is
  /// unselectable afterwards, so there'd be no way to undo the resize.
  static const double _minNodeSize = 20;

  late CanvasDoc _doc;

  /// Content bounds frozen when the document is adopted. Re-deriving them
  /// per paint would re-fit the viewport as a node moves, sliding the whole
  /// canvas under the cursor mid-drag.
  late CanvasBounds _bounds;

  double _zoom = 1;
  Offset _pan = Offset.zero;
  String? _selected;

  /// The last doc handed to [CanvasView.onChanged] — so the echo back
  /// through `widget.doc` isn't mistaken for a new document to reset to.
  CanvasDoc? _emitted;

  _Grab _grab = _Grab.pan;
  CanvasCorner? _corner;

  /// The connection being dragged out of an edge handle, or null.
  CanvasConnection? _connection;

  /// Toolbar position, pane-local. Reset with the document by design — see
  /// [CanvasToolbar]; only clamped so a pane resize can't strand it.
  Offset _toolbarPos = const Offset(canvasToolbarInset, canvasToolbarInset);

  /// The dragged node as it was at gesture start, plus the pixel delta
  /// accumulated since. Deriving each frame from the start (rather than
  /// nudging the live node) keeps the min-size clamp from sticking when a
  /// resize is dragged past the floor and back.
  CanvasNode? _grabStart;
  Offset _grabDelta = Offset.zero;

  bool get _editable => widget.editable && widget.onChanged != null;

  @override
  void initState() {
    super.initState();
    _adopt(widget.doc);
  }

  void _adopt(CanvasDoc doc) {
    _doc = doc;
    _bounds = CanvasBounds.of(doc);
    _zoom = 1;
    _pan = Offset.zero;
    _selected = null;
    _toolbarPos = const Offset(canvasToolbarInset, canvasToolbarInset);
  }

  /// Default size of a node created from the toolbar, in canvas units —
  /// Obsidian's own default for a new text card.
  static const double _newNodeWidth = 250, _newNodeHeight = 60;

  /// Add a text node at the middle of what the user is currently looking at,
  /// not at the document origin, which may be off-screen.
  void _addTextNode(Size size) {
    final vp = _viewport(size);
    if (vp.scale <= 0) return;
    final centreX = (size.width / 2 - vp.dx) / vp.scale;
    final centreY = (size.height / 2 - vp.dy) / vp.scale;
    final node = TextNode(id: _doc.freshId(), x: centreX - _newNodeWidth / 2, y: centreY - _newNodeHeight / 2, width: _newNodeWidth, height: _newNodeHeight);
    setState(() {
      _doc = _doc.addNode(node);
      _selected = node.id;
    });
    widget.onSelect?.call(node.id);
    _emit();
  }

  void _deleteSelected() {
    final id = _selected;
    if (id == null) return;
    final next = _doc.removeNode(id);
    if (identical(next, _doc)) return;
    setState(() {
      _doc = next;
      _selected = null;
    });
    widget.onSelect?.call(null);
    _emit();
  }

  @override
  void didUpdateWidget(CanvasView old) {
    super.didUpdateWidget(old);
    if (identical(old.doc, widget.doc)) return;
    // Our own edit arriving back from the parent — keep zoom/pan/selection.
    if (identical(widget.doc, _emitted)) {
      _doc = widget.doc;
      return;
    }
    setState(() => _adopt(widget.doc));
  }

  CanvasViewport _viewport(Size size) => CanvasViewport.fit(size, _bounds, zoom: _zoom, pan: _pan);

  void _onScroll(PointerScrollEvent e) {
    final factor = e.scrollDelta.dy < 0 ? 1.1 : 0.9;
    final next = (_zoom * factor).clamp(_minZoom, _maxZoom);
    if (next != _zoom) setState(() => _zoom = next);
  }

  void _onTapUp(TapUpDetails d, Size size) {
    final hit = hitTestCanvasNode(_doc, d.localPosition, size, bounds: _bounds, zoom: _zoom, pan: _pan);
    if (hit != _selected) setState(() => _selected = hit);
    widget.onSelect?.call(hit);
  }

  void _onPanStart(DragStartDetails d, Size size) {
    _grabDelta = Offset.zero;
    if (!_editable) {
      _grab = _Grab.pan;
      return;
    }
    // The toolbar floats above everything, so its grip is tested first.
    if (canvasToolbarGripRect(_clampedToolbarPos(size)).contains(d.localPosition)) {
      _grab = _Grab.toolbar;
      _grabStart = null;
      return;
    }
    final vp = _viewport(size);

    // A handle on the selected node wins over the node under the cursor —
    // the handles overhang the node's own rect.
    final sel = _selected == null ? null : _doc.node(_selected!);
    if (sel != null) {
      final rect = vp.rectOf(sel);
      // Corners before edges: on a small node the two sets can overlap, and
      // resize is the more common intent.
      final corner = canvasHandleAt(rect, d.localPosition);
      if (corner != null) {
        _grab = _Grab.resize;
        _corner = corner;
        _grabStart = sel;
        return;
      }
      final side = canvasEdgeHandleAt(rect, d.localPosition);
      if (side != null) {
        _grab = _Grab.connect;
        _grabStart = sel;
        setState(() => _connection = CanvasConnection(fromNode: sel.id, fromSide: side, to: d.localPosition));
        return;
      }
    }

    final hit = hitTestCanvasNode(_doc, d.localPosition, size, bounds: _bounds, zoom: _zoom, pan: _pan);
    if (hit != null) {
      _grab = _Grab.move;
      _corner = null;
      _grabStart = _doc.node(hit);
      // Dragging an unselected node selects it, so the handles follow.
      if (hit != _selected) {
        setState(() => _selected = hit);
        widget.onSelect?.call(hit);
      }
      return;
    }

    _grab = _Grab.pan;
    _grabStart = null;
  }

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    if (_grab == _Grab.toolbar) {
      setState(() => _toolbarPos = clampCanvasToolbar(_clampedToolbarPos(size) + d.delta, size, _actionCount));
      return;
    }
    if (_grab == _Grab.pan) {
      setState(() => _pan += d.delta);
      return;
    }
    final start = _grabStart;
    if (start == null) return;
    _grabDelta += d.delta;
    if (_grab == _Grab.connect) {
      final live = _connection;
      if (live != null) {
        setState(() => _connection = CanvasConnection(fromNode: live.fromNode, fromSide: live.fromSide, to: d.localPosition));
      }
      return;
    }
    final scale = _viewport(size).scale;
    if (scale <= 0) return;
    final dx = _grabDelta.dx / scale, dy = _grabDelta.dy / scale;
    final edited = _grab == _Grab.move ? start.withRect(x: start.x + dx, y: start.y + dy) : _resized(start, _corner!, dx, dy);
    setState(() => _doc = _doc.replaceNode(edited));
  }

  void _onPanEnd(DragEndDetails d, Size size) {
    final grab = _grab;
    final started = _grabStart;
    final dragged = _grabDelta != Offset.zero;
    final live = _connection;
    _grabStart = null;
    _corner = null;
    _grabDelta = Offset.zero;
    if (live != null) setState(() => _connection = null);

    if (grab == _Grab.connect) {
      if (live == null || started == null || !dragged) return;
      // Released over a node? Connect to it. Released over empty space, or
      // back on the source, is a cancelled gesture — not an edge.
      final target = hitTestCanvasNode(_doc, live.to, size, bounds: _bounds, zoom: _zoom, pan: _pan);
      if (target == null || target == live.fromNode) return;
      final edge = CanvasEdge(id: _doc.freshId(), fromNode: live.fromNode, toNode: target, fromSide: live.fromSide);
      final next = _doc.addEdge(edge);
      if (identical(next, _doc)) return; // duplicate connection — nothing to save
      setState(() => _doc = next);
      _emit();
      return;
    }

    if (grab == _Grab.pan || grab == _Grab.toolbar || started == null || !dragged) return;
    _emit();
  }

  /// Toolbar actions, built here so the count is available to the hit test
  /// (the toolbar's height depends on it) as well as to [build].
  List<CanvasToolbarAction> _actions(BuildContext context, Size size) => [
    CanvasToolbarAction(
      glyph: 'text-t',
      label: ClideSettings.i18n.string(context, 'action.addText', namespace: 'builtin.canvas', placeholder: 'Add text node'),
      onPressed: () => _addTextNode(size),
    ),
    CanvasToolbarAction(
      glyph: 'trash',
      label: ClideSettings.i18n.string(context, 'action.delete', namespace: 'builtin.canvas', placeholder: 'Delete selected node'),
      onPressed: _selected == null ? null : _deleteSelected,
    ),
  ];

  static const int _actionCount = 2;

  /// [_toolbarPos] pulled back inside the pane — recomputed rather than
  /// stored, so a pane resize can't strand the toolbar out of reach.
  Offset _clampedToolbarPos(Size size) => clampCanvasToolbar(_toolbarPos, size, _actionCount);

  void _emit() {
    _emitted = _doc;
    widget.onChanged?.call(_doc);
  }

  /// [start] resized by dragging [corner] a canvas-space ([dx], [dy]). The
  /// dragged edges move; the opposite ones stay put. Each edge stops at
  /// [_minNodeSize] from its opposite rather than crossing it.
  CanvasNode _resized(CanvasNode start, CanvasCorner corner, double dx, double dy) {
    var left = start.x, top = start.y;
    var right = start.x + start.width, bottom = start.y + start.height;
    final west = corner == CanvasCorner.topLeft || corner == CanvasCorner.bottomLeft;
    final north = corner == CanvasCorner.topLeft || corner == CanvasCorner.topRight;

    if (west) {
      left = math.min(left + dx, right - _minNodeSize);
    } else {
      right = math.max(right + dx, left + _minNodeSize);
    }
    if (north) {
      top = math.min(top + dy, bottom - _minNodeSize);
    } else {
      bottom = math.max(bottom + dy, top + _minNodeSize);
    }
    return start.withRect(x: left, y: top, width: right - left, height: bottom - top);
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
            // `down`, not the default `start`: `start` drops the movement
            // that crossed the touch slop, so a dragged node would trail
            // the cursor by that distance for the rest of the gesture —
            // visible as soon as you resize by a corner handle.
            dragStartBehavior: DragStartBehavior.down,
            onTapUp: (d) => _onTapUp(d, size),
            onPanStart: (d) => _onPanStart(d, size),
            onPanUpdate: (d) => _onPanUpdate(d, size),
            onPanEnd: (d) => _onPanEnd(d, size),
            child: Stack(
              children: [
                CustomPaint(
                  size: size,
                  painter: CanvasPainter(
                    doc: _doc,
                    tokens: tokens,
                    bounds: _bounds,
                    zoom: _zoom,
                    pan: _pan,
                    selected: _selected,
                    showHandles: _editable,
                    connection: _connection,
                  ),
                ),
                if (_editable) _toolbar(context, size),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _toolbar(BuildContext context, Size size) {
    final pos = _clampedToolbarPos(size);
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: CanvasToolbar(actions: _actions(context, size)),
    );
  }
}
