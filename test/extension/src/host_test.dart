import 'dart:io';

import 'package:clide/extension/extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExtensionScanner', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('clide_ext_');
    });

    tearDown(() async {
      try {
        await root.delete(recursive: true);
      } catch (_) {}
    });

    test('returns empty when directory is missing', () async {
      final absent = Directory('${root.path}/absent');
      final out = await const ExtensionScanner().discover(root: absent);
      expect(out, isEmpty);
    });

    test('returns empty when directory exists but has no extensions', () async {
      final out = await const ExtensionScanner().discover(root: root);
      expect(out, isEmpty);
    });

    test('discovers extensions from their own subdirs', () async {
      final a = Directory('${root.path}/ext.a')..createSync();
      await File('${a.path}/manifest.yaml').writeAsString('id: ext.a\ntitle: A\nversion: 1.0.0\n');
      final b = Directory('${root.path}/ext.b')..createSync();
      await File('${b.path}/manifest.yaml').writeAsString('id: ext.b\ntitle: B\nversion: 1.2.0\n');
      final out = await const ExtensionScanner().discover(root: root);
      expect(out.map((m) => m.id).toSet(), {'ext.a', 'ext.b'});
    });

    test('skips a subdir without a manifest.yaml', () async {
      final a = Directory('${root.path}/ext.a')..createSync();
      await File('${a.path}/README.md').writeAsString('no manifest');
      final out = await const ExtensionScanner().discover(root: root);
      expect(out, isEmpty);
    });

    test('skips malformed manifests (non-fatal)', () async {
      final bad = Directory('${root.path}/ext.bad')..createSync();
      await File('${bad.path}/manifest.yaml').writeAsString('not a map');
      final ok = Directory('${root.path}/ext.ok')..createSync();
      await File('${ok.path}/manifest.yaml').writeAsString('id: ext.ok');
      final out = await const ExtensionScanner().discover(root: root);
      expect(out.map((m) => m.id).toList(), ['ext.ok']);
    });
  });
}
