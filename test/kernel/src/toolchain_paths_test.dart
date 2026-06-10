/// Unit tests for `ToolchainView.resolved` (the Flutter-free `_StaticToolchain`)
/// in `lib/kernel/src/toolchain_paths.dart`. The listenable `Toolchain` and the
/// top-level `resolveToolchainPaths` are covered by `toolchain_test.dart`.
library;

import 'package:clide/kernel/src/toolchain_paths.dart';
import 'package:test/test.dart';

void main() {
  group('ToolchainView.resolved', () {
    test('exposes the supplied paths verbatim', () {
      final v = ToolchainView.resolved(const ResolvedPaths(
        git: '/opt/git',
        pql: '/opt/pql',
        tmux: '/opt/tmux',
        shell: '/usr/bin/zsh',
        gitEnv: {'GIT_EXEC_PATH': '/opt/git-core'},
      ));
      expect(v.git, '/opt/git');
      expect(v.pql, '/opt/pql');
      expect(v.tmux, '/opt/tmux');
      expect(v.shell, '/usr/bin/zsh');
      expect(v.gitEnv, {'GIT_EXEC_PATH': '/opt/git-core'});
      expect(v.resolved, isTrue);
      expect(v.allOk, isTrue);
      expect(v.missing, isEmpty);
    });

    test('falls back to bare command names when paths are null', () {
      final v = ToolchainView.resolved(const ResolvedPaths());
      expect(v.git, 'git');
      expect(v.pql, 'pql');
      expect(v.tmux, 'tmux');
      expect(v.shell, '/bin/bash');
      expect(v.gitEnv, isNull);
      expect(v.resolved, isTrue);
      expect(v.allOk, isFalse);
      expect(v.missing, ['git', 'pql', 'tmux']);
    });

    test('missing reports only the unresolved tools', () {
      final v = ToolchainView.resolved(const ResolvedPaths(
        git: '/opt/git',
        // pql + tmux null → missing.
      ));
      expect(v.missing, ['pql', 'tmux']);
      expect(v.allOk, isFalse);
    });
  });

  group('expandToolPath (T-347)', () {
    const minimal = '/usr/bin:/bin'; // a desktop-launch PATH, no ~/.local/bin

    test('Linux prepends ~/.local/bin + /usr/local/bin (desktop-launch fix)', () {
      final out = expandToolPath(minimal, isMac: false, isLinux: true, home: '/home/u');
      expect(out, '/home/u/.local/bin:/usr/local/bin:/usr/bin:/bin');
      // No homebrew dirs on Linux.
      expect(out.contains('/opt/homebrew'), isFalse);
    });

    test('macOS also adds the homebrew dirs', () {
      final out = expandToolPath(minimal, isMac: true, isLinux: false, home: '/Users/u');
      expect(out.split(':'), containsAll(['/Users/u/.local/bin', '/opt/homebrew/bin', '/opt/homebrew/sbin', '/usr/local/bin']));
    });

    test('does not duplicate dirs already on PATH', () {
      final base = '/home/u/.local/bin:/usr/local/bin:/usr/bin';
      expect(expandToolPath(base, isMac: false, isLinux: true, home: '/home/u'), base);
    });

    test('skips ~/.local/bin when HOME is empty', () {
      final out = expandToolPath(minimal, isMac: false, isLinux: true, home: '');
      expect(out, '/usr/local/bin:/usr/bin:/bin');
    });

    test('other platforms pass PATH through unchanged', () {
      expect(expandToolPath(minimal, isMac: false, isLinux: false, home: '/home/u'), minimal);
    });
  });
}
