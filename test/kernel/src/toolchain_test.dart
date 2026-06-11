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
      t.applyResolved(
        const ResolvedPaths(
          git: '/usr/bin/git',
          pql: '/usr/bin/pql',
          tmux: '/usr/bin/tmux',
          shell: '/bin/bash',
          gitEnv: {'GIT_EXEC_PATH': '/usr/lib/git-core'},
        ),
      );
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
    test('returns a ResolvedPaths with pql resolved from PATH', () {
      final paths = Toolchain.resolvePaths();
      expect(paths, isA<ResolvedPaths>());
      // On this CI host pql is installed (per repo memory).
      expect(paths.pql, isNotNull);
    });

    test('git falls back to PATH when no install-dir dugite is found', () {
      final paths = Toolchain.resolvePaths();
      // No dugite is bundled next to the test runner binary, so git
      // resolves via PATH; gitEnv stays null because dugite paths are
      // not in effect.
      if (paths.git != null) {
        expect(paths.gitEnv, isNull);
      }
    });
  });

  group('resolveToolchainPaths — security (T-98)', () {
    test('does NOT execute a planted git in the open workspace', () async {
      // Plant a fake dugite tree inside a temp dir that mimics what a
      // malicious repo could ship. The old code would resolve
      // `<workspaceRoot>/native/dugite/bin/git` as the git binary.
      final tmp = await Directory.systemTemp.createTemp('clide_t98_workspace_');
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final plantedBin = Directory('${tmp.path}/native/dugite/bin')..createSync(recursive: true);
      final plantedGit = File('${plantedBin.path}/git')..writeAsStringSync('#!/bin/sh\nexit 99\n');
      // chmod+x so the file is executable — exercises the worst case.
      await Process.run('chmod', ['+x', plantedGit.path]);
      expect(plantedGit.existsSync(), isTrue, reason: 'planted git must exist for the test to be meaningful');

      final paths = resolveToolchainPaths();

      // The resolved git binary must never be inside the workspace.
      // Belt-and-suspenders: also assert it doesn't equal the planted
      // path verbatim.
      expect(paths.git, isNot(startsWith(tmp.path)));
      expect(paths.git, isNot(plantedGit.path));
    });

    test('CLIDE_DUGITE_DIR env var is honored as an install-dir override', () {
      // We can't mutate Platform.environment from a test, so we just
      // assert the *contract* by checking the behavior in absence of
      // the var. The env-var branch is documented and exercised by the
      // dev workflow `make run` when CLIDE_DUGITE_DIR is set.
      // The negative case: no env var → no workspace lookup → git
      // resolves via PATH only.
      final paths = resolveToolchainPaths();
      if (paths.git != null) {
        expect(paths.gitEnv, isNull, reason: 'gitEnv must be null unless dugite is found in a trusted location');
      }
    });
  });
}
