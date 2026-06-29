import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:clide/src/svg/svg_document.dart';
import 'package:clide/widgets/src/svg/svg_painter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pixel-probe tests: render the scene to a `ui.Image` and read back colours.
/// Deterministic for fills, independent of fonts/goldens.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ui.Image> render(String svg, double w, double h, {SvgImageResolver? images}) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
    paintSvg(canvas, Size(w, h), buildSvgDocument(svg), images: images);
    return recorder.endRecording().toImage(w.round(), h.round());
  }

  Future<ui.Image> solidImage(int w, int h, int argb) {
    final px = Uint8List(w * h * 4);
    for (var i = 0; i < w * h; i++) {
      px[i * 4] = (argb >> 16) & 0xFF;
      px[i * 4 + 1] = (argb >> 8) & 0xFF;
      px[i * 4 + 2] = argb & 0xFF;
      px[i * 4 + 3] = (argb >> 24) & 0xFF;
    }
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  Future<int> argbAt(ui.Image img, int x, int y) async {
    final data = (await img.toByteData())!;
    final i = (y * img.width + x) * 4;
    return (data.getUint8(i + 3) << 24) | (data.getUint8(i) << 16) | (data.getUint8(i + 1) << 8) | data.getUint8(i + 2);
  }

  int alpha(int argb) => (argb >> 24) & 0xFF;

  test('fills a rect with its colour', () async {
    final img = await render('<svg viewBox="0 0 10 10"><rect width="10" height="10" fill="#FF0000"/></svg>', 10, 10);
    expect(await argbAt(img, 5, 5), 0xFFFF0000);
  });

  test('default fill is black', () async {
    final img = await render('<svg viewBox="0 0 10 10"><rect width="10" height="10"/></svg>', 10, 10);
    expect(await argbAt(img, 5, 5), 0xFF000000);
  });

  test('fill="none" leaves the interior transparent', () async {
    final img = await render('<svg viewBox="0 0 10 10"><rect width="10" height="10" fill="none"/></svg>', 10, 10);
    expect(alpha(await argbAt(img, 5, 5)), 0);
  });

  test('circle centre is filled, corner is empty', () async {
    final img = await render('<svg viewBox="0 0 10 10"><circle cx="5" cy="5" r="5" fill="#0000FF"/></svg>', 10, 10);
    expect(await argbAt(img, 5, 5), 0xFF0000FF);
    expect(alpha(await argbAt(img, 0, 0)), 0);
  });

  test('viewBox scales up to the paint size', () async {
    final img = await render('<svg viewBox="0 0 10 10"><rect width="10" height="10" fill="#FF0000"/></svg>', 20, 20);
    expect(await argbAt(img, 10, 10), 0xFFFF0000);
  });

  test('transform translates the shape', () async {
    final img = await render('<svg viewBox="0 0 20 20"><rect width="5" height="5" fill="#FF0000" transform="translate(10,10)"/></svg>', 20, 20);
    expect(await argbAt(img, 12, 12), 0xFFFF0000);
    expect(alpha(await argbAt(img, 2, 2)), 0);
  });

  test('group opacity dims the contents', () async {
    final img = await render('<svg viewBox="0 0 10 10"><g opacity="0.5"><rect width="10" height="10" fill="#FF0000"/></g></svg>', 10, 10);
    expect(alpha(await argbAt(img, 5, 5)), closeTo(128, 4));
  });

  test('draws a marker-end arrowhead, rotated to the path direction', () async {
    // A rightward path with a green right-pointing triangle marker at its end.
    const svg =
        '<svg viewBox="0 0 20 10">'
        '<defs><marker id="a" refX="0" refY="2" orient="auto" markerUnits="userSpaceOnUse">'
        '<polygon points="0,0 4,2 0,4" fill="#00FF00"/></marker></defs>'
        '<path d="M2 5 L12 5" stroke="#000000" marker-end="url(#a)"/></svg>';
    final data = (await (await render(svg, 40, 20)).toByteData())!;
    var greenDrawn = false;
    for (var i = 0; i < data.lengthInBytes; i += 4) {
      final r = data.getUint8(i), g = data.getUint8(i + 1), b = data.getUint8(i + 2), a = data.getUint8(i + 3);
      if (a > 200 && g > 200 && r < 80 && b < 80) {
        greenDrawn = true;
        break;
      }
    }
    expect(greenDrawn, isTrue, reason: 'the green arrowhead should have been painted');
  });

  test('paints an <image> via the injected resolver, into its dest rect', () async {
    final pic = await solidImage(4, 4, 0xFFFF00FF);
    const svg = '<svg viewBox="0 0 10 10"><image x="0" y="0" width="10" height="10" href="pic"/></svg>';
    final img = await render(svg, 10, 10, images: (href) => href == 'pic' ? pic : null);
    expect(await argbAt(img, 5, 5), 0xFFFF00FF);
  });

  test('an <image> with no resolver paints nothing', () async {
    const svg = '<svg viewBox="0 0 10 10"><image x="0" y="0" width="10" height="10" href="pic"/></svg>';
    final img = await render(svg, 10, 10);
    expect(alpha(await argbAt(img, 5, 5)), 0);
  });

  test('a wide image is aspect-fit (contain) into a square cell, centered (T-319)', () async {
    // 8x2 source into a 10x10 cell → scaled to 10x2.5, centered vertically
    // (rows ~3.75–6.25). The center has the image; the top/bottom margins stay
    // empty — proving contain-fit, not a stretched fill.
    final wide = await solidImage(8, 2, 0xFF00FF00);
    const svg = '<svg viewBox="0 0 10 10"><image x="0" y="0" width="10" height="10" href="pic"/></svg>';
    final img = await render(svg, 10, 10, images: (href) => href == 'pic' ? wide : null);
    expect(await argbAt(img, 5, 5), 0xFF00FF00); // center: image
    expect(alpha(await argbAt(img, 5, 0)), 0); // top margin: empty
    expect(alpha(await argbAt(img, 5, 9)), 0); // bottom margin: empty
  });

  test('renders the real d2 fixture without error and draws ink', () async {
    final svg = File('test/svg/fixtures/d2_pipeline.svg').readAsStringSync();
    final img = await render(svg, 200, 120);
    final data = (await img.toByteData())!;
    var anyInk = false;
    for (var i = 3; i < data.lengthInBytes; i += 4) {
      if (data.getUint8(i) != 0) {
        anyInk = true;
        break;
      }
    }
    expect(anyInk, isTrue);
  });
}
