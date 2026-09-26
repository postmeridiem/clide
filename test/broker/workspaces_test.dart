import 'dart:io';

import 'package:clide/src/broker/environment.dart';
import 'package:clide/src/broker/workspaces.dart';
import 'package:test/test.dart';

/// The workspace registry (D-119).
void main() {
  late Directory dir;
  late WorkspaceRegistry registry;
  late String projects;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('clide-workspaces-');
    registry = WorkspaceRegistry(dir.path);
    projects = registry.projects(0);
    Directory(projects).createSync(recursive: true);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  group('the name rule', () {
    test('takes letters, digits, ".", "_" and "-", up to 64 characters', () {
      for (final name in ['clide', 'Clide-2.x_final', 'a', '1.0', 'x' * 64]) {
        expect(workspaceNameProblem(name), isNull, reason: name);
      }
    });

    test('refuses other characters, a leading "." or "-", and a longer name', () {
      for (final (name, part) in [
        ('my repo', 'characters other than'),
        ('café', 'characters other than'),
        ('a/b', 'characters other than'),
        ('a%2Fb', 'characters other than'),
        ('', 'characters other than'),
        ('.git', 'starts with "."'),
        ('..', 'starts with "."'),
        ('-rf', 'starts with "-"'),
        ('x' * 65, 'longer than 64'),
      ]) {
        expect(workspaceNameProblem(name), contains(part), reason: name);
      }
    });
  });

  test('a scan lists the folders, and reports the ones it skips with why', () {
    for (final name in ['beta', 'alpha', 'with space', '.hidden']) {
      Directory('$projects/$name').createSync();
    }
    File('$projects/notes.txt').writeAsStringSync('A file is not a workspace.');
    Link('$projects/linked').createSync('$projects/alpha');
    final scan = registry.scan(0);
    expect(scan.slugs, ['alpha', 'beta']);
    expect([for (final s in scan.skipped) s.name], ['.hidden', 'linked', 'with space']);
    expect(scan.skipped[1].reason, contains('symbolic link'));
    expect(scan.skipped[2].reason, contains('characters other than'));
  });

  test('a missing projects folder is named', () {
    expect(() => registry.scan(1), throwsA(isA<BrokerConfigException>().having((e) => e.message, 'message', contains('${dir.path}/1/projects'))));
  });

  test('finds a workspace by its folder name, and nothing else of that name', () {
    Directory('$projects/clide').createSync();
    Directory('$projects/.hidden').createSync();
    File('$projects/file').writeAsStringSync('');
    Link('$projects/link').createSync('$projects/clide');
    expect(registry.find(0, 'clide'), '$projects/clide');
    for (final slug in ['missing', 'file', 'link', '.hidden', '..', '.']) {
      expect(registry.find(0, slug), isNull, reason: slug);
    }
    expect(registry.find(1, 'clide'), isNull, reason: "another user's folder");
  });

  test('a folder added while the broker runs is found on the next request for it', () {
    expect(registry.find(0, 'later'), isNull);
    Directory('$projects/later').createSync();
    expect(registry.find(0, 'later'), '$projects/later');
  });
}
