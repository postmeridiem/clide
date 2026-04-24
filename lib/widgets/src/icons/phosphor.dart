import 'dart:ui' as ui;

import 'package:clide/widgets/src/clide_icon.dart';

class PhosphorIconPainter extends ClideIconPainter {
  const PhosphorIconPainter(this.codePoint, {this.family = 'Phosphor'});

  final int codePoint;
  final String family;

  @override
  void paint(ui.Canvas canvas, ui.Color color) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontFamily: family, fontSize: 1.0, height: 1.0, textAlign: ui.TextAlign.center),
    )
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

abstract class PhosphorIcons {
  static const folder = PhosphorIconPainter(0xe24a);
  static const fileText = PhosphorIconPainter(0xe23a);
  static const gitBranch = PhosphorIconPainter(0xe278);
  static const gitCommit = PhosphorIconPainter(0xe27a);
  static const gitDiff = PhosphorIconPainter(0xe27c);
  static const gitPullRequest = PhosphorIconPainter(0xe282);
  static const magnifyingGlass = PhosphorIconPainter(0xe30c);
  static const terminal = PhosphorIconPainter(0xe47e);
  static const terminalWindow = PhosphorIconPainter(0xeae8);
  static const code = PhosphorIconPainter(0xe1bc);
  static const codeBlock = PhosphorIconPainter(0xeafe);
  static const pencilSimple = PhosphorIconPainter(0xe3b4);
  static const eye = PhosphorIconPainter(0xe220);
  static const eyeSlash = PhosphorIconPainter(0xe224);
  static const arrowClockwise = PhosphorIconPainter(0xe036);
  static const arrowsOutSimple = PhosphorIconPainter(0xe0a6);
  static const arrowsInSimple = PhosphorIconPainter(0xe09e);
  static const list = PhosphorIconPainter(0xe2f0);
  static const listChecks = PhosphorIconPainter(0xeadc);
  static const gear = PhosphorIconPainter(0xe270);
  static const puzzlePiece = PhosphorIconPainter(0xe596);
  static const keyboard = PhosphorIconPainter(0xe2d8);
  static const palette = PhosphorIconPainter(0xe6c8);
  static const warning = PhosphorIconPainter(0xe4e0);
  static const warningCircle = PhosphorIconPainter(0xe4e2);
  static const check = PhosphorIconPainter(0xe182);
  static const checkCircle = PhosphorIconPainter(0xe184);
  static const caretLeft = PhosphorIconPainter(0xe138);
  static const caretRight = PhosphorIconPainter(0xe13a);
  static const caretDown = PhosphorIconPainter(0xe136);
  static const caretUp = PhosphorIconPainter(0xe13c);
  static const graph = PhosphorIconPainter(0xeb58);
  static const treeStructure = PhosphorIconPainter(0xe67c);
  static const image = PhosphorIconPainter(0xe2ca);
  static const link = PhosphorIconPainter(0xe2e2);
  static const chatCircle = PhosphorIconPainter(0xe168);
  static const robot = PhosphorIconPainter(0xe762);
  static const ticket = PhosphorIconPainter(0xe490);
  static const lightbulb = PhosphorIconPainter(0xe2dc);
  static const notepad = PhosphorIconPainter(0xe63e);
  static const bookOpen = PhosphorIconPainter(0xe0e6);
  static const xMark = PhosphorIconPainter(0xe4f6);
  static const circlesFour = PhosphorIconPainter(0xe190);
}
