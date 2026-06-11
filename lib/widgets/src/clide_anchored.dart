/// Anchored-overlay positioning + lifecycle primitive (D-88).
///
/// Every clide popover surface — menu-bar dropdowns, the theme picker, the
/// permission-mode picker, the slash / @ typeaheads, quick-open — used to
/// re-derive the same four things: a [LayerLink] + [CompositedTransformFollower]
/// (or a hand-rolled `Positioned`), a full-screen tap-away barrier, the
/// `Overlay.insert` / `OverlayEntry` bookkeeping, and post-frame focus capture.
/// This widget owns all of it; callers supply the trigger ([anchor]) and the
/// floating content ([overlayBuilder]). Modal, centred dialogs stay on the
/// kernel `DialogRouter` — this is for anchored, non-modal popovers.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Primary placement of the floating panel relative to the [anchor].
enum ClideAnchorSide { below, above, left, right }

/// Cross-axis alignment of the panel's edge to the anchor's edge.
enum ClideAnchorAlign { start, center, end }

/// Open/close state for a [ClideAnchoredOverlay]. A plain [ChangeNotifier] so
/// it composes with `ListenableBuilder` and outside controllers (e.g. the menu
/// bar's single-open coordinator drives one of these per top-level button).
class ClideOverlayController extends ChangeNotifier {
  bool _open = false;
  bool get isOpen => _open;

  void open() {
    if (_open) return;
    _open = true;
    notifyListeners();
  }

  void close() {
    if (!_open) return;
    _open = false;
    notifyListeners();
  }

  void toggle() => _open ? close() : open();
}

/// Wraps [anchor] with a [CompositedTransformTarget] and, while [controller] is
/// open, inserts an [OverlayEntry] built from [overlayBuilder], positioned
/// relative to the anchor (or centred when [centered]).
class ClideAnchoredOverlay extends StatefulWidget {
  const ClideAnchoredOverlay({
    super.key,
    required this.controller,
    required this.anchor,
    required this.overlayBuilder,
    this.side = ClideAnchorSide.below,
    this.align = ClideAnchorAlign.start,
    this.offset = const Offset(0, 2),
    this.autoFlip = true,
    this.barrier = true,
    this.dismissOnEscape = true,
    this.captureFocus = true,
    this.rootOverlay = false,
    this.centered = false,
    this.onOpened,
    this.onClosed,
  });

  final ClideOverlayController controller;

  /// The trigger widget. Wrapped in a [CompositedTransformTarget].
  final Widget anchor;

  /// Builds the floating content. Receives the [controller] so rows can close
  /// the overlay on activation.
  final Widget Function(BuildContext context, ClideOverlayController controller) overlayBuilder;

  final ClideAnchorSide side;
  final ClideAnchorAlign align;

  /// Follower offset for the requested [side]. On an [autoFlip] vertical flip
  /// the dy is negated so the gap stays on the correct edge.
  final Offset offset;

  /// Flip [side] to its opposite when the anchor sits in the far edge of the
  /// viewport (e.g. a status-bar control at the window bottom opens upward).
  final bool autoFlip;

  /// Insert a full-screen tap-away barrier behind the panel.
  final bool barrier;

  /// Close on Escape (as a fallback; menu content may handle Esc first).
  final bool dismissOnEscape;

  /// Request focus into the panel on open.
  final bool captureFocus;

  /// Insert into the root overlay (menu bar needs this to clear pane chrome).
  final bool rootOverlay;

  /// Ignore the anchor; render the panel centred horizontally at [offset].dy
  /// from the top (the command-palette / quick-open shape).
  final bool centered;

  final VoidCallback? onOpened;
  final VoidCallback? onClosed;

  @override
  State<ClideAnchoredOverlay> createState() => _ClideAnchoredOverlayState();
}

class _ClideAnchoredOverlayState extends State<ClideAnchoredOverlay> {
  final LayerLink _link = LayerLink();
  final FocusScopeNode _scope = FocusScopeNode(debugLabel: 'clide-anchored');
  OverlayEntry? _entry;
  ClideAnchorSide _resolvedSide = ClideAnchorSide.below;

  @override
  void initState() {
    super.initState();
    _resolvedSide = widget.side;
    widget.controller.addListener(_sync);
  }

  @override
  void didUpdateWidget(ClideAnchoredOverlay old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller)) {
      old.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _entry?.remove();
    _entry = null;
    _scope.dispose();
    super.dispose();
  }

  void _sync() {
    if (widget.controller.isOpen && _entry == null) {
      _resolvedSide = _computeSide();
      _entry = OverlayEntry(builder: _buildEntry);
      Overlay.of(context, rootOverlay: widget.rootOverlay).insert(_entry!);
      if (widget.captureFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _entry != null) _scope.requestFocus();
        });
      }
      widget.onOpened?.call();
    } else if (!widget.controller.isOpen && _entry != null) {
      _entry!.remove();
      _entry = null;
      widget.onClosed?.call();
    }
  }

  /// Resolve [ClideAnchorSide] honouring [autoFlip]: a vertical side flips when
  /// the anchor is past 60% (below) / before 40% (above) of the viewport.
  ClideAnchorSide _computeSide() {
    var side = widget.side;
    if (!widget.autoFlip || widget.centered) return side;
    final box = context.findRenderObject();
    // Use the real view size, not MediaQuery — the latter can be overridden to
    // zero (e.g. the shared test harness), which would defeat the flip.
    final view = View.maybeOf(context);
    if (box is RenderBox && box.hasSize && view != null) {
      final rect = box.localToGlobal(Offset.zero) & box.size;
      final h = view.physicalSize.height / view.devicePixelRatio;
      if (h > 0) {
        if (side == ClideAnchorSide.below && rect.bottom > h * 0.6) {
          side = ClideAnchorSide.above;
        } else if (side == ClideAnchorSide.above && rect.top < h * 0.4) {
          side = ClideAnchorSide.below;
        }
      }
    }
    return side;
  }

  (Alignment target, Alignment follower) _alignments(ClideAnchorSide side) {
    final a = widget.align;
    switch (side) {
      case ClideAnchorSide.below:
        return (
          a == ClideAnchorAlign.start
              ? Alignment.bottomLeft
              : a == ClideAnchorAlign.end
              ? Alignment.bottomRight
              : Alignment.bottomCenter,
          a == ClideAnchorAlign.start
              ? Alignment.topLeft
              : a == ClideAnchorAlign.end
              ? Alignment.topRight
              : Alignment.topCenter,
        );
      case ClideAnchorSide.above:
        return (
          a == ClideAnchorAlign.start
              ? Alignment.topLeft
              : a == ClideAnchorAlign.end
              ? Alignment.topRight
              : Alignment.topCenter,
          a == ClideAnchorAlign.start
              ? Alignment.bottomLeft
              : a == ClideAnchorAlign.end
              ? Alignment.bottomRight
              : Alignment.bottomCenter,
        );
      case ClideAnchorSide.right:
        return (
          a == ClideAnchorAlign.start
              ? Alignment.topRight
              : a == ClideAnchorAlign.end
              ? Alignment.bottomRight
              : Alignment.centerRight,
          a == ClideAnchorAlign.start
              ? Alignment.topLeft
              : a == ClideAnchorAlign.end
              ? Alignment.bottomLeft
              : Alignment.centerLeft,
        );
      case ClideAnchorSide.left:
        return (
          a == ClideAnchorAlign.start
              ? Alignment.topLeft
              : a == ClideAnchorAlign.end
              ? Alignment.bottomLeft
              : Alignment.centerLeft,
          a == ClideAnchorAlign.start
              ? Alignment.topRight
              : a == ClideAnchorAlign.end
              ? Alignment.bottomRight
              : Alignment.centerRight,
        );
    }
  }

  Widget _buildEntry(BuildContext context) {
    // Content owns its own focus (ClideMenu autofocuses + handles keys). The
    // FocusScope isolates Tab traversal from the page behind; the Escape Focus
    // sits ABOVE the scope so it catches Esc the content left unhandled, without
    // stealing focus from the content.
    Widget content = widget.overlayBuilder(context, widget.controller);
    if (widget.captureFocus) content = FocusScope(node: _scope, child: content);
    if (widget.dismissOnEscape) {
      content = Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            widget.controller.close();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: content,
      );
    }

    final Widget positioned;
    if (widget.centered) {
      positioned = Positioned(
        top: widget.offset.dy,
        left: 0,
        right: 0,
        child: Center(child: content),
      );
    } else {
      final flipped = _resolvedSide != widget.side;
      final off = flipped ? Offset(widget.offset.dx, -widget.offset.dy) : widget.offset;
      final (target, follower) = _alignments(_resolvedSide);
      // The Stack lays the follower out loosely, so the (shrink-wrapping) panel
      // sizes to its content; the follower layer's transform alone positions it.
      // An Align here would peg the panel to a corner of the full-screen follower
      // box and break hit-testing for non-top-left anchors.
      positioned = CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: target,
        followerAnchor: follower,
        offset: off,
        child: content,
      );
    }

    return Stack(
      children: [
        if (widget.barrier)
          Positioned.fill(
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.controller.close),
          ),
        positioned,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(link: _link, child: widget.anchor);
  }
}
