import 'dart:ui' as ui;

import 'package:clide/builtin/graph/src/graph_painter.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/src/graph/force_layout.dart';
import 'package:clide/src/graph/vault_graph.dart';
import 'package:clide/widgets/src/clide_settings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

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

  Future<bool> hasInk(GraphPainter painter, [double s = 200]) async {
    final rec = ui.PictureRecorder();
    painter.paint(ui.Canvas(rec, Rect.fromLTWH(0, 0, s, s)), Size(s, s));
    final img = await rec.endRecording().toImage(s.round(), s.round());
    final data = (await img.toByteData())!;
    for (var i = 3; i < data.lengthInBytes; i += 4) {
      if (data.getUint8(i) != 0) return true;
    }
    return false;
  }

  VaultGraph twoNodes() => VaultGraph.fromOutlinks({
    'a.md': const ['b.md'],
    'b.md': const [],
  });

  testWidgets('paints nodes, edges, and labels', (tester) async {
    final tokens = await tokensFrom(tester);
    final g = twoNodes();
    final pos = ForceLayout.compute(['a.md', 'b.md'], g.edgePairs);
    // toImage/toByteData is real engine async — run it off the fake test clock.
    expect(await tester.runAsync(() => hasInk(GraphPainter(graph: g, positions: pos, tokens: tokens))), isTrue);
  });

  testWidgets('dims nodes outside the hover neighbourhood but still draws ink', (tester) async {
    final tokens = await tokensFrom(tester);
    final g = twoNodes();
    final pos = ForceLayout.compute(['a.md', 'b.md'], g.edgePairs);
    // Highlight only a.md — b.md and the edge dim.
    expect(await tester.runAsync(() => hasInk(GraphPainter(graph: g, positions: pos, tokens: tokens, highlight: g.neighborhood('a.md')))), isTrue);
  });

  testWidgets('an empty graph paints nothing (no throw)', (tester) async {
    final tokens = await tokensFrom(tester);
    expect(await tester.runAsync(() => hasInk(GraphPainter(graph: const VaultGraph([], []), positions: const {}, tokens: tokens))), isFalse);
  });

  testWidgets('paints under a user zoom + pan', (tester) async {
    final tokens = await tokensFrom(tester);
    final g = twoNodes();
    final pos = ForceLayout.compute(['a.md', 'b.md'], g.edgePairs);
    expect(await tester.runAsync(() => hasInk(GraphPainter(graph: g, positions: pos, tokens: tokens, zoom: 2, pan: const Offset(15, -10)))), isTrue);
  });

  testWidgets('repaints when zoom or pan changes, not when identical', (tester) async {
    final tokens = await tokensFrom(tester);
    final g = twoNodes();
    final pos = ForceLayout.compute(['a.md', 'b.md'], g.edgePairs);
    GraphPainter p({double zoom = 1, Offset pan = Offset.zero}) => GraphPainter(graph: g, positions: pos, tokens: tokens, zoom: zoom, pan: pan);
    expect(p().shouldRepaint(p()), isFalse);
    expect(p(zoom: 2).shouldRepaint(p()), isTrue);
    expect(p(pan: const Offset(1, 0)).shouldRepaint(p()), isTrue);
  });

  group('hitTestNode', () {
    test('finds the node under the point, null when far or empty', () {
      final g = VaultGraph.fromOutlinks({'a.md': const []});
      // A single node lays out at the layout centre (400,300); an 800×600 canvas
      // over an 800×600 layout is scale 1, no offset → the node sits at (400,300).
      final pos = ForceLayout.compute(['a.md'], const []);
      expect(hitTestNode(g, pos, const Offset(400, 300), const Size(800, 600)), 'a.md');
      expect(hitTestNode(g, pos, const Offset(20, 20), const Size(800, 600)), isNull);
      expect(hitTestNode(g, const {}, Offset.zero, const Size(800, 600)), isNull);
    });

    test('pan shifts the hit location; zoom scales about the centre', () {
      final g = VaultGraph.fromOutlinks({'a.md': const []});
      final pos = ForceLayout.compute(['a.md'], const []); // single node at (400,300)
      // A pan moves the node by the same pixels — hit follows it, misses the old spot.
      expect(hitTestNode(g, pos, const Offset(500, 300), const Size(800, 600), pan: const Offset(100, 0)), 'a.md');
      expect(hitTestNode(g, pos, const Offset(400, 300), const Size(800, 600), pan: const Offset(100, 0)), isNull);
      // Zoom scales about the canvas centre, so a centre node stays under it.
      expect(hitTestNode(g, pos, const Offset(400, 300), const Size(800, 600), zoom: 3), 'a.md');
    });
  });

  group('GraphViewport.fit', () {
    test('a centre point is pan-translated and zoom-invariant', () {
      const canvas = Size(800, 600), layout = Size(800, 600);
      final centre = (x: 400.0, y: 300.0);
      expect(GraphViewport.fit(canvas, layout).toPixel(centre), const Offset(400, 300));
      expect(GraphViewport.fit(canvas, layout, zoom: 4).toPixel(centre), const Offset(400, 300));
      expect(GraphViewport.fit(canvas, layout, pan: const Offset(10, 20)).toPixel(centre), const Offset(410, 320));
    });
  });
}
