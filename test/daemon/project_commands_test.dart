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
