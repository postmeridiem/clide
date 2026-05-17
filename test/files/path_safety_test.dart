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
      expect(() => resolveUnderRoot(root, '../../../etc/passwd'), throwsA(isA<PathOutsideRoot>()));
    });

    test('rejects traversal that lands at filesystem root', () {
      expect(() => resolveUnderRoot(root, '../'), throwsA(isA<PathOutsideRoot>()));
    });

    test('rejects sibling-directory traversal', () {
      expect(() => resolveUnderRoot(root, '../sibling/file'), throwsA(isA<PathOutsideRoot>()));
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
        expect(() => resolveUnderRoot(root, '../${twin.uri.pathSegments.where((s) => s.isNotEmpty).last}/file'), throwsA(isA<PathOutsideRoot>()));
      } finally {
        if (twin.existsSync()) twin.deleteSync(recursive: true);
      }
    });

    test('PathOutsideRoot.toString embeds requested + resolved + root', () {
      final e = PathOutsideRoot('r', '/abs', '/root');
      expect(e.toString(), allOf(contains('r'), contains('/abs'), contains('/root')));
    });
  });

  group('resolveUnderRootFollowingSymlinks (T-102)', () {
    test('plain non-symlink file passes through with the resolved real path', () {
      final f = File('${root.path}/plain.txt')..writeAsStringSync('hello');
      final out = resolveUnderRootFollowingSymlinks(root, 'plain.txt');
      // Real-path may differ from root.path on hosts where systemTemp
      // is itself a symlink (macOS /tmp -> /private/tmp). Compare via
      // resolveSymbolicLinksSync on both sides.
      expect(out, f.resolveSymbolicLinksSync());
    });

    test('non-existent target returns the path-layer result (caller surfaces not-found)', () {
      final out = resolveUnderRootFollowingSymlinks(root, 'never-existed.txt');
      expect(out, endsWith('/never-existed.txt'));
    });

    test('rejects a symlink under the workspace whose target lives outside', () async {
      // Create an outside file the symlink will point at.
      final outside = await Directory.systemTemp.createTemp('clide_t102_outside_');
      addTearDown(() async {
        if (await outside.exists()) await outside.delete(recursive: true);
      });
      final secret = File('${outside.path}/secret.txt')..writeAsStringSync('payload');

      // Plant a symlink inside the workspace that targets the outside file.
      final link = Link('${root.path}/leak')..createSync(secret.path);
      expect(link.existsSync(), isTrue);

      expect(
        () => resolveUnderRootFollowingSymlinks(root, 'leak'),
        throwsA(isA<PathOutsideRoot>()),
      );
    });

    test('tolerates symlinks in the workspace root path itself', () {
      // Where systemTemp is itself a symlink (macOS), the realPath of a
      // file under root won't startWith root.absolute.path — but
      // resolveUnderRootFollowingSymlinks resolves the root too, so
      // the containment check still passes.
      File('${root.path}/under-root.txt').writeAsStringSync('ok');
      // No throw is the assertion.
      resolveUnderRootFollowingSymlinks(root, 'under-root.txt');
    });

    test('rejects a symlink-to-symlink chain whose final target is outside', () async {
      final outside = await Directory.systemTemp.createTemp('clide_t102_chain_');
      addTearDown(() async {
        if (await outside.exists()) await outside.delete(recursive: true);
      });
      final secret = File('${outside.path}/secret.txt')..writeAsStringSync('payload');
      // a -> b (under root) -> /outside/secret.txt
      Link('${root.path}/b').createSync(secret.path);
      Link('${root.path}/a').createSync('${root.path}/b');

      expect(
        () => resolveUnderRootFollowingSymlinks(root, 'a'),
        throwsA(isA<PathOutsideRoot>()),
      );
    });
  });
}
