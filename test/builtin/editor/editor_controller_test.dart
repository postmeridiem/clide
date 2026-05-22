/// Tests the multi-buffer tracking in EditorController (the UI mirror
/// of the daemon's editor model): hydrate populates the open-buffer
/// list, events keep it in sync, and activate/close route to IPC.
library;

import 'package:clide/builtin/editor/src/editor_controller.dart';
import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_ipc.dart';

IpcResponse _ok(Map<String, Object?> data) => IpcResponse.ok(id: '', data: data);

Map<String, Object?> _buf(String id, String path, {bool dirty = false}) => {'id': id, 'path': path, 'dirty': dirty};

Map<String, Object?> _read(String id, String path, String content, {bool dirty = false}) => {
      'id': id,
      'path': path,
      'content': content,
      'selection': {'start': 0, 'end': 0},
      'dirty': dirty,
    };

void emitEditor(DaemonBus bus, String kind, Map<String, Object?> data) {
  bus.emit(DaemonEvent(subsystem: 'editor', kind: kind, data: data, ts: DateTime.now().toUtc()));
}

void main() {
  late DaemonBus bus;
  late FakeDaemonClient ipc;
  late EditorController c;

  setUp(() {
    bus = DaemonBus();
    ipc = FakeDaemonClient(log: Logger(), events: bus);
    c = EditorController(ipc: ipc, events: bus);
  });

  tearDown(() async {
    c.dispose();
    await bus.dispose();
  });

  group('hydrate', () {
    test('populates the open-buffer list and loads the active buffer', () async {
      ipc.stub(
          'editor.list',
          (_) async => _ok({
                'buffers': [_buf('b_1', 'lib/a.dart'), _buf('b_2', 'lib/b.dart', dirty: true)]
              }));
      ipc.stub(
          'editor.active',
          (_) async => _ok({
                'active': {'id': 'b_1'}
              }));
      ipc.stub('editor.read', (a) async => _ok(_read('b_1', 'lib/a.dart', 'hello')));

      await c.hydrate();

      expect(c.buffers.map((b) => b.id).toList(), ['b_1', 'b_2']);
      expect(c.buffers[1].dirty, isTrue);
      expect(c.activeId, 'b_1');
      expect(c.content, 'hello');
    });

    test('with no active buffer leaves the list but no active content', () async {
      ipc.stub(
          'editor.list',
          (_) async => _ok({
                'buffers': [_buf('b_1', 'lib/a.dart')]
              }));
      ipc.stub('editor.active', (_) async => _ok(const {})); // no `active` key

      await c.hydrate();

      expect(c.buffers, hasLength(1));
      expect(c.activeId, isNull);
      expect(c.content, '');
    });
  });

  group('routing tab gestures to IPC', () {
    test('activate(id) issues editor.activate', () async {
      String? activated;
      ipc.stub('editor.activate', (a) async {
        activated = a['id'] as String?;
        return _ok({'active': a['id']});
      });
      await c.activate('b_7');
      expect(activated, 'b_7');
    });

    test('activate is a no-op when the id is already active', () async {
      ipc.stub(
          'editor.list',
          (_) async => _ok({
                'buffers': [_buf('b_1', 'a.dart')]
              }));
      ipc.stub(
          'editor.active',
          (_) async => _ok({
                'active': {'id': 'b_1'}
              }));
      ipc.stub('editor.read', (_) async => _ok(_read('b_1', 'a.dart', 'x')));
      await c.hydrate();

      var calls = 0;
      ipc.stub('editor.activate', (a) async {
        calls++;
        return _ok({'active': a['id']});
      });
      await c.activate('b_1'); // already active
      expect(calls, 0);
    });

    test('closeBuffer(id) issues editor.close', () async {
      String? closed;
      ipc.stub('editor.close', (a) async {
        closed = a['id'] as String?;
        return _ok(const {});
      });
      await c.closeBuffer('b_3');
      expect(closed, 'b_3');
    });
  });

  group('event sync', () {
    test('editor.opened refreshes the list and loads the new active buffer', () async {
      var listVersion = 1;
      ipc.stub(
          'editor.list',
          (_) async => _ok({
                'buffers': listVersion == 1 ? [_buf('b_1', 'a.dart')] : [_buf('b_1', 'a.dart'), _buf('b_2', 'b.dart')]
              }));
      ipc.stub(
          'editor.active',
          (_) async => _ok({
                'active': {'id': 'b_1'}
              }));
      ipc.stub('editor.read', (a) async {
        final id = a['id'] as String;
        return _ok(_read(id, id == 'b_1' ? 'a.dart' : 'b.dart', 'content-$id'));
      });
      await c.hydrate();
      expect(c.buffers, hasLength(1));

      listVersion = 2;
      emitEditor(bus, 'editor.opened', {'id': 'b_2'});
      await pumpEventQueue();

      expect(c.buffers.map((b) => b.id).toList(), ['b_1', 'b_2']);
      expect(c.activeId, 'b_2');
      expect(c.content, 'content-b_2');
    });

    test('editor.closed refreshes the list and clears active when it was active', () async {
      var listVersion = 1;
      ipc.stub(
          'editor.list',
          (_) async => _ok({
                'buffers': listVersion == 1 ? [_buf('b_1', 'a.dart'), _buf('b_2', 'b.dart')] : [_buf('b_2', 'b.dart')]
              }));
      ipc.stub(
          'editor.active',
          (_) async => _ok({
                'active': {'id': 'b_1'}
              }));
      ipc.stub('editor.read', (a) async => _ok(_read(a['id'] as String, 'a.dart', 'x')));
      await c.hydrate();
      expect(c.buffers, hasLength(2));

      listVersion = 2;
      emitEditor(bus, 'editor.closed', {'id': 'b_1'});
      await pumpEventQueue();

      expect(c.buffers.map((b) => b.id).toList(), ['b_2']);
      expect(c.activeId, isNull); // cleared until an active-changed arrives
    });

    test('editor.saved clears the dirty marker on the buffer', () async {
      ipc.stub(
          'editor.list',
          (_) async => _ok({
                'buffers': [_buf('b_1', 'a.dart', dirty: true)]
              }));
      ipc.stub(
          'editor.active',
          (_) async => _ok({
                'active': {'id': 'b_1'}
              }));
      ipc.stub('editor.read', (_) async => _ok(_read('b_1', 'a.dart', 'x', dirty: true)));
      await c.hydrate();
      expect(c.buffers.single.dirty, isTrue);

      emitEditor(bus, 'editor.saved', {'id': 'b_1'});
      await pumpEventQueue();

      expect(c.buffers.single.dirty, isFalse);
      expect(c.dirty, isFalse);
    });

    test('editor.edited marks the buffer dirty', () async {
      ipc.stub(
          'editor.list',
          (_) async => _ok({
                'buffers': [_buf('b_1', 'a.dart')]
              }));
      ipc.stub(
          'editor.active',
          (_) async => _ok({
                'active': {'id': 'b_1'}
              }));
      ipc.stub('editor.read', (_) async => _ok(_read('b_1', 'a.dart', 'x')));
      await c.hydrate();
      expect(c.buffers.single.dirty, isFalse);

      // A remote edit (not our own — no set-content was issued).
      emitEditor(bus, 'editor.edited', {'id': 'b_1'});
      await pumpEventQueue();

      expect(c.buffers.single.dirty, isTrue);
    });
  });

  group('local edits', () {
    test('pushLocalEdit marks the active buffer dirty and mirrors to IPC', () async {
      ipc.stub(
          'editor.list',
          (_) async => _ok({
                'buffers': [_buf('b_1', 'a.dart')]
              }));
      ipc.stub(
          'editor.active',
          (_) async => _ok({
                'active': {'id': 'b_1'}
              }));
      ipc.stub('editor.read', (_) async => _ok(_read('b_1', 'a.dart', 'x')));
      await c.hydrate();

      Map<String, Object?>? setArgs;
      ipc.stub('editor.set-content', (a) async {
        setArgs = a;
        return _ok(const {});
      });
      c.pushLocalEdit(newContent: 'xy', newSelection: const Selection.collapsed(2));
      await pumpEventQueue();

      expect(c.dirty, isTrue);
      expect(c.buffers.single.dirty, isTrue);
      expect(setArgs?['id'], 'b_1');
      expect(setArgs?['text'], 'xy');
    });
  });
}
