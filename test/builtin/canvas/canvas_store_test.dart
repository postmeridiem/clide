/// CanvasDocumentStore (T-570) — the document state lifted out of the pane
/// widget so the `canvas.*` verbs and a drag edit the same thing.
library;

import 'dart:async';

import 'package:clide/builtin/canvas/canvas.dart';
import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/canvas/json_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

const _valid = '{"nodes":[{"id":"n1","type":"text","text":"hi","x":0,"y":0,"width":100,"height":50}],"edges":[]}';

void main() {
  late KernelFixture f;
  late CanvasDocumentStore store;

  setUp(() async {
    f = await KernelFixture.create();
    store = CanvasDocumentStore(ipc: f.ipc, messages: f.services.messages, i18n: f.services.i18n);
  });
  tearDown(() {
    store.dispose();
    return f.dispose();
  });

  void stubRead(String content) => f.ipc.stub('files.read', (args) async => IpcResponse.ok(id: '1', data: {'content': content}));

  group('open', () {
    test('loads and parses a document, then notifies', () async {
      stubRead(_valid);
      var notifications = 0;
      store.addListener(() => notifications++);

      await store.open('a.canvas');

      expect(store.doc('a.canvas')!.node('n1'), isNotNull);
      expect(store.openPaths, ['a.canvas']);
      expect(notifications, 1);
    });

    test('is idempotent — a second open does not re-read', () async {
      var reads = 0;
      f.ipc.stub('files.read', (args) async {
        reads++;
        return IpcResponse.ok(id: '1', data: const {'content': _valid});
      });

      await store.open('a.canvas');
      await store.open('a.canvas');
      expect(reads, 1);
    });

    test('a failed read is recorded as an error, not a document', () async {
      f.ipc.stub(
        'files.read',
        (args) async => IpcResponse.err(
          id: '1',
          error: IpcError(code: IpcExitCode.notFound, kind: IpcErrorKind.notFound, message: 'no such file'),
        ),
      );

      await store.open('gone.canvas');
      expect(store.doc('gone.canvas'), isNull);
      expect(store.entry('gone.canvas')!.error, 'no such file');
    });

    test('a malformed document surfaces the parse error', () async {
      stubRead('[1,2,3]');
      await store.open('bad.canvas');
      expect(store.entry('bad.canvas')!.error, contains('top level must be a JSON object'));
    });

    test('an unopened path has no entry at all', () {
      expect(store.doc('never.canvas'), isNull);
      expect(store.entry('never.canvas'), isNull);
      expect(store.openPaths, isEmpty);
    });
  });

  group('apply', () {
    test('replaces the document, notifies, and writes it back', () async {
      stubRead(_valid);
      final writes = <String>[];
      f.ipc.stub('files.write', (args) async {
        writes.add(args['text']! as String);
        return IpcResponse.ok(id: '1', data: const {'bytes': 1});
      });
      await store.open('a.canvas');

      var notifications = 0;
      store.addListener(() => notifications++);
      final next = store.doc('a.canvas')!.replaceNode(store.doc('a.canvas')!.node('n1')!.withRect(x: 42));
      await store.apply('a.canvas', next);

      expect(store.doc('a.canvas')!.node('n1')!.x, 42);
      expect(notifications, 1);
      expect(CanvasDoc.parse(writes.single).node('n1')!.x, 42);
    });

    test('a path that is not open is ignored, and writes nothing', () async {
      var writes = 0;
      f.ipc.stub('files.write', (args) async {
        writes++;
        return IpcResponse.ok(id: '1', data: const {'bytes': 1});
      });

      await store.apply('never.canvas', const CanvasDoc());
      expect(store.openPaths, isEmpty);
      expect(writes, 0);
    });

    test('overlapping applies do not interleave, and coalesce to the latest', () async {
      stubRead(_valid);
      final gate = Completer<void>();
      final writes = <String>[];
      f.ipc.stub('files.write', (args) async {
        writes.add(args['text']! as String);
        if (writes.length == 1) await gate.future;
        return IpcResponse.ok(id: '1', data: const {'bytes': 1});
      });
      await store.open('a.canvas');
      final base = store.doc('a.canvas')!;

      final first = store.apply('a.canvas', base.replaceNode(base.node('n1')!.withRect(x: 1)));
      final second = store.apply('a.canvas', base.replaceNode(base.node('n1')!.withRect(x: 2)));
      final third = store.apply('a.canvas', base.replaceNode(base.node('n1')!.withRect(x: 3)));
      await second;
      await third;
      expect(writes, hasLength(1), reason: 'the first write is still in flight');

      gate.complete();
      await first;
      expect(writes, hasLength(2), reason: 'two queued edits collapse into one write');
      expect(CanvasDoc.parse(writes.last).node('n1')!.x, 3);
    });

    test('two documents write independently', () async {
      stubRead(_valid);
      final paths = <String>[];
      f.ipc.stub('files.write', (args) async {
        paths.add(args['path']! as String);
        return IpcResponse.ok(id: '1', data: const {'bytes': 1});
      });
      await store.open('a.canvas');
      await store.open('b.canvas');

      await store.apply('a.canvas', store.doc('a.canvas')!);
      await store.apply('b.canvas', store.doc('b.canvas')!);
      expect(paths, ['a.canvas', 'b.canvas']);
    });

    test('a failed write raises an error toast and keeps the document', () async {
      stubRead(_valid);
      f.ipc.stub(
        'files.write',
        (args) async => IpcResponse.err(
          id: '1',
          error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'path outside workspace'),
        ),
      );
      await store.open('a.canvas');

      await store.apply('a.canvas', store.doc('a.canvas')!.addNode(const TextNode(id: 'n2', x: 0, y: 0, width: 10, height: 10)));
      // The toast reaches ToastService over the MessageBus, so it lands a
      // turn after the failed write returns.
      await Future<void>.delayed(Duration.zero);

      expect(f.services.toast.entries, hasLength(1));
      expect(f.services.toast.entries.single.severity, ToastSeverity.error);
      expect(f.services.toast.entries.single.message, contains('a.canvas'));
      expect(store.doc('a.canvas')!.node('n2'), isNotNull, reason: 'the edit is still the user’s to retry');
    });
  });

  group('close', () {
    test('close drops one document and notifies', () async {
      stubRead(_valid);
      await store.open('a.canvas');
      await store.open('b.canvas');

      var notifications = 0;
      store.addListener(() => notifications++);
      store.close('a.canvas');

      expect(store.openPaths, ['b.canvas']);
      expect(notifications, 1);
    });

    test('closing an unopened path is a silent no-op', () async {
      var notifications = 0;
      store.addListener(() => notifications++);
      store.close('never.canvas');
      expect(notifications, 0);
    });

    test('closeAll drops everything — the workspace-switch path', () async {
      stubRead(_valid);
      await store.open('a.canvas');
      await store.open('b.canvas');

      store.closeAll();
      expect(store.openPaths, isEmpty);
      // Idempotent: a second sweep notifies nobody.
      var notifications = 0;
      store.addListener(() => notifications++);
      store.closeAll();
      expect(notifications, 0);
    });
  });
}
