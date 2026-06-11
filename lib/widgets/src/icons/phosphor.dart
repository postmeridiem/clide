import 'dart:ui' as ui;

import 'package:clide/widgets/src/clide_icon.dart';
import 'package:clide/widgets/src/icons/phosphor_glyphs.g.dart';

class PhosphorIconPainter extends ClideIconPainter {
  const PhosphorIconPainter(this.codePoint, {this.family = 'Phosphor'});

  final int codePoint;
  final String family;

  @override
  void paint(ui.Canvas canvas, ui.Color color) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: family, fontSize: 1.0, height: 1.0, textAlign: ui.TextAlign.center))
      ..pushStyle(ui.TextStyle(color: color, fontFamily: family))
      ..addText(String.fromCharCode(codePoint));
    final paragraph = builder.build()..layout(const ui.ParagraphConstraints(width: 1.0));
    final dy = (1.0 - paragraph.height) / 2;
    canvas.drawParagraph(paragraph, ui.Offset(0, dy));
  }

  @override
  bool operator ==(Object other) => other is PhosphorIconPainter && other.codePoint == codePoint && other.family == family;

  @override
  int get hashCode => Object.hash(codePoint, family);
}

/// Phosphor glyphs, resolved by their exact kebab-case name (e.g. `folder`,
/// `folder-simple`, `git-branch`). The full label→codepoint table is the
/// generated [kPhosphorGlyphs]; raw codepoints live only there, so feature code
/// reads `PhosphorIcons.byName('folder')` rather than `0xe24a` (T-314). A
/// string key also lets a Lua extension name an icon without crossing the FFI
/// boundary with a codepoint.
abstract class PhosphorIcons {
  /// Shown when a name doesn't resolve. An unresolved name is a real error — a
  /// wrong or missing label — so the fallback is `placeholder`: the box reads
  /// as a render error and surfaces the bug honestly, rather than masking it as
  /// an intentional "unknown" the way a `question` mark would.
  static const String fallbackName = 'placeholder';

  /// Resolve a glyph by its kebab-case [name]. A total function: an unknown
  /// name degrades to [fallbackName] so a bad value (a typo, a stale setting, a
  /// Lua extension's string) never crashes the UI. Typos in clide's own call
  /// sites are caught at CI by `phosphor_glyphs_test`, which asserts every
  /// `byName('…')` literal in `lib/` exists in the map.
  static PhosphorIconPainter byName(String name) => PhosphorIconPainter(kPhosphorGlyphs[name] ?? kPhosphorGlyphs[fallbackName]!);
}
