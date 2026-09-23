/// Tests for the clide-hosted agent bootstrap (Epic B / T-215..T-217, D-83).
library;

import 'dart:io';

import 'package:clide/builtin/claude/src/agent_bootstrap.dart';
import 'package:clide/src/ipc/paths.dart' show workspaceSocketPath;
import 'package:test/test.dart';

void main() {
  group('clideContextNote (T-216)', () {
    test('names clide, the clide CLI, the env vars, and the parity contract', () {
      final note = clideContextNote('/home/dev/proj');
      expect(note, contains('inside clide'));
      expect(note, contains('clide <subsystem> <verb>'));
      expect(note, contains('CLIDE_WORKSPACE'));
      expect(note, contains('CLIDE_SOCK'));
      expect(note, contains('/home/dev/proj'));
      expect(note, contains('D-6'));
    });

    test('points at the live registry instead of copying it (T-585)', () {
      final note = clideContextNote('/repo');
      // The note must send the agent to the generated listing...
      expect(note, contains('clide capabilities'));
      // ...and say so in a way that stops it reading silence as absence, which
      // is how the old hand-maintained list misled: it advertised six
      // subsystems out of sixteen under "subsystems that respond today".
      expect(note, contains('never assume a verb is absent'));
    });

    test('carries no hand-maintained subsystem inventory to go stale (T-585)', () {
      final note = clideContextNote('/repo');
      expect(note, isNot(contains('respond today')), reason: 'a second copy of the command registry rots silently, in the direction of hiding features');
      // A spot-check on the shape rather than the wording: an inventory reads
      // as a run of comma-separated subsystem names. Naming one or two verbs in
      // passing is fine; enumerating the surface is what must not come back.
      const subsystems = ['canvas', 'clipboard', 'editor', 'env', 'files', 'git', 'icon', 'image', 'pane', 'panel', 'pql', 'search'];
      final named = subsystems.where((s) => note.contains('`$s`')).length;
      expect(named, lessThan(4), reason: 'the note names $named subsystems — that is an inventory, and inventories drift');
    });

    test('names the one occasion a capability listing cannot teach (T-585)', () {
      // `capabilities` says what exists, never when to reach for it. The
      // clipboard is the verb an agent never thinks to look up, because the
      // goal "put this on their clipboard" does not arise on its own.
      final note = clideContextNote('/repo');
      expect(note, contains('clide clipboard set'));
      expect(note, contains('shell command'));
    });
  });

  group('clideSkillsNote (T-490)', () {
    test('names both skills, nudges first-turn use, and stays short', () {
      final note = clideSkillsNote();
      expect(note, contains('`pql`'));
      expect(note, contains('`clide`'));
      expect(note, contains('from your first turn'));
      // Acceptance #4: a short nudge, not a wall of text crowding clideContextNote.
      expect(note.length, lessThan(360));
    });
  });

  group('clideBashAllowRule (T-217)', () {
    test('is the command-scoped Bash rule and rides on --allowedTools', () {
      expect(clideBashAllowRule, 'Bash(clide:*)');
      expect(clideAllowedToolsArgs, ['--allowedTools', 'Bash(clide:*)']);
    });
  });

  group('agentEnvDelta (T-215)', () {
    test('always exports CLIDE_SOCK + CLIDE_WORKSPACE', () {
      final d = agentEnvDelta(workspaceRoot: '/repo', socketPath: '/run/clide/abc.sock', currentPath: '/usr/bin', clideCliDir: null);
      expect(d['CLIDE_WORKSPACE'], '/repo');
      expect(d['CLIDE_SOCK'], '/run/clide/abc.sock');
    });

    test('leaves PATH untouched when clide is already resolvable (clideCliDir null)', () {
      final d = agentEnvDelta(workspaceRoot: '/repo', socketPath: '/s.sock', currentPath: '/usr/bin', clideCliDir: null);
      expect(d.containsKey('PATH'), isFalse);
    });

    test('prepends the cli dir to PATH when given', () {
      final d = agentEnvDelta(workspaceRoot: '/repo', socketPath: '/s.sock', currentPath: '/usr/bin:/bin', clideCliDir: '/home/dev/.local/bin');
      expect(d['PATH'], '/home/dev/.local/bin:/usr/bin:/bin');
    });

    test('sets PATH to just the cli dir when there is no current PATH', () {
      final d = agentEnvDelta(workspaceRoot: '/repo', socketPath: '/s.sock', currentPath: null, clideCliDir: '/opt/clide/bin');
      expect(d['PATH'], '/opt/clide/bin');
    });

    test('exports PATH for a preset even when clide is already resolvable (D-106)', () {
      final d = agentEnvDelta(workspaceRoot: '/repo', socketPath: '/s.sock', currentPath: '/usr/bin:/bin', clideCliDir: null, prependDirs: ['/opt/go/bin']);
      expect(d['PATH'], '/opt/go/bin:/usr/bin:/bin');
    });

    test('preset dirs come first, then the cli dir, then the current PATH (D-106)', () {
      final d = agentEnvDelta(
        workspaceRoot: '/repo',
        socketPath: '/s.sock',
        currentPath: '/usr/bin',
        clideCliDir: '/home/dev/.local/bin',
        prependDirs: ['/opt/go/bin', '/brew/bin'],
      );
      expect(d['PATH'], '/opt/go/bin:/brew/bin:/home/dev/.local/bin:/usr/bin');
    });

    test('a preset dir already on the current PATH is not duplicated (D-106)', () {
      final d = agentEnvDelta(
        workspaceRoot: '/repo',
        socketPath: '/s.sock',
        currentPath: '/opt/go/bin:/usr/bin',
        clideCliDir: null,
        prependDirs: ['/opt/go/bin'],
      );
      expect(d['PATH'], '/opt/go/bin:/usr/bin');
    });
  });

  group('resolveClideCli (T-215)', () {
    test('returns null when clide already resolves on PATH (no PATH change needed)', () {
      final cli = resolveClideCli(
        currentPath: '/usr/bin:/home/dev/.local/bin',
        candidates: const ['/opt/clide/clide-cli'],
        isExecutableFile: (p) => p == '/home/dev/.local/bin/clide',
      );
      expect(cli, isNull);
    });

    test('returns the first executable candidate when not on PATH', () {
      final cli = resolveClideCli(
        currentPath: '/usr/bin',
        candidates: const ['/nope/clide', '/opt/clide/clide-cli', '/also/clide'],
        isExecutableFile: (p) => p == '/opt/clide/clide-cli',
      );
      expect(cli, '/opt/clide/clide-cli');
    });

    test('returns null when nothing holds clide', () {
      expect(resolveClideCli(currentPath: '/usr/bin', candidates: const ['/a/clide', '/b/clide'], isExecutableFile: (_) => false), isNull);
    });
  });

  // T-603: the opened workspace never decides what `clide` the agent runs, and
  // only `clide` itself reaches its PATH.
  group('clideCliCandidates (T-603)', () {
    test('an installed app: the user install, then the bundled C client — never the workspace', () {
      final c = clideCliCandidates(home: '/home/u', executable: '/home/u/.local/lib/clide/clide', abi: 'linux-x64');
      expect(c, ['/home/u/.local/bin/clide', '/home/u/.local/lib/clide/clide-cli']);
      expect(c.any((p) => p.contains('/native/')), isFalse);
    });

    test('a build from a clide source tree adds that tree\'s own native client', () {
      final c = clideCliCandidates(home: '/home/u', executable: '/src/clide/build/linux/x64/debug/bundle/clide', abi: 'linux-x64');
      expect(c.last, '/src/clide/native/linux-x64/clide');
    });

    test('the bundle\'s own `clide` — the GUI — is never a candidate', () {
      final c = clideCliCandidates(home: null, executable: '/opt/clide/clide', abi: 'linux-x64');
      expect(c, ['/opt/clide/clide-cli']);
    });
  });

  group('exposeClideCli (T-603)', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('clide-cli-expose-'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('a dir holding only a `clide` link to the binary', () {
      final bin = File('${tmp.path}/pkg/clide-cli')..createSync(recursive: true);
      File('${tmp.path}/pkg/evil').createSync();
      final dir = exposeClideCli(bin.path, dir: '${tmp.path}/bin');
      expect(Directory(dir).listSync().map((e) => e.uri.pathSegments.last), ['clide']);
      expect(Link('$dir/clide').targetSync(), bin.path);
    });

    test('re-exposing another binary repoints the link', () {
      final a = File('${tmp.path}/a/clide')..createSync(recursive: true);
      final b = File('${tmp.path}/b/clide-cli')..createSync(recursive: true);
      exposeClideCli(a.path, dir: '${tmp.path}/bin');
      exposeClideCli(b.path, dir: '${tmp.path}/bin');
      expect(Link('${tmp.path}/bin/clide').targetSync(), b.path);
      exposeClideCli(b.path, dir: '${tmp.path}/bin'); // unchanged: no-op
      expect(Link('${tmp.path}/bin/clide').targetSync(), b.path);
    });
  });

  group('claudeConfigDirForWorkspace (T-484)', () {
    test('bound workspace → the account config dir', () {
      expect(claudeConfigDirForWorkspace(cwd: '/repo/a', boundConfigDir: (_) => '/home/u/.claude-work', env: const {}), '/home/u/.claude-work');
    });

    test('unbound + parent CLAUDE_CONFIG_DIR set → respects the launcher choice', () {
      expect(
        claudeConfigDirForWorkspace(cwd: '/repo/a', boundConfigDir: (_) => null, env: const {'CLAUDE_CONFIG_DIR': '/home/u/.claude-personal'}),
        '/home/u/.claude-personal',
      );
    });

    test('unbound + no parent env → null (Claude defaults to ~/.claude)', () {
      expect(claudeConfigDirForWorkspace(cwd: '/repo/a', boundConfigDir: (_) => null, env: const {}), isNull);
    });

    test('binding beats the parent env (binding > parent)', () {
      expect(claudeConfigDirForWorkspace(cwd: '/repo/a', boundConfigDir: (_) => '/bound', env: const {'CLAUDE_CONFIG_DIR': '/parent'}), '/bound');
    });

    test('an empty bound dir is ignored (falls through to parent / null)', () {
      expect(claudeConfigDirForWorkspace(cwd: '/r', boundConfigDir: (_) => '', env: const {'CLAUDE_CONFIG_DIR': '/parent'}), '/parent');
      expect(claudeConfigDirForWorkspace(cwd: '/r', boundConfigDir: (_) => '', env: const {}), isNull);
    });
  });

  group('agentBootstrap (IO wrapper)', () {
    test('socket in the delta matches workspaceSocketPath; allow rule in extraArgs', () {
      final b = agentBootstrap('/some/workspace');
      expect(b.envDelta['CLIDE_SOCK'], workspaceSocketPath('/some/workspace'));
      expect(b.envDelta['CLIDE_WORKSPACE'], '/some/workspace');
      expect(b.extraArgs, ['--allowedTools', 'Bash(clide:*)']);
    });

    test('merges over the provided base env', () {
      final b = agentBootstrap('/ws', base: {'FOO': 'bar'});
      expect(b.envDelta['FOO'], 'bar');
      expect(b.envDelta['CLIDE_WORKSPACE'], '/ws');
    });

    test('injects the bound workspace CLAUDE_CONFIG_DIR (T-484)', () {
      final b = agentBootstrap('/ws', boundConfigDir: (_) => '/home/u/.claude-work');
      expect(b.envDelta['CLAUDE_CONFIG_DIR'], '/home/u/.claude-work');
    });

    test('an explicit base CLAUDE_CONFIG_DIR override beats the workspace binding (T-484)', () {
      final b = agentBootstrap('/ws', base: {'CLAUDE_CONFIG_DIR': '/override'}, boundConfigDir: (_) => '/bound');
      expect(b.envDelta['CLAUDE_CONFIG_DIR'], '/override');
    });

    test('the workspace PATH preset lands at the head of the delta PATH (D-106)', () {
      final b = agentBootstrap('/ws', pathPreset: (cwd) => cwd == '/ws' ? ['/opt/go/bin'] : const []);
      expect(b.envDelta['PATH'], startsWith('/opt/go/bin:'));
    });

    test('no preset wired → bootstrap behaves as before (no gratuitous PATH export)', () {
      final emptyPreset = agentBootstrap('/ws', pathPreset: (_) => const []);
      final unwired = agentBootstrap('/ws');
      expect(emptyPreset.envDelta.containsKey('PATH'), unwired.envDelta.containsKey('PATH'));
    });
  });
}
