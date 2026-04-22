import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/widgets/src/clide_text.dart';
import 'package:flutter/widgets.dart';

enum ClideButtonVariant { normal, primary, subtle }

class ClideButton extends StatefulWidget {
  const ClideButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ClideButtonVariant.normal,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.semanticLabel,
    this.semanticHint,
  });

  final String label;
  final VoidCallback? onPressed;
  final ClideButtonVariant variant;
  final EdgeInsetsGeometry padding;

  /// Overrides [label] for screen readers (use when the visible label is
  /// an icon-only glyph or a noun that reads oddly when announced).
  final String? semanticLabel;

  /// Screen-reader hint describing the button's effect. Optional.
  final String? semanticHint;

  @override
  State<ClideButton> createState() => _ClideButtonState();
}

class _ClideButtonState extends State<ClideButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final enabled = widget.onPressed != null;

    Color bg;
    Color fg;
    switch (widget.variant) {
      case ClideButtonVariant.normal:
        bg = _pressed
            ? tokens.buttonActiveBackground
            : _hovered
                ? tokens.buttonHoverBackground
                : tokens.buttonBackground;
        fg = tokens.buttonForeground;
      case ClideButtonVariant.primary:
        bg = _pressed
            ? tokens.panelActiveBorder
            : _hovered
                ? tokens.buttonActiveBackground
                : tokens.buttonActiveBackground;
        fg = tokens.globalBackground;
      case ClideButtonVariant.subtle:
        bg = _hovered
            ? tokens.listItemHoverBackground
            : tokens.listItemBackground;
        fg = tokens.listItemForeground;
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel ?? widget.label,
      hint: widget.semanticHint,
      onTap: enabled ? widget.onPressed : null,
      excludeSemantics: true,
      child: MouseRegion(
        cursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onPressed?.call();
          },
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: tokens.buttonBorder, width: 1),
              borderRadius: BorderRadius.circular(3),
            ),
            child: ClideText(
              widget.label,
              color: fg,
              fontWeight: widget.variant == ClideButtonVariant.primary
                  ? FontWeight.w600
                  : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
