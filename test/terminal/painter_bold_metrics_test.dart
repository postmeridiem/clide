/// Verifies that the bundled JetBrainsMono Bold face has identical
/// advance widths to Regular at our render size — required for the
/// terminal cell grid to stay stable when bold attributes flip on.
///
/// If this fails, the workaround in painter.dart was deactivated
/// against a font that drifts; pick one of the alternatives in T-73
/// (variable JetBrainsMono / Berkeley Mono / IBM Plex Mono).
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _family = 'JetBrainsMonoTest';
const _fontSize = 14.0;
const _sample = 'mmmmmmmmmm';

void main() {
  setUpAll(() async {
    final regular = await File('assets/fonts/jetbrains_mono/JetBrainsMono-Regular.ttf').readAsBytes();
    final bold = await File('assets/fonts/jetbrains_mono/JetBrainsMono-Bold.ttf').readAsBytes();

    final loader = FontLoader(_family)
      ..addFont(Future.value(ByteData.sublistView(regular)))
      ..addFont(Future.value(ByteData.sublistView(bold)));
    await loader.load();
  });

  test('JetBrainsMono Bold advance width matches Regular (cell drift = 0)', () {
    final regularWidth = _measure(FontWeight.normal);
    final boldWidth = _measure(FontWeight.bold);
    expect(boldWidth, regularWidth,
        reason: 'Bold advance width must equal Regular at $_fontSize px '
            'or the terminal cell grid drifts when bold flips on.');
  });
}

double _measure(FontWeight weight) {
  final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
    fontFamily: _family,
    fontSize: _fontSize,
  ))
    ..pushStyle(ui.TextStyle(
      fontFamily: _family,
      fontWeight: weight,
      fontSize: _fontSize,
    ))
    ..addText(_sample);
  final paragraph = builder.build()..layout(const ui.ParagraphConstraints(width: double.infinity));
  final width = paragraph.maxIntrinsicWidth;
  paragraph.dispose();
  return width;
}
