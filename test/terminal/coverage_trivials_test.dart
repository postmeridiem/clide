/// Closeout tests for the last single-digit-uncovered lines in
/// `lib/src/terminal/`: pointer_input constructors, the abstract
/// TerminalMouseHandler constructor, the reflow padding branch in
/// Buffer.resize, and the wide-char skip branch in
/// TerminalPainter.paintLine.
library;

import 'dart:ui';

import 'package:clide/src/terminal/src/core/mouse/handler.dart';
import 'package:clide/src/terminal/src/terminal.dart';
import 'package:clide/src/terminal/src/ui/painter.dart';
import 'package:clide/src/terminal/src/ui/pointer_input.dart';
import 'package:clide/src/terminal/src/ui/terminal_text_style.dart';
import 'package:clide/src/terminal/src/ui/themes.dart';
import 'package:flutter/painting.dart';
import 'package:test/test.dart';

class _StubMouseHandler extends TerminalMouseHandler {
  const _StubMouseHandler();
  @override
  String? call(TerminalMouseEvent event) => null;
}

void main() {
  test('PointerInputs.none / .all produce expected sets', () {
    expect(const PointerInputs.none().inputs, isEmpty);
    expect(const PointerInputs.all().inputs, containsAll(PointerInput.values));
  });

  test('TerminalMouseHandler abstract const constructor is reachable via a subclass', () {
    const h = _StubMouseHandler();
    expect(h, isA<TerminalMouseHandler>());
  });

  test('Buffer.resize pads reflow output up to the new height', () {
    final t = Terminal(maxLines: 200, onOutput: (_) {});
    // Write content narrower than the new width — reflow should produce
    // fewer lines than newHeight, triggering the pad-with-empty-lines
    // branch in buffer.dart.
    t.write('abc\r\n');
    // Resize to a wide + tall viewport.
    t.resize(40, 50, 8, 16);
    expect(t.buffer.lines.length, greaterThanOrEqualTo(50));
  });

  test('TerminalPainter.paintLine handles wide (CJK) cells without skipping the skip', () {
    final t = Terminal(maxLines: 100, onOutput: (_) {});
    // CJK ideograph — terminal stores it as a width-2 cell, so paintLine
    // advances `i` twice and the wide-char branch fires.
    t.write('漢字');
    final p = TerminalPainter(
      theme: TerminalThemes.defaultTheme,
      textStyle: const TerminalStyle(),
      textScaler: const TextScaler.linear(1.0),
    );
    p.paintLine(Canvas(PictureRecorder()), Offset.zero, t.buffer.lines[0]);
  });
}
