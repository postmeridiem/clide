/// Tests for the `files.*` command handlers.
library;

import 'dart:io';

import 'package:clide/clide.dart';
import 'package:clide/src/daemon/files_commands.dart';
import 'package:test/test.dart';

void main() {
  late Directory sandbox;
  late DaemonDispatcher dispatcher;
  late FilesService files;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('clide-files-test-');
    // Two files + a subdir + an ignored dir.
    File('${sandbox.path}/README.md').writeAsStringSync('hi');
    File('${sandbox.path}/pubspec.yaml').writeAsStringSync('name: fake');
    Directory('${sandbox.path}/lib').createSync();
    File('${sandbox.path}/lib/main.dart').writeAsStringSync('void main(){}');
    Directory('${sandbox.path}/.dart_tool').createSync();
    File('${sandbox.path}/.dart_tool/hidden').writeAsStringSync('x');

    final sink = RecordingEventSink();
    files = FilesService(
      root: sandbox,
      events: sink,
      // builtin ignore set hides .dart_tool/, which is what we want.
      ignore: IgnoreSet.builtin(),
    );
    dispatcher = DaemonDispatcher();
    registerFilesCommands(dispatcher, files);
  });

  tearDown(() async {
    await files.shutdown();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  Future<IpcResponse> call(String cmd, Map<String, Object?> args) {
    return dispatcher.dispatch(IpcRequest(id: '1', cmd: cmd, args: args));
  }

  test('files.root returns the configured root path', () async {
    final r = await call('files.root', const {});
    expect(r.ok, isTrue);
    expect(r.data['path'], sandbox.absolute.path);
    expect(r.data['ignorePatterns'], greaterThan(0));
  });

  test('files.ls lists the top-level directory', () async {
    final r = await call('files.ls', const {'path': ''});
    expect(r.ok, isTrue);
    final entries = (r.data['entries'] as List).cast<Map>();
    final names = entries.map((e) => e['name']).toList();
    expect(names, containsAll(['lib', 'README.md', 'pubspec.yaml']));
    expect(names, isNot(contains('.dart_tool')));
  });

  test('files.ls sorts directories first', () async {
    final r = await call('files.ls', const {'path': ''});
    final entries = (r.data['entries'] as List).cast<Map>();
    expect(entries.first['isDirectory'], isTrue);
  });

  test('files.ls into a subdirectory returns its contents', () async {
    final r = await call('files.ls', const {'path': 'lib'});
    expect(r.ok, isTrue);
    final names = [
      for (final e in (r.data['entries'] as List).cast<Map>()) e['name'],
    ];
    expect(names, ['main.dart']);
  });

  test('files.watch acks subscription', () async {
    final r = await call('files.watch', const {});
    expect(r.ok, isTrue);
    expect(r.data['subscribed'], isTrue);
  });

  test('files.read returns the file content', () async {
    final r = await call('files.read', const {'path': 'README.md'});
    expect(r.ok, isTrue);
    expect(r.data['content'], 'hi');
    expect(r.data['path'], 'README.md');
  });

  test('files.read without a path returns toolError', () async {
    final r = await call('files.read', const {});
    expect(r.ok, isFalse);
    expect(r.error!.kind, IpcErrorKind.toolError);
    expect(r.error!.message, contains('path'));
  });

  test('files.read with an empty string path returns toolError', () async {
    final r = await call('files.read', const {'path': ''});
    expect(r.ok, isFalse);
  });

  test('files.read with a path outside the root is rejected', () async {
    final r = await call('files.read', const {'path': '../escape.txt'});
    expect(r.ok, isFalse);
    expect(r.error!.message, contains('outside workspace'));
  });

  test('files.read returns toolError for a missing file', () async {
    final r = await call('files.read', const {'path': 'does-not-exist.md'});
    expect(r.ok, isFalse);
    expect(r.error!.message, contains('not found'));
  });

  test('files.ls with a path outside the root is rejected', () async {
    final r = await call('files.ls', const {'path': '../escape'});
    expect(r.ok, isFalse);
    expect(r.error!.message, contains('outside workspace'));
  });

  test('files.watch is idempotent: a second call still acks subscription', () async {
    final r1 = await call('files.watch', const {});
    final r2 = await call('files.watch', const {});
    expect(r1.ok, isTrue);
    expect(r2.ok, isTrue);
  });

  test('FilesService.atCwd resolves a workspace root', () {
    final svc = FilesService.atCwd(events: RecordingEventSink());
    expect(svc.root.existsSync(), isTrue);
    addTearDown(svc.shutdown);
  });
}
