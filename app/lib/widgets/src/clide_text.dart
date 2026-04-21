import 'package:clide_app/kernel/src/theme/controller.dart';
import 'package:flutter/widgets.dart';

/// Theme-aware Text. Defaults pull from the global foreground token.
class ClideText extends StatelessWidget {
  const ClideText(
    this.data, {
    super.key,
    this.color,
    this.fontSize = 13,
    this.fontWeight = FontWeight.w400,
    this.muted = false,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String data;
  final Color? color;
  final double fontSize;
  final FontWeight fontWeight;
  final bool muted;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final resolved =
        color ?? (muted ? tokens.globalTextMuted : tokens.globalForeground);
    return Text(
      data,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      style: TextStyle(
        color: resolved,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFamilyFallback: const ['Inter', 'Helvetica', 'Arial', 'sans-serif'],
      ),
    );
  }
}
