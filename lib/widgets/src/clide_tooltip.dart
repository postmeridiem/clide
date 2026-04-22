import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/widgets/src/clide_text.dart';
import 'package:flutter/widgets.dart';

/// Very small tooltip — hover a child to reveal a label. Uses an
/// OverlayEntry to draw above everything else without Material.
class ClideTooltip extends StatefulWidget {
  const ClideTooltip({
    super.key,
    required this.message,
    required this.child,
    this.showDelay = const Duration(milliseconds: 500),
  });

  final String message;
  final Widget child;
  final Duration showDelay;

  @override
  State<ClideTooltip> createState() => _ClideTooltipState();
}

class _ClideTooltipState extends State<ClideTooltip> {
  OverlayEntry? _entry;
  bool _hovering = false;

  void _show() {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _entry?.remove();
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset(0, box.size.height + 4));
    _entry = OverlayEntry(
      builder: (ctx) {
        final tokens = ClideTheme.of(ctx).surface;
        return Positioned(
          left: offset.dx,
          top: offset.dy,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tokens.tooltipBackground,
              border: Border.all(color: tokens.tooltipBorder),
              borderRadius: BorderRadius.circular(3),
            ),
            child: ClideText(widget.message, color: tokens.tooltipForeground),
          ),
        );
      },
    );
    overlay.insert(_entry!);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      tooltip: widget.message,
      child: MouseRegion(
        onEnter: (_) async {
          _hovering = true;
          await Future<void>.delayed(widget.showDelay);
          if (mounted && _hovering) _show();
        },
        onExit: (_) {
          _hovering = false;
          _hide();
        },
        child: widget.child,
      ),
    );
  }
}
