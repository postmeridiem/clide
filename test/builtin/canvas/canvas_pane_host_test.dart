/// CanvasPaneHost (T-322): renders the extension-owned document tabs —
/// empty hint without documents, per-tab load through `files.read`, parse
/// errors surfaced as muted text, valid documents as an interactive
/// [CanvasView].
library;

import 'package:clide/builtin/canvas/canvas.dart';
import 'package:clide/builtin/canvas/src/canvas_view.dart';
import 'package:clide/clide.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

const _validCanvas = '{"nodes":[{"id":"n1","type":"text","text":"hi","x":0,"y":0,"width":100,"height":50}],"edges":[]}';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  // The shared harness's Overlay hands unbounded constraints; the pane is a
  // Column with an Expanded body, so give it a tight box.
  Widget host(MultitabController<String>? tabs) {
    return harness(f, SizedBox(width: 800, height: 600, child: CanvasPaneHost(tabs: tabs)));
  }

  testWidgets('shows the empty hint before activation (null controller)', (tester) async {
    await tester.pumpWidget(host(null));
    expect(find.text('Open a .canvas file to view it here.'), findsOneWidget);
  });

  testWidgets('shows the empty hint when no document is open', (tester) async {
    final tabs = MultitabController<String>();
    addTearDown(tabs.dispose);
    await tester.pumpWidget(host(tabs));
    expect(find.text('Open a .canvas file to view it here.'), findsOneWidget);
  });

  testWidgets('loads a document through files.read and renders a CanvasView', (tester) async {
    final reads = <Object?>[];
    f.ipc.stub('files.read', (args) async {
      reads.add(args['path']);
      return IpcResponse.ok(id: '1', data: {'content': _validCanvas});
    });
    final tabs = MultitabController<String>(
      initial: [const MultitabEntry(id: 'a.canvas', title: 'a.canvas', payload: 'a.canvas')],
    );
    addTearDown(tabs.dispose);

    await tester.pumpWidget(host(tabs));
    await pumpAsync(tester);

    expect(reads, ['a.canvas']);
    expect(find.byType(CanvasView), findsOneWidget);
    expect(find.text('a.canvas'), findsOneWidget); // the sub-tab label
  });

  testWidgets('a failed read surfaces the IPC error as muted text', (tester) async {
    f.ipc.stub('files.read', (args) async {
      return IpcResponse.err(
        id: '1',
        error: IpcError(code: IpcExitCode.notFound, kind: IpcErrorKind.notFound, message: 'no such file: gone.canvas'),
      );
    });
    final tabs = MultitabController<String>(
      initial: [const MultitabEntry(id: 'gone.canvas', title: 'gone.canvas', payload: 'gone.canvas')],
    );
    addTearDown(tabs.dispose);

    await tester.pumpWidget(host(tabs));
    await pumpAsync(tester);

    expect(find.text('no such file: gone.canvas'), findsOneWidget);
    expect(find.byType(CanvasView), findsNothing);
  });

  testWidgets('a non-object top level surfaces the parse error', (tester) async {
    f.ipc.stub('files.read', (args) async => IpcResponse.ok(id: '1', data: {'content': '[1,2,3]'}));
    final tabs = MultitabController<String>(
      initial: [const MultitabEntry(id: 'bad.canvas', title: 'bad.canvas', payload: 'bad.canvas')],
    );
    addTearDown(tabs.dispose);

    await tester.pumpWidget(host(tabs));
    await pumpAsync(tester);

    expect(find.text('canvas: top level must be a JSON object'), findsOneWidget);
    expect(find.byType(CanvasView), findsNothing);
  });

  testWidgets('two documents render as two sub-tabs, keep-alive across switches', (tester) async {
    f.ipc.stub('files.read', (args) async => IpcResponse.ok(id: '1', data: {'content': _validCanvas}));
    final tabs = MultitabController<String>(
      initial: [
        const MultitabEntry(id: 'notes/a.canvas', title: 'a.canvas', payload: 'notes/a.canvas'),
        const MultitabEntry(id: 'notes/b.canvas', title: 'b.canvas', payload: 'notes/b.canvas'),
      ],
    );
    addTearDown(tabs.dispose);

    await tester.pumpWidget(host(tabs));
    await pumpAsync(tester);

    expect(find.text('a.canvas'), findsOneWidget);
    expect(find.text('b.canvas'), findsOneWidget);
    // keepAlive keeps both bodies mounted — the inactive one offstage in
    // the IndexedStack — so both must be found with skipOffstage off.
    expect(find.byType(CanvasView, skipOffstage: false), findsNWidgets(2));
    expect(find.byType(CanvasView), findsOneWidget);

    tabs.activate('notes/b.canvas');
    await pumpAsync(tester);
    expect(find.byType(CanvasView, skipOffstage: false), findsNWidgets(2));
    expect(find.byType(CanvasView), findsOneWidget);
  });
}
