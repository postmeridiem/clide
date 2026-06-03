/// Tests for the clide-hosted agent bootstrap (Epic B / T-215..T-217, D-83).
library;

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

    test('lists only subsystems that dispatch today; not the unfinished status snapshot', () {
      final note = clideContextNote('/repo');
      expect(note, contains('git status'));
      expect(note, contains('editor active'));
      // `clide status` (T-221) and live pane reflection (Epic C) are not wired
      // yet — the note must not point the agent at a command that returns
      // nothing, mirroring the T-213 "never mislead an agent" guard.
      expect(note, isNot(contains('clide status')));
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
      final d = agentEnvDelta(
        workspaceRoot: '/repo',
        socketPath: '/run/clide/abc.sock',
        currentPath: '/usr/bin',
        clideCliDir: null,
      );
      expect(d['CLIDE_WORKSPACE'], '/repo');
      expect(d['CLIDE_SOCK'], '/run/clide/abc.sock');
    });

    test('leaves PATH untouched when clide is already resolvable (clideCliDir null)', () {
      final d = agentEnvDelta(
        workspaceRoot: '/repo',
        socketPath: '/s.sock',
        currentPath: '/usr/bin',
        clideCliDir: null,
      );
      expect(d.containsKey('PATH'), isFalse);
    });

    test('prepends the cli dir to PATH when given', () {
      final d = agentEnvDelta(
        workspaceRoot: '/repo',
        socketPath: '/s.sock',
        currentPath: '/usr/bin:/bin',
        clideCliDir: '/home/dev/.local/bin',
      );
      expect(d['PATH'], '/home/dev/.local/bin:/usr/bin:/bin');
    });

    test('sets PATH to just the cli dir when there is no current PATH', () {
      final d = agentEnvDelta(
        workspaceRoot: '/repo',
        socketPath: '/s.sock',
        currentPath: null,
        clideCliDir: '/opt/clide/bin',
      );
      expect(d['PATH'], '/opt/clide/bin');
    });
  });

  group('resolveClideCliDir (T-215)', () {
    test('returns null when clide already resolves on PATH (no PATH change needed)', () {
      final dir = resolveClideCliDir(
        currentPath: '/usr/bin:/home/dev/.local/bin',
        candidateDirs: const ['/repo/native/linux-x64'],
        isExecutableFile: (p) => p == '/home/dev/.local/bin/clide',
      );
      expect(dir, isNull);
    });

    test('returns the first candidate holding an executable clide when not on PATH', () {
      final dir = resolveClideCliDir(
        currentPath: '/usr/bin',
        candidateDirs: const ['/nope', '/repo/native/linux-x64', '/also'],
        isExecutableFile: (p) => p == '/repo/native/linux-x64/clide',
      );
      expect(dir, '/repo/native/linux-x64');
    });

    test('returns null when nothing holds clide', () {
      final dir = resolveClideCliDir(
        currentPath: '/usr/bin',
        candidateDirs: const ['/a', '/b'],
        isExecutableFile: (_) => false,
      );
      expect(dir, isNull);
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
  });
}
