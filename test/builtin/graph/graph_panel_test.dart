import 'dart:async';

import 'package:clide/builtin/graph/src/graph_panel.dart';
import 'package:clide/builtin/graph/src/graph_view.dart';
import 'package:clide/clide.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  IpcResponse ok(Map<String, Object?> data) => IpcResponse.ok(id: '1', data: data);

  /// Stubs `pql.files` (from the map's keys) and `pql.meta` (outlinks + tags).
  void stubVault(Map<String, List<String>> vault, {Map<String, List<String>> tags = const {}}) {
    f.ipc.stub(
      'pql.files',
      (_) async => ok({
        'files': [
          for (final p in vault.keys) {'path': p},
        ],
      }),
    );
    f.ipc.stub('pql.meta', (args) async {
      final path = args['path'] as String?;
      return ok({
        'outlinks': [
          for (final t in vault[path] ?? const []) {'target': t},
        ],
        'tags': tags[path] ?? const <String>[],
      });
    });
  }

  Widget panel([Size size = const Size(400, 400)]) => anchoredHarness(f, SizedBox(width: size.width, height: size.height, child: const GraphPanel()));

  testWidgets('shows a spinner (no filter bar) while the first load is in flight', (tester) async {
    f.ipc.stub('pql.files', (_) => Completer<IpcResponse>().future);
    await tester.pumpWidget(panel());
    await tester.pump();
    expect(find.byType(ClideSpinner), findsOneWidget);
    expect(find.byType(ClideFilterBox), findsNothing);
    expect(find.byType(GraphView), findsNothing);
  });

  testWidgets('renders the graph and the filter bar once loaded', (tester) async {
    stubVault({
      'a.md': ['b.md'],
      'b.md': [],
    });
    await tester.pumpWidget(panel());
    await pumpAsync(tester);
    expect(find.byType(GraphView), findsOneWidget);
    expect(find.byType(ClideFilterBox), findsOneWidget);
  });

  testWidgets('shows an empty message for a vault with no notes', (tester) async {
    stubVault(const {});
    await tester.pumpWidget(panel());
    await pumpAsync(tester);
    expect(find.text('No linked notes in this vault.'), findsOneWidget);
    expect(find.byType(GraphView), findsNothing);
  });

  testWidgets('surfaces a load error', (tester) async {
    f.ipc.stub(
      'pql.files',
      (_) async => IpcResponse.err(
        id: '1',
        error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'index locked'),
      ),
    );
    await tester.pumpWidget(panel());
    await pumpAsync(tester);
    expect(find.text('index locked'), findsOneWidget);
    expect(find.byType(GraphView), findsNothing);
  });

  testWidgets('clicking a node opens it in the editor', (tester) async {
    stubVault({'only.md': const []});
    String? opened;
    f.ipc.stub('editor.open', (args) async {
      opened = args['path'] as String?;
      return ok(const {});
    });
    await tester.pumpWidget(panel());
    await pumpAsync(tester);
    await tester.tap(find.byType(GraphView));
    await pumpAsync(tester);
    expect(opened, 'only.md');
  });

  testWidgets('a depth pill with no active note shows the local-graph hint', (tester) async {
    stubVault({
      'a.md': ['b.md'],
      'b.md': [],
    });
    await tester.pumpWidget(panel());
    await pumpAsync(tester);
    await tester.tap(find.text('1')); // depth-1 from the (absent) active note
    await pumpAsync(tester);
    expect(find.text('Open a note to see its local graph.'), findsOneWidget);
    expect(find.byType(GraphView), findsNothing);
  });

  testWidgets('a tag pill cycles include → exclude and filters the graph', (tester) async {
    stubVault(
      {'only.md': const []},
      tags: {
        'only.md': ['x'],
      },
    );
    await tester.pumpWidget(panel());
    await pumpAsync(tester);
    expect(find.text('x'), findsOneWidget); // neutral tag pill

    await tester.tap(find.text('x')); // → include; the note carries x, so it stays
    await pumpAsync(tester);
    expect(find.byType(GraphView), findsOneWidget);

    await tester.tap(find.text('+x')); // → exclude; the note carries x, so it drops
    await pumpAsync(tester);
    expect(find.text('No notes match the filter.'), findsOneWidget);
    expect(find.byType(GraphView), findsNothing);
  });
}
