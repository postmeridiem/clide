import 'dart:io';

import 'package:clide/src/ipc/paths.dart';
import 'package:test/test.dart';

void main() {
  group('workspaceSocketPath (D-70)', () {
    test('returns the FNV-1a hashed path under the socket directory', () {
      final p = workspaceSocketPath('/home/me/projects/clide');
      expect(p, startsWith('${socketDirectory()}/'));
      expect(p, endsWith('.sock'));
      // 16-char hex hash.
      final hash = p.split('/').last.replaceAll('.sock', '');
      expect(hash, matches(RegExp(r'^[0-9a-f]{16}$')));
    });

    test('is deterministic for the same input', () {
      expect(
        workspaceSocketPath('/home/me/repo'),
        workspaceSocketPath('/home/me/repo'),
      );
    });

    test('different workspace roots hash to different paths', () {
      expect(
        workspaceSocketPath('/home/me/repo-a'),
        isNot(workspaceSocketPath('/home/me/repo-b')),
      );
    });

    test('socketDirectory uses XDG_RUNTIME_DIR on Linux when set', () {
      if (Platform.isMacOS) return;
      final xdg = Platform.environment['XDG_RUNTIME_DIR'];
      if (xdg != null && xdg.isNotEmpty) {
        expect(socketDirectory(), '$xdg/clide');
      } else {
        expect(socketDirectory(), '/tmp/clide');
      }
    });

    test('socketDirectory uses ~/Library/Caches on macOS', () {
      if (!Platform.isMacOS) return;
      final home = Platform.environment['HOME']!;
      expect(socketDirectory(), '$home/Library/Caches/clide');
    });
  });

  group('fnv1a64Hex (T-126 cross-check)', () {
    // Reference values from <http://isthe.com/chongo/tech/comp/fnv/>.
    // The C client in native/clide-cli/clide.c MUST produce the same
    // 16-char hex strings for the same inputs, or server + client see
    // different socket paths and the integration falls apart silently.
    test('empty string → offset basis', () {
      expect(fnv1a64Hex(''), 'cbf29ce484222325');
    });

    test('"a" → reference value', () {
      expect(fnv1a64Hex('a'), 'af63dc4c8601ec8c');
    });

    test('"foo" → reference value', () {
      expect(fnv1a64Hex('foo'), 'dcb27518fed9d577');
    });

    test('"/home/me/projects/clide" → 16 hex chars, deterministic', () {
      final h = fnv1a64Hex('/home/me/projects/clide');
      expect(h, matches(RegExp(r'^[0-9a-f]{16}$')));
      expect(fnv1a64Hex('/home/me/projects/clide'), h);
    });
  });
}
