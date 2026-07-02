import 'package:clide/builtin/graph/src/graph_view.dart';
import 'package:clide/src/graph/vault_graph.dart';
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
}
