import 'dart:ui' as ui;

import 'package:clide/builtin/canvas/src/canvas_painter.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/src/canvas/json_canvas.dart';
import 'package:clide/widgets/src/clide_settings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  CanvasDoc sampleDoc() => const CanvasDoc(
    nodes: [
      TextNode(id: 't', x: 0, y: 0, width: 200, height: 100, text: 'hello', color: '4'),
      FileNode(id: 'f', x: 300, y: 0, width: 200, height: 100, file: 'notes/a.md'),
    ],
    edges: [CanvasEdge(id: 'e', fromNode: 't', toNode: 'f', fromSide: CanvasSide.right, toSide: CanvasSide.left)],
  );

  Future<SurfaceTokens> tokensFrom(WidgetTester tester) async {
    late SurfaceTokens tokens;
    await tester.pumpWidget(
      anchoredHarness(
        f,
        Builder(
          builder: (ctx) {
            tokens = ClideSettings.theme.of(ctx).surface;
            return const SizedBox();
          },
        ),
      ),
    );
    return tokens;
  }

  Future<bool> hasInk(CanvasPainter painter, [double s = 200]) async {
    final rec = ui.PictureRecorder();
    painter.paint(ui.Canvas(rec, Rect.fromLTWH(0, 0, s, s)), Size(s, s));
    final img = await rec.endRecording().toImage(s.round(), s.round());
    final data = (await img.toByteData())!;
    for (var i = 3; i < data.lengthInBytes; i += 4) {
      if (data.getUint8(i) != 0) return true;
    }
    return false;
  }

  group('canvasContentColor', () {
    test('maps presets, hex (long + short), and null/unknown', () {
      expect(canvasContentColor('4'), const Color(0xFF44CF6E));
      expect(canvasContentColor('#ff0000'), const Color(0xFFFF0000));
      expect(canvasContentColor('#f00'), const Color(0xFFFF0000));
      expect(canvasContentColor(null), isNull);
      expect(canvasContentColor('nonsense'), isNull);
    });
  });

  group('CanvasBounds', () {
    test('spans every node rect', () {
      const doc = CanvasDoc(
        nodes: [
          TextNode(id: 'a', x: -10, y: 5, width: 20, height: 20, text: ''),
          TextNode(id: 'b', x: 100, y: 0, width: 50, height: 80, text: ''),
        ],
      );
      final b = CanvasBounds.of(doc);
      expect((b.left, b.top, b.right, b.bottom), (-10.0, 0.0, 150.0, 80.0));
    });
  });

  group('CanvasViewport.fit', () {
    test('centres content in the padded pane', () {
      const doc = CanvasDoc(
        nodes: [TextNode(id: 'a', x: 0, y: 0, width: 100, height: 100, text: '')],
      );
      final vp = CanvasViewport.fit(const Size(400, 400), CanvasBounds.of(doc));
      final r = vp.rectOf(doc.nodes.first);
      expect(r.center.dx, closeTo(200, 0.001));
      expect(r.center.dy, closeTo(200, 0.001));
    });
  });

  testWidgets('paints nodes, edges, and a group', (tester) async {
    final tokens = await tokensFrom(tester);
    expect(await tester.runAsync(() => hasInk(CanvasPainter(doc: sampleDoc(), tokens: tokens))), isTrue);
  });

  testWidgets('an empty canvas paints nothing (no throw)', (tester) async {
    final tokens = await tokensFrom(tester);
    expect(await tester.runAsync(() => hasInk(CanvasPainter(doc: const CanvasDoc(), tokens: tokens))), isFalse);
  });

  testWidgets('a selected node still paints (draws the focus ring)', (tester) async {
    final tokens = await tokensFrom(tester);
    expect(await tester.runAsync(() => hasInk(CanvasPainter(doc: sampleDoc(), tokens: tokens, selected: 't'))), isTrue);
  });

  testWidgets('repaints on zoom / pan / selection change, not when identical', (tester) async {
    final tokens = await tokensFrom(tester);
    final doc = sampleDoc();
    CanvasPainter p({double zoom = 1, Offset pan = Offset.zero, String? selected}) =>
        CanvasPainter(doc: doc, tokens: tokens, zoom: zoom, pan: pan, selected: selected);
    expect(p().shouldRepaint(p()), isFalse);
    expect(p(zoom: 2).shouldRepaint(p()), isTrue);
    expect(p(pan: const Offset(1, 0)).shouldRepaint(p()), isTrue);
    expect(p(selected: 't').shouldRepaint(p()), isTrue);
  });
}
