import 'dart:io';

import 'package:clide/clide.dart';
import 'package:test/test.dart';

void main() {
  group('defaultSocketPath', () {
    final originalXdg = Platform.environment['XDG_RUNTIME_DIR'];
    final originalUser = Platform.environment['USER'];

    test('uses XDG_RUNTIME_DIR when set', () {
      // We can't mutate Platform.environment from dart:io, so this test
      // just asserts the path shape for the current env. CI and dev
      // boxes both have meaningful USER values.
      final path = defaultSocketPath();
      expect(path, endsWith('.sock'));
      expect(path, contains('clide-'));
      if (originalXdg != null && originalXdg.isNotEmpty) {
        expect(path, startsWith(originalXdg));
      } else {
        expect(path, startsWith('/tmp'));
      }
      if (originalUser != null && originalUser.isNotEmpty) {
        expect(path, contains('clide-$originalUser'));
      }
    });
  });
}
