import 'package:clide/widgets/src/clide_tooltip.dart';
import 'package:flutter/widgets.dart';

class ClideTappable extends StatefulWidget {
  const ClideTappable({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.onPressChanged,
    this.cursor = SystemMouseCursors.click,
    this.tooltip,
  });

  final Widget Function(BuildContext context, bool hovered, bool pressed) builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onPressChanged;
  final MouseCursor cursor;
  final String? tooltip;

  @override
  State<ClideTappable> createState() => _ClideTappableState();
}

class _ClideTappableState extends State<ClideTappable> {
  bool _hover = false;
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
    widget.onPressChanged?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    Widget child = MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) {
        setState(() => _hover = false);
        _setPressed(false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: widget.builder(context, _hover, _pressed),
      ),
    );
    if (widget.tooltip != null) {
      child = ClideTooltip(message: widget.tooltip!, child: child);
    }
    return child;
  }
}
