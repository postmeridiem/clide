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
}
