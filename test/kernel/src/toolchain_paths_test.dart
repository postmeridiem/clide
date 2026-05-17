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
}
