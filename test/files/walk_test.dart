/// Tests for `walkFiles` — the recursive, ignore-pruned, capped
/// workspace file walk behind `files.walk` and the search engine.
library;

import 'dart:io';

import 'package:clide/src/files/ignore.dart';
import 'package:clide/src/files/listing.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('clide-walk-');
    File('${root.path}/README.md').writeAsStringSync('a');
    File('${root.path}/pubspec.yaml').writeAsStringSync('b');
    Directory('${root.path}/lib/src').createSync(recursive: true);
    File('${root.path}/lib/main.dart').writeAsStringSync('c');
    File('${root.path}/lib/src/util.dart').writeAsStringSync('d');
    Directory('${root.path}/build').createSync();
    File('${root.path}/build/output.bin').writeAsStringSync('e');
  });
  tearDown(() async {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('walks recursively, returns files sorted by path', () async {
    final r = await walkFiles(root: root, ignore: IgnoreSet([]));
    expect(r.truncated, isFalse);
    expect(r.files.map((e) => e.path).toList(), ['README.md', 'build/output.bin', 'lib/main.dart', 'lib/src/util.dart', 'pubspec.yaml']);
  });

  test('prunes ignored directories (build/ via builtin ignore)', () async {
    final r = await walkFiles(root: root, ignore: IgnoreSet.builtin());
    final paths = r.files.map((e) => e.path).toList();
    expect(paths, isNot(contains('build/output.bin')));
    expect(paths, containsAll(['README.md', 'lib/main.dart', 'lib/src/util.dart']));
  });

  test('emits only files, never directory entries', () async {
    final r = await walkFiles(root: root, ignore: IgnoreSet([]));
    expect(r.files.every((e) => !e.isDirectory), isTrue);
  });

  test('respects the maxFiles cap and flags truncation', () async {
    final r = await walkFiles(root: root, ignore: IgnoreSet([]), maxFiles: 2);
    expect(r.truncated, isTrue);
    expect(r.files, hasLength(2));
  });

  test('an empty workspace yields no files and is not truncated', () async {
    final empty = await Directory.systemTemp.createTemp('clide-walk-empty-');
    addTearDown(() => empty.deleteSync(recursive: true));
    final r = await walkFiles(root: empty, ignore: IgnoreSet([]));
    expect(r.files, isEmpty);
    expect(r.truncated, isFalse);
  });

  // T-365: stat() follows links, so the old detection (stat.type == link)
  // was always false and walkFiles descended symlinked directories —
  // an escape hatch out of the workspace.
  group('symlinks (T-365)', () {
    test('listDir reports a symlinked directory as a symlink', () async {
      final outside = await Directory.systemTemp.createTemp('clide-walk-outside-');
      addTearDown(() => outside.deleteSync(recursive: true));
      File('${outside.path}/secret.txt').writeAsStringSync('s');
      Link('${root.path}/linked').createSync(outside.path);

      final entries = await listDir(root: root, dir: '', ignore: IgnoreSet([]));
      final linked = entries.singleWhere((e) => e.name == 'linked');
      expect(linked.isSymlink, isTrue);
      expect(linked.isDirectory, isTrue, reason: 'target type still reported for the UI');
    });

    test('walkFiles does not descend a symlinked directory', () async {
      final outside = await Directory.systemTemp.createTemp('clide-walk-outside-');
      addTearDown(() => outside.deleteSync(recursive: true));
      File('${outside.path}/secret.txt').writeAsStringSync('s');
      Link('${root.path}/linked').createSync(outside.path);

      final r = await walkFiles(root: root, ignore: IgnoreSet([]));
      expect(r.files.map((e) => e.path), isNot(contains('linked/secret.txt')));
    });

    test('a symlink cycle does not hang the walk', () async {
      Link('${root.path}/lib/loop').createSync(root.path);
      final r = await walkFiles(root: root, ignore: IgnoreSet([]));
      expect(r.truncated, isFalse);
      expect(r.files.map((e) => e.path), contains('README.md'));
    });

    test('a symlink to a file is emitted as a file entry, flagged', () async {
      Link('${root.path}/readme-link').createSync('${root.path}/README.md');
      final r = await walkFiles(root: root, ignore: IgnoreSet([]));
      final e = r.files.singleWhere((e) => e.path == 'readme-link');
      expect(e.isSymlink, isTrue);
      expect(e.isDirectory, isFalse);
    });
  });
}
