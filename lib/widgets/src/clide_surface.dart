import 'package:clide/kernel/src/theme/controller.dart';
import 'package:flutter/widgets.dart';

/// Themed container. Replaces Material's Card / Scaffold body surfaces
/// for clide widgets — pulls color, border, and padding from the
/// current theme's surface tokens.
class ClideSurface extends StatelessWidget {
  const ClideSurface({
    super.key,
    this.child,
    this.color,
    this.border,
    this.padding = EdgeInsets.zero,
    this.width,
    this.height,
    this.borderRadius,
  });

  final Widget? child;
  final Color? color;
  final Color? border;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? tokens.panelBackground,
        border: border == null ? null : Border.all(color: border!, width: 1),
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}
