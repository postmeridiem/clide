import 'package:clide/src/draw/draw_dispatch.dart';
import 'package:clide/src/draw/draw_doc.dart';
import 'package:test/test.dart';

void main() {
  DrawingFileReader reader(Map<String, String> files) =>
      (p) async => files[p];
  Future<DrawResult> resolve(DrawingCardDoc doc, DrawingRegistry reg, {Map<String, String> files = const {}}) =>
      resolveDrawingSvg(doc, reg, readFile: reader(files));

  group('resolveDrawingSvg', () {
    test('primitive: inline svg passes through', () async {
      final r = await resolve(parseDrawingCardDoc({'svg': '<svg id="x"/>'})!, DrawingRegistry());
      expect((r as DrawOk).svg, '<svg id="x"/>');
    });

    test('primitive: svgPath is read via the injected reader', () async {
      final r = await resolve(parseDrawingCardDoc({'svgPath': 'd.svg'})!, DrawingRegistry(), files: {'d.svg': '<svg id="file"/>'});
      expect((r as DrawOk).svg, '<svg id="file"/>');
    });

    test('primitive: an unreadable svgPath is an honest error', () async {
      final r = await resolve(parseDrawingCardDoc({'svgPath': 'missing.svg'})!, DrawingRegistry());
      expect(r, isA<DrawErr>());
      expect((r as DrawErr).message, contains('missing.svg'));
    });

    test('primitive: no source at all is an error', () async {
      final r = await resolve(parseDrawingCardDoc(const {})!, DrawingRegistry());
      expect(r, isA<DrawErr>());
    });

    test('template: an unknown template is an error', () async {
      final r = await resolve(parseDrawingCardDoc({'template': 'd2', 'source': 'a -> b'})!, DrawingRegistry());
      expect(r, isA<DrawErr>());
      expect((r as DrawErr).message, contains('d2'));
    });

    test('template: a registered handler lowers the doc to SVG', () async {
      final reg = DrawingRegistry()..register('d2', (doc) async => '<svg data-src="${doc.fields['source']}"/>');
      final r = await resolve(parseDrawingCardDoc({'template': 'd2', 'source': 'a -> b'})!, reg);
      expect((r as DrawOk).svg, '<svg data-src="a -> b"/>');
    });

    test('template: a handler that returns null is an error', () async {
      final reg = DrawingRegistry()..register('d2', (_) async => null);
      final r = await resolve(parseDrawingCardDoc({'template': 'd2'})!, reg);
      expect(r, isA<DrawErr>());
    });
  });
}
