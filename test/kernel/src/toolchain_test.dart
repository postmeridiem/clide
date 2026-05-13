/// Unit tests for `Toolchain` + `resolveToolchainPaths` in
/// `lib/kernel/src/toolchain.dart`.
library;

import 'dart:io';

import 'package:clide/kernel/src/toolchain.dart';
import 'package:test/test.dart';

void main() {
  group('Toolchain', () {
    test('default getters return the bare command name when unresolved', () {
      final t = Toolchain();
      expect(t.git, 'git');
      expect(t.pql, 'pql');
      expect(t.tmux, 'tmux');
      expect(t.shell, '/bin/bash');
      expect(t.resolved, isFalse);
      expect(t.allOk, isFalse);
      expect(t.missing, ['git', 'pql', 'tmux']);
    });

    test('applyResolved with full paths flips resolved + allOk + clears missing', () {
      final t = Toolchain();
      var calls = 0;
      t.addListener(() => calls++);
      t.applyResolved(const ResolvedPaths(
        git: '/usr/bin/git',
        pql: '/usr/bin/pql',
        tmux: '/usr/bin/tmux',
        shell: '/bin/bash',
        gitEnv: {'GIT_EXEC_PATH': '/usr/lib/git-core'},
      ));
      expect(t.resolved, isTrue);
      expect(t.allOk, isTrue);
      expect(t.missing, isEmpty);
      expect(t.gitEnv?['GIT_EXEC_PATH'], '/usr/lib/git-core');
      expect(t.git, '/usr/bin/git');
      expect(calls, 1);
    });

    test('applyResolved with only some tools resolved reports the rest as missing', () {
      final t = Toolchain();
      t.applyResolved(const ResolvedPaths(pql: '/usr/bin/pql'));
      expect(t.resolved, isTrue);
      expect(t.allOk, isFalse);
      expect(t.missing, ['git', 'tmux']);
    });

    test('waitForResolution completes immediately when already resolved', () async {
      final t = Toolchain();
      t.applyResolved(const ResolvedPaths());
      await t.waitForResolution(); // shouldn't hang
    });

    test('waitForResolution awaits applyResolved when not yet resolved', () async {
      final t = Toolchain();
      final f = t.waitForResolution();
      // Resolve on the next microtask.
      Future.microtask(() => t.applyResolved(const ResolvedPaths()));
      await f.timeout(const Duration(seconds: 1));
    });
  });

  group('Toolchain.resolvePaths (static)', () {
    test('returns a ResolvedPaths against the current workspace', () {
      final paths = Toolchain.resolvePaths(workspaceRoot: Directory.current.path);
      // Whatever was found, the result must be a ResolvedPaths.
      expect(paths, isA<ResolvedPaths>());
      // On this CI host pql is installed (per repo memory).
      expect(paths.pql, isNotNull);
    });

    test('uses the dugite git when present in the workspace', () {
      // The clide repo bundles dugite under native/dugite/bin/git.
      final paths = Toolchain.resolvePaths(workspaceRoot: Directory.current.path);
      final dugitePath = '${Directory.current.path}/native/dugite/bin/git';
      if (File(dugitePath).existsSync()) {
        expect(paths.git, dugitePath);
        expect(paths.gitEnv?['GIT_EXEC_PATH'], isNotNull);
      }
    });

    test('falls back to PATH git when no dugite is present', () {
      final paths = Toolchain.resolvePaths(workspaceRoot: '/tmp/clide-no-dugite-${DateTime.now().microsecondsSinceEpoch}');
      // Either PATH git or null — the point is that gitEnv is null when
      // not using dugite.
      if (paths.git != null) {
        expect(paths.gitEnv, isNull);
      }
    });
  });

  group('resolveToolchainPaths (top-level, for isolates)', () {
    test('matches Toolchain.resolvePaths shape', () {
      final viaStatic = Toolchain.resolvePaths(workspaceRoot: Directory.current.path);
      final viaTopLevel = resolveToolchainPaths(Directory.current.path);
      // Both must agree on the pql binary (or both null if missing).
      expect(viaTopLevel.pql, viaStatic.pql);
    });

    test('returns a ResolvedPaths for an arbitrary path', () {
      final paths = resolveToolchainPaths('/tmp/clide-arbitrary');
      expect(paths, isA<ResolvedPaths>());
    });
  });
}
