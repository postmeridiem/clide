/// T-319: loadDrawingImages decodes the annotated `<image>` hrefs a drawing
/// card references, skipping files it can't read — the resolver the compare
/// card and lightbox paint through.
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:clide/builtin/claude/src/conversation_view.dart' show loadDrawingImages;
import 'package:clide/src/svg/svg_document.dart' show buildSvgDocument;
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _pixelImage() {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(Uint8List(4), 1, 1, ui.PixelFormat.rgba8888, c.complete);
  return c.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decodes annotated image hrefs and skips a missing file', () async {
    final img = await _pixelImage();
    final doc = buildSvgDocument(
      '<svg viewBox="0 0 40 10">'
      '<image href="a.png" x="0" y="0" width="20" height="10" data-label="A"/>'
      '<image href="gone.png" x="20" y="0" width="20" height="10" data-label="B"/>'
      '</svg>',
    );
    final imgs = await loadDrawingImages(
      doc,
      load: (p) async => p == 'a.png' ? Uint8List(4) : null, // gone.png → null → skipped
      decode: (_) async => img,
    );
    expect(imgs.keys.toList(), ['a.png']);
    expect(imgs['a.png'], same(img));
    img.dispose();
  });

  test('a doc with no image references loads nothing', () async {
    final doc = buildSvgDocument('<svg viewBox="0 0 10 10"><rect width="10" height="10" data-label="x"/></svg>');
    expect(await loadDrawingImages(doc, load: (_) async => Uint8List(4)), isEmpty);
  });
}
