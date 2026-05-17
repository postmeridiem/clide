import 'package:clide/kernel/kernel.dart' show ClideTheme;
import 'package:clide/widgets/src/clide_tooltip.dart';
import 'package:flutter/widgets.dart';

/// Mouse + keyboard activatable surface. Wraps the [builder] child in
/// a `Focus` so Tab traversal reaches it; an `Actions` provider that
/// handles [ActivateIntent] by invoking [onTap] (the keymap binds
/// Enter / Space to ActivateIntent by default); and a focus ring
/// rendered via `tokens.globalFocus`.
///
/// Hover + pressed state still feed [builder] for visual feedback.
/// Disabled state (`onTap == null`) blocks focus traversal too.
class ClideTappable extends StatefulWidget {
  const ClideTappable({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.onPressChanged,
    this.cursor = SystemMouseCursors.click,
    this.tooltip,
    this.focusNode,
    this.autofocus = false,
  });

  final Widget Function(BuildContext context, bool hovered, bool pressed) builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onPressChanged;
  final MouseCursor cursor;
  final String? tooltip;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<ClideTappable> createState() => _ClideTappableState();
}

class _ClideTappableState extends State<ClideTappable> {
  bool _hover = false;
  bool _pressed = false;
  bool _focused = false;
  FocusNode? _internalFocus;

  FocusNode get _effectiveFocus => widget.focusNode ?? (_internalFocus ??= FocusNode(debugLabel: 'ClideTappable'));

  @override
  void dispose() {
    _internalFocus?.dispose();
    super.dispose();
  }

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
    widget.onPressChanged?.call(v);
  }

  void _setFocused(bool v) {
    if (_focused == v) return;
    setState(() => _focused = v);
  }

  Object? _activate(ActivateIntent _) {
    widget.onTap?.call();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final enabled = widget.onTap != null;
    Widget child = MouseRegion(
      cursor: enabled ? widget.cursor : SystemMouseCursors.forbidden,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) {
        setState(() => _hover = false);
        _setPressed(false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        child: widget.builder(context, _hover, _pressed),
      ),
    );

    // Focus ring — 2 px outer outline in the global focus token. Drawn
    // as a wrapping decoration so it sits outside the child's content
    // without shifting layout (the same DecoratedBox always paints;
    // border color falls through to transparent when unfocused).
    child = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(
          color: _focused ? tokens.globalFocus : const Color(0x00000000),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: child,
    );

    // Actions wraps Focus: dispatching ActivateIntent from the focused
    // context (the node held by Focus) walks UP and finds this Actions
    // provider. The reverse nesting would leave Actions as a descendant
    // of the focused context — unreachable.
    child = Actions(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: _activate),
      },
      child: Focus(
        focusNode: _effectiveFocus,
        canRequestFocus: enabled,
        autofocus: widget.autofocus,
        onFocusChange: _setFocused,
        child: child,
      ),
    );

    if (widget.tooltip != null) {
      child = ClideTooltip(message: widget.tooltip!, child: child);
    }
    return child;
  }
}
