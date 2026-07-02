import 'package:clide/builtin/graph/src/graph_view.dart';
import 'package:clide/src/graph/vault_graph.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  testWidgets('clicking a node opens it', (tester) async {
    String? opened;
    final g = VaultGraph.fromOutlinks({'only.md': const []});
    await tester.pumpWidget(
      anchoredHarness(
        f,
        SizedBox(
          width: 300,
          height: 300,
          child: GraphView(graph: g, layoutSize: const Size(300, 300), onOpen: (id) => opened = id),
        ),
      ),
    );
    await tester.pump();
    // A single node lays out at the centre → the view's centre.
    await tester.tap(find.byType(GraphView));
    expect(opened, 'only.md');
  });

  testWidgets('renders an empty graph without error', (tester) async {
    await tester.pumpWidget(anchoredHarness(f, const SizedBox(width: 200, height: 200, child: GraphView(graph: VaultGraph([], [])))));
    await tester.pump();
    expect(find.byType(GraphView), findsOneWidget);
    await tester.tap(find.byType(GraphView)); // no node, no onOpen — must not throw
  });

  testWidgets('dragging pans the graph; a reverse pan restores it', (tester) async {
    String? opened;
    final g = VaultGraph.fromOutlinks({'only.md': const []});
    await tester.pumpWidget(
      anchoredHarness(
        f,
        SizedBox(
          width: 400,
          height: 400,
          child: GraphView(graph: g, onOpen: (id) => opened = id),
        ),
      ),
    );
    await tester.pump();
    final centre = tester.getCenter(find.byType(GraphView));
    // Pan right — the node leaves the centre, so a centre tap misses. (An equal,
    // opposite drag cancels the same gesture slop, so the net returns to zero —
    // robust to the exact slop the arena consumes.)
    await tester.drag(find.byType(GraphView), const Offset(120, 0));
    await tester.pump();
    await tester.tapAt(centre);
    expect(opened, isNull);
    await tester.drag(find.byType(GraphView), const Offset(-120, 0));
    await tester.pump();
    await tester.tapAt(centre);
    expect(opened, 'only.md');
  });

  testWidgets('a scroll signal zooms without throwing', (tester) async {
    final g = VaultGraph.fromOutlinks({
      'a.md': const ['b.md'],
      'b.md': const [],
    });
    await tester.pumpWidget(anchoredHarness(f, SizedBox(width: 400, height: 400, child: GraphView(graph: g))));
    await tester.pump();
    final centre = tester.getCenter(find.byType(GraphView));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(centre));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120))); // zoom in
    await tester.pump();
    expect(find.byType(GraphView), findsOneWidget);
  });
}
