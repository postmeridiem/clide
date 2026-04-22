import 'package:clide_app/kernel/src/theme/controller.dart';
import 'package:clide_app/widgets/src/typography.dart';
import 'package:flutter/widgets.dart';

/// Theme-aware Text. Defaults pull from the global foreground token
/// and [clideUiDefaultWeight].
///
/// The UI font family is deliberately **not** set on this widget — it
/// inherits from the ambient `DefaultTextStyle` which `_AppRoot`
/// provides ([clideUiFamily] in real runs). Goldens rely on Alchemist
/// injecting Ahem for deterministic metrics; hard-coding a family here
/// would override that and break pixel determinism per D-024.
class ClideText extends StatelessWidget {
  const ClideText(
    this.data, {
    super.key,
    this.color,
    this.fontSize = 13,
    this.fontWeight,
    this.muted = false,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String data;
  final Color? color;
  final double fontSize;
  final FontWeight? fontWeight;
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
        // Null means inherit from the ambient DefaultTextStyle —
        // _AppRoot installs clideUiDefaultWeight there; goldens get
        // whatever Alchemist injects. Passing an explicit weight (e.g.
        // FontWeight.bold) still wins.
        fontWeight: fontWeight,
      ),
    );
  }
}
