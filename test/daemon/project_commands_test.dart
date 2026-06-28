/// Tests for `project.new` (T-487, story T-486): name validation, the
/// create-dir + scaffold + git-init service, and the dispatcher verb. git init
/// is injected as a fake, so these run Flutter-free with real temp dirs.
library;

import 'dart:io';

import 'package:clide/clide.dart';
import 'package:clide/src/daemon/project_commands.dart';
import 'package:test/test.dart';

void main() {
  late Directory parent;
  setUp(() async => parent = await Directory.systemTemp.createTemp('clide-newproj-'));
  tearDown(() {
    if (parent.existsSync()) parent.deleteSync(recursive: true);
  });

  group('validateProjectName', () {
    test('rejects empty, paths, and dot-names; accepts a plain folder name', () {
      expect(validateProjectName(''), isNotNull);
      expect(validateProjectName('a/b'), isNotNull);
      expect(validateProjectName('.'), isNotNull);
      expect(validateProjectName('..'), isNotNull);
      expect(validateProjectName('.hidden'), isNotNull);
      expect(validateProjectName('my-app'), isNull);
    });
  });

  group('createNewProject', () {
    test('creates the dir + scaffold and runs git init', () async {
      final inited = <String>[];
      final r = await createNewProject(parent: parent.path, name: 'my-app', gitInit: (d) async => inited.add(d));
      expect(r.ok, isTrue, reason: r.error);
      final target = '${parent.path}/my-app';
      expect(r.path, target);
      expect(Directory(target).existsSync(), isTrue);
      expect(File('$target/.gitignore').existsSync(), isTrue);
      expect(File('$target/CLAUDE.md').readAsStringSync(), contains('my-app'));
      expect(inited, [target]);
    });

    test('refuses an existing target without touching it', () async {
      Directory('${parent.path}/taken').createSync();
      File('${parent.path}/taken/keep.txt').writeAsStringSync('x');
      var gitRan = false;
      final r = await createNewProject(parent: parent.path, name: 'taken', gitInit: (_) async => gitRan = true);
      expect(r.ok, isFalse);
      expect(r.error, contains('already exists'));
      expect(gitRan, isFalse);
      expect(File('${parent.path}/taken/keep.txt').existsSync(), isTrue);
    });

    test('refuses a missing parent and a bad name', () async {
      expect((await createNewProject(parent: '/no/such/parent/xyz', name: 'a', gitInit: (_) async {})).error, contains('does not exist'));
      expect((await createNewProject(parent: parent.path, name: 'a/b', gitInit: (_) async {})).error, isNotNull);
    });
  });

  group('initExistingProject + project.init', () {
    test('inits an existing folder, scaffolds absent files, never clobbers', () async {
      final inited = <String>[];
      File('${parent.path}/CLAUDE.md').writeAsStringSync('keep me');
      final r = await initExistingProject(path: parent.path, gitInit: (d) async => inited.add(d));
      expect(r.ok, isTrue, reason: r.error);
      expect(r.path, parent.path);
      expect(inited, [parent.path]);
      expect(File('${parent.path}/CLAUDE.md').readAsStringSync(), 'keep me', reason: 'existing file untouched');
      expect(File('${parent.path}/.gitignore').existsSync(), isTrue, reason: 'absent file scaffolded');
    });

    test('refuses a missing directory', () async {
      expect((await initExistingProject(path: '/no/such/dir/xyz', gitInit: (_) async {})).error, contains('does not exist'));
    });

    test('project.init verb inits --dir, and falls back to the default init path', () async {
      final d = DaemonDispatcher();
      registerProjectCommands(d, gitInit: (_) async {}, defaultInitPath: () => parent.path);
      final r1 = await d.dispatch(
        IpcRequest(
          id: '1',
          cmd: 'project.init',
          args: {
            'positional': const <String>[],
            'flags': {'dir': parent.path},
          },
        ),
      );
      expect(r1.ok, isTrue, reason: r1.error?.message);
      expect(r1.data['path'], parent.path);
      final r2 = await d.dispatch(IpcRequest(id: '2', cmd: 'project.init', args: {'positional': const <String>[], 'flags': const {}}));
      expect(r2.ok, isTrue, reason: r2.error?.message);
      expect(r2.data['path'], parent.path);
    });
  });

  group('project.new command', () {
    Future<IpcResponse> run(List<String> positional, {Map<String, Object?>? flags, String? defaultParent}) {
      final d = DaemonDispatcher();
      registerProjectCommands(d, gitInit: (_) async {}, defaultParent: () => defaultParent);
      return d.dispatch(IpcRequest(id: '1', cmd: 'project.new', args: {'positional': positional, 'flags': ?flags}));
    }

    test('creates under --dir and returns the path', () async {
      final r = await run(['my-app'], flags: {'dir': parent.path});
      expect(r.ok, isTrue, reason: r.error?.message);
      expect(r.data['path'], '${parent.path}/my-app');
      expect(r.data['name'], 'my-app');
    });

    test('falls back to the default parent when --dir is omitted', () async {
      final r = await run(['my-app'], defaultParent: parent.path);
      expect(r.ok, isTrue, reason: r.error?.message);
      expect(r.data['path'], '${parent.path}/my-app');
    });

    test('errors with no name, and with no parent available', () async {
      expect((await run([])).ok, isFalse, reason: 'name is required');
      expect((await run(['x'])).ok, isFalse, reason: 'no --dir and no default parent');
    });
  });
}
