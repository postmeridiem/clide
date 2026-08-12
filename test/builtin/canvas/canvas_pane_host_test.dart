/// CanvasPaneHost (T-322): renders the extension-owned document tabs —
/// empty hint without documents, per-tab load through `files.read`, parse
/// errors surfaced as muted text, valid documents as an interactive
/// [CanvasView].
library;

import 'dart:async';

import 'package:clide/builtin/canvas/canvas.dart';
import 'package:clide/builtin/canvas/src/canvas_painter.dart';
import 'package:clide/builtin/canvas/src/canvas_view.dart';
import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/canvas/json_canvas.dart';
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

  late CanvasDocumentStore store;
  setUp(() {
    store = CanvasDocumentStore(ipc: f.ipc, messages: f.services.messages, i18n: f.services.i18n);
    addTearDown(store.dispose);
  });

  // The shared harness's Overlay hands unbounded constraints; the pane is a
  // Column with an Expanded body, so give it a tight box.
  Widget host(MultitabController<String>? tabs, {bool withStore = true}) {
    return harness(
      f,
      SizedBox(
        width: 800,
        height: 600,
        child: CanvasPaneHost(tabs: tabs, store: withStore ? store : null),
      ),
    );
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

  group('persistence', () {
    MultitabController<String> oneTab() => MultitabController<String>(
      initial: [const MultitabEntry(id: 'a.canvas', title: 'a.canvas', payload: 'a.canvas')],
    );

    testWidgets('an edit is written back through files.write', (tester) async {
      final writes = <Map<String, Object?>>[];
      f.ipc.stub('files.read', (args) async => IpcResponse.ok(id: '1', data: {'content': _validCanvas}));
      f.ipc.stub('files.write', (args) async {
        writes.add(args);
        return IpcResponse.ok(id: '1', data: const {'bytes': 1});
      });
      final tabs = oneTab();
      addTearDown(tabs.dispose);

      await tester.pumpWidget(host(tabs));
      await pumpAsync(tester);
      await tester.dragFrom(tester.getCenter(find.byType(CanvasView)), const Offset(40, 0), touchSlopX: 0, touchSlopY: 0);
      await pumpAsync(tester);

      expect(writes, hasLength(1));
      expect(writes.single['path'], 'a.canvas');
      final saved = CanvasDoc.parse(writes.single['text']! as String);
      expect(saved.node('n1')!.x, greaterThan(0), reason: 'the moved position is what got written');
      expect((saved.node('n1')! as TextNode).text, 'hi', reason: 'the payload survives the round trip');
    });

    testWidgets('a pan does not write — only a real edit does', (tester) async {
      var writes = 0;
      f.ipc.stub('files.read', (args) async => IpcResponse.ok(id: '1', data: {'content': _validCanvas}));
      f.ipc.stub('files.write', (args) async {
        writes++;
        return IpcResponse.ok(id: '1', data: const {'bytes': 1});
      });
      final tabs = oneTab();
      addTearDown(tabs.dispose);

      await tester.pumpWidget(host(tabs));
      await pumpAsync(tester);
      // Top-left corner of the view is padding, not the node.
      await tester.dragFrom(tester.getTopLeft(find.byType(CanvasView)) + const Offset(3, 3), const Offset(40, 0), touchSlopX: 0, touchSlopY: 0);
      await pumpAsync(tester);

      expect(writes, 0);
    });

    testWidgets('a failed write toasts and keeps the canvas on screen', (tester) async {
      f.ipc.stub('files.read', (args) async => IpcResponse.ok(id: '1', data: {'content': _validCanvas}));
      f.ipc.stub('files.write', (args) async {
        return IpcResponse.err(
          id: '1',
          error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'path outside workspace: a.canvas'),
        );
      });
      final tabs = oneTab();
      addTearDown(tabs.dispose);

      await tester.pumpWidget(host(tabs));
      await pumpAsync(tester);
      await tester.dragFrom(tester.getCenter(find.byType(CanvasView)), const Offset(40, 0), touchSlopX: 0, touchSlopY: 0);
      await pumpAsync(tester);

      expect(f.services.toast.entries, hasLength(1));
      expect(f.services.toast.entries.single.severity, ToastSeverity.error);
      expect(f.services.toast.entries.single.message, contains('a.canvas'));
      expect(f.services.toast.entries.single.message, contains('path outside workspace'));
      // The edit the user made is still theirs to retry — not blanked out.
      expect(find.byType(CanvasView), findsOneWidget);
    });

    testWidgets('an edit made through the store shows up in the pane', (tester) async {
      // The path a `canvas.*` verb takes: it never touches the widget, it
      // applies to the store, and the pane is looking at the same state.
      f.ipc.stub('files.read', (args) async => IpcResponse.ok(id: '1', data: {'content': _validCanvas}));
      f.ipc.stub('files.write', (args) async => IpcResponse.ok(id: '1', data: const {'bytes': 1}));
      final tabs = oneTab();
      addTearDown(tabs.dispose);

      await tester.pumpWidget(host(tabs));
      await pumpAsync(tester);
      expect(store.doc('a.canvas')!.nodes, hasLength(1));

      await store.apply('a.canvas', store.doc('a.canvas')!.addNode(const TextNode(id: 'cli', x: 400, y: 0, width: 60, height: 30, text: 'from the CLI')));
      await pumpAsync(tester);

      final painter = tester
          .widgetList<CustomPaint>(find.descendant(of: find.byType(CanvasView), matching: find.byType(CustomPaint)))
          .map((p) => p.painter)
          .whereType<CanvasPainter>()
          .single;
      expect(painter.doc.node('cli'), isNotNull);
    });

    testWidgets('add-note routes through the kernel picker and lands a file node', (tester) async {
      // The whole T-571 chain: toolbar → pane → quickOpen.pick() → path →
      // FileNode → store → files.write.
      f.ipc.stub('files.read', (args) async => IpcResponse.ok(id: '1', data: {'content': _validCanvas}));
      final writes = <String>[];
      f.ipc.stub('files.write', (args) async {
        writes.add(args['text']! as String);
        return IpcResponse.ok(id: '1', data: const {'bytes': 1});
      });
      final tabs = oneTab();
      addTearDown(tabs.dispose);

      await tester.pumpWidget(host(tabs));
      await pumpAsync(tester);

      await tester.tap(find.byWidgetPredicate((w) => w is ClideTooltip && w.message == 'Add note from file'));
      await tester.pump();
      expect(f.services.quickOpen.isPicking, isTrue, reason: 'the pane asked the kernel picker');

      f.services.quickOpen.resolvePick('docs/design.md');
      await pumpAsync(tester);

      final saved = CanvasDoc.parse(writes.last);
      final node = saved.nodes.last;
      expect(node, isA<FileNode>());
      expect((node as FileNode).file, 'docs/design.md');
    });

    testWidgets('dismissing the picker leaves the document alone', (tester) async {
      f.ipc.stub('files.read', (args) async => IpcResponse.ok(id: '1', data: {'content': _validCanvas}));
      var writes = 0;
      f.ipc.stub('files.write', (args) async {
        writes++;
        return IpcResponse.ok(id: '1', data: const {'bytes': 1});
      });
      final tabs = oneTab();
      addTearDown(tabs.dispose);

      await tester.pumpWidget(host(tabs));
      await pumpAsync(tester);
      await tester.tap(find.byWidgetPredicate((w) => w is ClideTooltip && w.message == 'Add note from file'));
      await tester.pump();

      f.services.quickOpen.close(); // user hit escape
      await pumpAsync(tester);

      expect(writes, 0);
      expect(store.doc('a.canvas')!.nodes, hasLength(1));
    });

    testWidgets('edits during an in-flight write coalesce to the latest', (tester) async {
      final gate = Completer<void>();
      final written = <String>[];
      f.ipc.stub('files.read', (args) async => IpcResponse.ok(id: '1', data: {'content': _validCanvas}));
      f.ipc.stub('files.write', (args) async {
        written.add(args['text']! as String);
        if (written.length == 1) await gate.future; // hold the first write open
        return IpcResponse.ok(id: '1', data: const {'bytes': 1});
      });
      final tabs = oneTab();
      addTearDown(tabs.dispose);

      await tester.pumpWidget(host(tabs));
      await pumpAsync(tester);
      final centre = tester.getCenter(find.byType(CanvasView));

      await tester.dragFrom(centre, const Offset(20, 0), touchSlopX: 0, touchSlopY: 0);
      await tester.pump();
      // Two more edits while the first write is still in flight.
      await tester.dragFrom(centre, const Offset(20, 0), touchSlopX: 0, touchSlopY: 0);
      await tester.pump();
      await tester.dragFrom(centre, const Offset(20, 0), touchSlopX: 0, touchSlopY: 0);
      await tester.pump();
      expect(written, hasLength(1), reason: 'writes do not overlap');

      gate.complete();
      await pumpAsync(tester);

      // The two queued edits collapse into one write, carrying the last
      // position — not two round trips for a position already superseded.
      expect(written, hasLength(2));
      expect(CanvasDoc.parse(written.last).node('n1')!.x, greaterThan(CanvasDoc.parse(written.first).node('n1')!.x));
    });
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
