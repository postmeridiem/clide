import 'dart:io';

import 'package:clide/src/editor/editor_settings_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('resolveEditorSettings', () {
    late Directory root;
    setUp(() async => root = await Directory.systemTemp.createTemp('clide-ec-resolve-'));
    tearDown(() => root.deleteSync(recursive: true));

    test('composes from the .editorconfig source', () async {
      await File('${root.path}/.editorconfig').writeAsString('root = true\n[*]\nindent_style = space\nindent_size = 2\n');
      final s = resolveEditorSettings(root, 'lib/a.dart');
      expect(s.indentStyle, 'space');
      expect(s.indentSize, 2);
    });

    test('no source resolves to empty settings', () async {
      expect(resolveEditorSettings(root, 'a.txt').isEmpty, isTrue);
    });
  });
}
