import 'package:clide/kernel/src/facade.dart' show ClideKernel;
import 'package:clide/kernel/src/i18n/i18n.dart' show I18nReplacer;
import 'package:clide/kernel/src/panels/arrangement.dart';
import 'package:clide/kernel/src/panels/slot_id.dart';
import 'package:clide/kernel/src/theme/controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A 4-px splitter that adjusts the size of [slot] in [arrangement].
/// Slot hosts wrap this around their edges to make the three-column
/// layout resizable.
///
/// Drag with the mouse, or tab to it and use the arrow keys (Shift =
/// coarse step). Exposes a `slider` Semantics node so screen readers
/// announce the current width.
class DragResizeHandle extends StatefulWidget {
  const DragResizeHandle({super.key, required this.arrangement, required this.slot, required this.axis, this.thickness = DragResizeHandle.defaultThickness});

  final LayoutArrangement arrangement;
  final SlotId slot;
  final Axis axis;
  final double thickness;

  static const defaultThickness = 8.0;
  static const double stepFine = 10.0;
  static const double stepCoarse = 50.0;

  @override
  State<DragResizeHandle> createState() => _DragResizeHandleState();
}

class _DragResizeHandleState extends State<DragResizeHandle> {
  bool _hovered = false;
  bool _focused = false;
  double? _dragStartSize;
  Offset? _dragStartPointer;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final lineColor = (_hovered || _focused) ? tokens.panelActiveBorder : tokens.dividerColor;

    final size = widget.arrangement.sizeOf(widget.slot);

    return Semantics(
      container: true,
      slider: true,
      label: _semanticLabel(context),
      value: size == null ? null : _pixels(context, size.round()),
      increasedValue: size == null ? null : _pixels(context, (size + DragResizeHandle.stepFine).round()),
      decreasedValue: size == null ? null : _pixels(context, (size - DragResizeHandle.stepFine).round()),
      onIncrease: () => _bump(DragResizeHandle.stepFine),
      onDecrease: () => _bump(-DragResizeHandle.stepFine),
      child: FocusableActionDetector(
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        shortcuts: _shortcuts(),
        actions: <Type, Action<Intent>>{
          _BumpIntent: CallbackAction<_BumpIntent>(
            onInvoke: (intent) {
              _bump(intent.delta);
              return null;
            },
          ),
        },
        child: MouseRegion(
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
                  width: widget.axis == Axis.horizontal ? (_focused ? 2 : 1) : null,
                  height: widget.axis == Axis.vertical ? (_focused ? 2 : 1) : null,
                  color: lineColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The slider's accessible name (D-21, `core` namespace). With no kernel in
  /// scope (isolated tests) the i18n lookups fall back to the English
  /// placeholders, mirroring the widget-facing facade's degrade behaviour.
  String _semanticLabel(BuildContext context) {
    final i18n = ClideKernel.maybeOf(context)?.i18n;
    final axis = widget.axis == Axis.horizontal
        ? (i18n?.string('resize.axis.width', namespace: 'core', placeholder: 'width') ?? 'width')
        : (i18n?.string('resize.axis.height', namespace: 'core', placeholder: 'height') ?? 'height');
    if (widget.slot == Slots.sidebar) {
      return i18n?.interpolated(
            'resize.sidebar',
            namespace: 'core',
            placeholder: 'Sidebar {axis}',
            replacers: [I18nReplacer(from: '{axis}', replace: axis)],
          ) ??
          'Sidebar $axis';
    }
    if (widget.slot == Slots.contextPanel) {
      return i18n?.interpolated(
            'resize.contextPanel',
            namespace: 'core',
            placeholder: 'Context panel {axis}',
            replacers: [I18nReplacer(from: '{axis}', replace: axis)],
          ) ??
          'Context panel $axis';
    }
    return i18n?.interpolated(
          'resize.slot',
          namespace: 'core',
          placeholder: '{slot} {axis}',
          replacers: [
            I18nReplacer(from: '{slot}', replace: widget.slot.value),
            I18nReplacer(from: '{axis}', replace: axis),
          ],
        ) ??
        '${widget.slot.value} $axis';
  }

  /// `'{n} pixels'` via the `core` catalog (falls back to English with no
  /// kernel in scope).
  String _pixels(BuildContext context, int n) {
    final i18n = ClideKernel.maybeOf(context)?.i18n;
    return i18n?.interpolated(
          'resize.pixels',
          namespace: 'core',
          placeholder: '{n} pixels',
          replacers: [I18nReplacer(from: '{n}', replace: '$n')],
        ) ??
        '$n pixels';
  }

  Map<ShortcutActivator, Intent> _shortcuts() {
    final horiz = widget.axis == Axis.horizontal;
    final fine = DragResizeHandle.stepFine;
    final coarse = DragResizeHandle.stepCoarse;
    return <ShortcutActivator, Intent>{
      if (horiz) ...{
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _BumpIntent(-fine),
        const SingleActivator(LogicalKeyboardKey.arrowRight): _BumpIntent(fine),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): _BumpIntent(-coarse),
        const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): _BumpIntent(coarse),
      } else ...{
        const SingleActivator(LogicalKeyboardKey.arrowUp): _BumpIntent(-fine),
        const SingleActivator(LogicalKeyboardKey.arrowDown): _BumpIntent(fine),
        const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): _BumpIntent(-coarse),
        const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): _BumpIntent(coarse),
      },
    };
  }

  void _bump(double rawDelta) {
    final current = widget.arrangement.sizeOf(widget.slot);
    if (current == null) return;
    widget.arrangement.setSize(widget.slot, bumpedSlotSize(slot: widget.slot, current: current, rawDelta: rawDelta));
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

class _BumpIntent extends Intent {
  const _BumpIntent(this.delta);
  final double delta;
}

/// Apply a raw delta in the natural axis direction. Drag and arrow
/// keys both call this so the keyboard mirrors the drag: positive
/// delta = right/down. Context-panel sits on the right edge of the
/// app, so we flip the sign there — right-arrow should *shrink* it,
/// matching how dragging the left-edge handle rightward works.
double bumpedSlotSize({required SlotId slot, required double current, required double rawDelta}) {
  final delta = slot == Slots.contextPanel ? -rawDelta : rawDelta;
  return current + delta;
}
