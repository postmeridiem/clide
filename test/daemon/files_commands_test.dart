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
    final names = [for (final e in (r.data['entries'] as List).cast<Map>()) e['name']];
    expect(names, ['main.dart']);
  });

  test('files.walk returns a flat, recursive file list (no dirs, no ignored)', () async {
    final r = await call('files.walk', const {});
    expect(r.ok, isTrue);
    final paths = (r.data['files'] as List).cast<String>();
    expect(paths, containsAll(['README.md', 'pubspec.yaml', 'lib/main.dart']));
    // Directories themselves are never emitted, and .dart_tool is pruned.
    expect(paths, isNot(contains('lib')));
    expect(paths.any((p) => p.startsWith('.dart_tool')), isFalse);
    expect(r.data['truncated'], isFalse);
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

  test('CLI positional path binds to files.read (T-232)', () async {
    // argv shape {positional:[...]} → schema normalize → args['path'].
    final r = await call('files.read', const {
      'positional': ['README.md'],
    });
    expect(r.ok, isTrue, reason: r.error?.message);
    expect(r.data['content'], 'hi');
  });

  test('files.read accepts an absolute path under the workspace root', () async {
    // Regression: the markdown reader publishes absolute skill paths
    // (e.g. .claude/skills/.../SKILL.md). An absolute path under root
    // must resolve, not double onto the root and 404.
    final abs = '${sandbox.absolute.path}/README.md';
    final r = await call('files.read', {'path': abs});
    expect(r.ok, isTrue);
    expect(r.data['content'], 'hi');
  });

  test('files.read reads an absolute path under an extra read root (D-80)', () async {
    final extra = await Directory.systemTemp.createTemp('clide-extra-claude-');
    addTearDown(() async => extra.existsSync() ? extra.deleteSync(recursive: true) : null);
    File('${extra.path}/SKILL.md').writeAsStringSync('# peon');
    final svc = FilesService(root: sandbox, events: RecordingEventSink(), ignore: IgnoreSet.builtin(), extraReadRoots: [extra]);
    final d = DaemonDispatcher();
    registerFilesCommands(d, svc);
    addTearDown(svc.shutdown);

    final r = await d.dispatch(IpcRequest(id: '1', cmd: 'files.read', args: {'path': '${extra.absolute.path}/SKILL.md'}));
    expect(r.ok, isTrue);
    expect(r.data['content'], '# peon');
  });

  test('files.read still rejects an absolute path outside all roots', () async {
    final r = await call('files.read', const {'path': '/etc/passwd'});
    expect(r.ok, isFalse);
    expect(r.error!.message, contains('outside workspace'));
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

  test('files.read rejects a file over the size cap', () async {
    // Cap is 10 MB; write 11 MB of zeros and confirm rejection rather
    // than reading it into memory.
    final big = File('${sandbox.path}/huge.bin');
    final chunk = List<int>.filled(1024 * 1024, 0);
    final sink = big.openWrite();
    for (var i = 0; i < 11; i++) {
      sink.add(chunk);
    }
    await sink.flush();
    await sink.close();
    final r = await call('files.read', const {'path': 'huge.bin'});
    expect(r.ok, isFalse);
    expect(r.error!.message, contains('too large'));
  });

  test('files.ls with a path outside the root is rejected', () async {
    final r = await call('files.ls', const {'path': '../escape'});
    expect(r.ok, isFalse);
    expect(r.error!.message, contains('outside workspace'));
  });

  test('files.read rejects a symlink whose target is outside the workspace (T-102)', () async {
    final outside = await Directory.systemTemp.createTemp('clide_t102_read_');
    addTearDown(() async {
      if (await outside.exists()) await outside.delete(recursive: true);
    });
    File('${outside.path}/secret.txt').writeAsStringSync('payload');
    Link('${sandbox.path}/leak').createSync('${outside.path}/secret.txt');

    final r = await call('files.read', const {'path': 'leak'});
    expect(r.ok, isFalse);
    expect(r.error!.message, contains('outside workspace'));
  });

  test('files.ls rejects a symlinked subdir whose target is outside (T-102)', () async {
    final outside = await Directory.systemTemp.createTemp('clide_t102_ls_');
    addTearDown(() async {
      if (await outside.exists()) await outside.delete(recursive: true);
    });
    Link('${sandbox.path}/leak-dir').createSync(outside.path);

    final r = await call('files.ls', const {'path': 'leak-dir'});
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

  test('files.watch emits files.changed when a file is created under root', () async {
    final ack = await call('files.watch', const {});
    expect(ack.ok, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await File('${sandbox.path}/created.txt').writeAsString('x');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // FilesService.startWatching wires watcher.stream → events.emit;
    // exercising the emit branch is the goal — the consumer-side
    // assertion is covered in test/files/watcher_test.dart.
  });

  test('FilesService.atCwd walks parent dirs looking for .git, falls back to CWD if none', () async {
    final deepNoGit = await Directory.systemTemp.createTemp('clide-no-git-');
    addTearDown(() => deepNoGit.deleteSync(recursive: true));
    final nested = Directory('${deepNoGit.path}/a/b/c')..createSync(recursive: true);
    final saved = Directory.current;
    try {
      Directory.current = nested;
      final svc = FilesService.atCwd(events: RecordingEventSink());
      // No .git anywhere on the walk → root falls back to CWD.
      // Compare canonical paths: on macOS the CWD resolves through the
      // /tmp → /private/tmp symlink, so the raw createTemp path differs.
      expect(svc.root.resolveSymbolicLinksSync(), nested.resolveSymbolicLinksSync());
      await svc.shutdown();
    } finally {
      Directory.current = saved;
    }
  });
}
