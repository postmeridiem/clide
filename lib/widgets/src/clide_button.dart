import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/widgets/src/clide_tappable.dart';
import 'package:clide/widgets/src/clide_text.dart';
import 'package:flutter/widgets.dart';

enum ClideButtonVariant { normal, primary, subtle }

class ClideButton extends StatelessWidget {
  const ClideButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ClideButtonVariant.normal,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.semanticLabel,
    this.semanticHint,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final ClideButtonVariant variant;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;
  final String? semanticHint;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      hint: semanticHint,
      onTap: enabled ? onPressed : null,
      excludeSemantics: true,
      child: ClideTappable(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        tooltip: tooltip,
        onTap: onPressed,
        builder: (ctx, hovered, pressed) {
          Color bg;
          Color fg;
          switch (variant) {
            case ClideButtonVariant.normal:
              bg = pressed
                  ? tokens.buttonActiveBackground
                  : hovered
                      ? tokens.buttonHoverBackground
                      : tokens.buttonBackground;
              fg = tokens.buttonForeground;
            case ClideButtonVariant.primary:
              bg = pressed ? tokens.panelActiveBorder : tokens.buttonActiveBackground;
              fg = tokens.globalBackground;
            case ClideButtonVariant.subtle:
              bg = hovered ? tokens.listItemHoverBackground : tokens.listItemBackground;
              fg = tokens.listItemForeground;
          }

          return Container(
            padding: padding,
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: tokens.buttonBorder, width: 1),
              borderRadius: BorderRadius.circular(3),
            ),
            child: ClideText(
              label,
              color: fg,
              fontWeight: variant == ClideButtonVariant.primary ? FontWeight.w600 : FontWeight.w500,
            ),
          );
        },
      ),
    );
  }
}
