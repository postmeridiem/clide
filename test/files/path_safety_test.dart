import 'dart:io';

import 'package:clide/src/files/path_safety.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('clide_path_safety_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  group('resolveUnderRoot', () {
    test('plain relative path resolves under root', () {
      final out = resolveUnderRoot(root, 'file.txt');
      expect(out, '${root.absolute.path}/file.txt');
    });

    test('nested relative path resolves under root', () {
      final out = resolveUnderRoot(root, 'src/main.dart');
      expect(out, '${root.absolute.path}/src/main.dart');
    });

    test('empty relative path resolves to root itself', () {
      final out = resolveUnderRoot(root, '');
      expect(out, root.absolute.path);
    });

    test('rejects ../etc/passwd traversal', () {
      expect(() => resolveUnderRoot(root, '../../../etc/passwd'),
          throwsA(isA<PathOutsideRoot>()));
    });

    test('rejects traversal that lands at filesystem root', () {
      expect(() => resolveUnderRoot(root, '../'),
          throwsA(isA<PathOutsideRoot>()));
    });

    test('rejects sibling-directory traversal', () {
      expect(() => resolveUnderRoot(root, '../sibling/file'),
          throwsA(isA<PathOutsideRoot>()));
    });

    test('allows internal `..` that stays under root', () {
      final out = resolveUnderRoot(root, 'a/b/../c');
      expect(out, '${root.absolute.path}/a/c');
    });

    test('rejects path that prefix-matches root but is outside', () {
      // Sibling dir whose name starts with the root's last segment.
      // resolveUnderRoot must not be fooled by string-prefix matching.
      final twin = Directory('${root.parent.path}/${root.uri.pathSegments.where((s) => s.isNotEmpty).last}_twin');
      try {
        twin.createSync();
        expect(() => resolveUnderRoot(root, '../${twin.uri.pathSegments.where((s) => s.isNotEmpty).last}/file'),
            throwsA(isA<PathOutsideRoot>()));
      } finally {
        if (twin.existsSync()) twin.deleteSync(recursive: true);
      }
    });
  });
}
