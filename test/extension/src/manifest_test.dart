import 'package:clide/extension/extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExtensionManifest.fromYamlString', () {
    test('parses the minimum viable manifest', () {
      final m = ExtensionManifest.fromYamlString('''
id: ext.postmeridiem.linear
title: Linear
version: 1.2.3
entry: main.lua
schema_version: 1
''');
      expect(m.id, 'ext.postmeridiem.linear');
      expect(m.title, 'Linear');
      expect(m.version, '1.2.3');
      expect(m.entry, 'main.lua');
      expect(m.schemaVersion, 1);
      expect(m.dependsOn, isEmpty);
    });

    test('title defaults to id when absent', () {
      final m = ExtensionManifest.fromYamlString('id: ext.x');
      expect(m.title, 'ext.x');
      expect(m.version, '0.0.0');
      expect(m.entry, 'extension.lua');
      expect(m.schemaVersion, 1);
    });

    test('depends_on list is captured', () {
      final m = ExtensionManifest.fromYamlString('''
id: ext.a
depends_on:
  - builtin.git
  - builtin.diff
''');
      expect(m.dependsOn, ['builtin.git', 'builtin.diff']);
    });

    test('non-string depends_on entries are filtered out', () {
      final m = ExtensionManifest.fromYamlString('''
id: ext.x
depends_on: [builtin.git, 42, builtin.diff]
''');
      expect(m.dependsOn, ['builtin.git', 'builtin.diff']);
    });

    test('missing id throws FormatException', () {
      expect(
        () => ExtensionManifest.fromYamlString('title: Floating'),
        throwsA(isA<FormatException>()),
      );
    });

    test('empty id throws FormatException', () {
      expect(
        () => ExtensionManifest.fromYamlString('id: ""'),
        throwsA(isA<FormatException>()),
      );
    });

    test('non-map root throws FormatException', () {
      expect(
        () => ExtensionManifest.fromYamlString('- just a list'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
