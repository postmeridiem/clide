import 'dart:io';
import 'dart:ui' as ui;

import 'package:clide/src/svg/svg_document.dart';
import 'package:clide/widgets/src/svg/svg_painter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pixel-probe tests: render the scene to a `ui.Image` and read back colours.
/// Deterministic for fills, independent of fonts/goldens.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ui.Image> render(String svg, double w, double h) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
    paintSvg(canvas, Size(w, h), buildSvgDocument(svg));
    return recorder.endRecording().toImage(w.round(), h.round());
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
