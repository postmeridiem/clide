import 'dart:io';

import 'package:clide/clide.dart';
import 'package:clide/src/daemon/editor_commands.dart';
import 'package:clide/src/editor/registry.dart';
import 'package:test/test.dart';

void main() {
  late Directory sandbox;
  late DaemonDispatcher dispatcher;
  late EditorRegistry reg;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('clide-ed-cmd-test-');
    await File('${sandbox.path}/doc.md').writeAsString('alpha beta');
    final sink = RecordingEventSink();
    reg = EditorRegistry(events: sink, workspaceRoot: sandbox);
    dispatcher = DaemonDispatcher();
    registerEditorCommands(dispatcher, reg);
  });

  tearDown(() async {
    await reg.shutdown();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  Future<IpcResponse> call(String cmd, [Map<String, Object?> args = const {}]) {
    return dispatcher.dispatch(IpcRequest(id: '1', cmd: cmd, args: args));
  }

  test('editor.open requires a path', () async {
    final r = await call('editor.open');
    expect(r.ok, isFalse);
    expect(r.error!.kind, 'user_error');
  });

  test('editor.open + editor.active round-trip', () async {
    final open = await call('editor.open', {'path': 'doc.md'});
    expect(open.ok, isTrue);
    final id = open.data['id']! as String;
    expect(id, startsWith('b_'));

    final active = await call('editor.active');
    expect(active.ok, isTrue);
    final act = active.data['active']! as Map;
    expect(act['id'], id);
    expect(act['path'], 'doc.md');
  });

  test('editor.insert without id targets the active buffer', () async {
    await call('editor.open', {'path': 'doc.md'});
    final r = await call('editor.insert', {'text': 'X '});
    expect(r.ok, isTrue);
    expect(r.data['inserted'], 2);

    final read = await call('editor.read');
    expect((read.data['content'] as String).startsWith('X '), isTrue);
  });

  test('editor.replace-selection swaps selected range', () async {
    final open = await call('editor.open', {'path': 'doc.md'});
    final id = open.data['id'] as String?;

    await call('editor.set-selection', {
      'id': id,
      'selection': {'start': 0, 'end': 5}, // 'alpha'
    });
    final r = await call('editor.replace-selection', {'text': 'gamma'});
    expect(r.ok, isTrue);

    final read = await call('editor.read');
    expect(read.data['content'], 'gamma beta');
  });

  test('editor.save persists to disk', () async {
    await call('editor.open', {'path': 'doc.md'});
    await call('editor.insert', {'text': 'Z '});
    final save = await call('editor.save');
    expect(save.ok, isTrue);
    final disk = await File('${sandbox.path}/doc.md').readAsString();
    expect(disk.startsWith('Z '), isTrue);
  });

  test('editor.close removes the buffer', () async {
    final open = await call('editor.open', {'path': 'doc.md'});
    final id = open.data['id'] as String?;
    final r = await call('editor.close', {'id': id});
    expect(r.ok, isTrue);
    final list = await call('editor.list');
    expect((list.data['buffers'] as List), isEmpty);
  });

  test('editor.list includes all open buffers', () async {
    await File('${sandbox.path}/a.md').writeAsString('a');
    await File('${sandbox.path}/b.md').writeAsString('b');
    await call('editor.open', {'path': 'a.md'});
    await call('editor.open', {'path': 'b.md'});
    final r = await call('editor.list');
    final names = [
      for (final b in (r.data['buffers'] as List).cast<Map>()) b['path'],
    ];
    expect(names, containsAll(['a.md', 'b.md']));
  });

  test('insert on unknown id returns not-found', () async {
    final r = await call('editor.insert', {'id': 'b_404', 'text': 'x'});
    expect(r.ok, isFalse);
    expect(r.error!.code, IpcExitCode.notFound);
  });
}
