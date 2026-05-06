import 'dart:io';

import 'package:clide/builtin/claude/src/tmux_session.dart' as tmux;
import 'package:test/test.dart';

class _RecordingRunner {
  final List<List<String>> calls = [];
  String stdout = '';
  int exitCode = 0;

  Future<ProcessResult> call(List<String> args) async {
    calls.add(List.of(args));
    return ProcessResult(0, exitCode, stdout, '');
  }
}

void main() {
  late _RecordingRunner runner;

  setUp(() {
    runner = _RecordingRunner();
    tmux.tmuxRunner = runner.call;
  });

  tearDown(() {
    // Restore the default runner so other tests aren't affected.
    tmux.tmuxRunner = (args) => Process.run('tmux', args);
  });

  group('killSession', () {
    test('invokes tmux kill-session on the clide socket', () async {
      await tmux.killSession('clide-claude-foo');
      expect(runner.calls, [
        ['-L', 'clide', 'kill-session', '-t', 'clide-claude-foo'],
      ]);
    });

    test('does not surface non-zero exit (session already gone)', () async {
      runner.exitCode = 1;
      await tmux.killSession('clide-claude-foo');
      expect(runner.calls, hasLength(1));
    });
  });

  group('listClideSessions', () {
    test('parses session names from tmux output', () async {
      runner.stdout = 'clide-claude-foo\nclide-claude-foo-1\nclide-claude-foo-2\n';
      final names = await tmux.listClideSessions();
      expect(names, ['clide-claude-foo', 'clide-claude-foo-1', 'clide-claude-foo-2']);
    });

    test('returns empty list when server is not running', () async {
      runner.exitCode = 1;
      final names = await tmux.listClideSessions();
      expect(names, isEmpty);
    });

    test('strips blank lines and whitespace', () async {
      runner.stdout = '\nclide-claude-foo\n\n  clide-claude-foo-1  \n';
      final names = await tmux.listClideSessions();
      expect(names, ['clide-claude-foo', 'clide-claude-foo-1']);
    });
  });

  group('reapSecondaries', () {
    test('kills only -<digits>-suffixed sessions, leaves primary alive', () async {
      runner.stdout = 'clide-claude-foo\nclide-claude-foo-1\nclide-claude-foo-2\n';
      await tmux.reapSecondaries('clide-claude-foo');

      // First call lists, then one kill per secondary.
      expect(runner.calls.first, ['-L', 'clide', 'list-sessions', '-F', '#{session_name}']);
      final kills = runner.calls.skip(1).toList();
      expect(kills, [
        ['-L', 'clide', 'kill-session', '-t', 'clide-claude-foo-1'],
        ['-L', 'clide', 'kill-session', '-t', 'clide-claude-foo-2'],
      ]);
    });

    test('ignores sessions for other repos', () async {
      runner.stdout = 'clide-claude-foo\nclide-claude-bar-1\nclide-claude-foo-1\n';
      await tmux.reapSecondaries('clide-claude-foo');
      final kills = runner.calls.skip(1).toList();
      expect(kills, [
        ['-L', 'clide', 'kill-session', '-t', 'clide-claude-foo-1'],
      ]);
    });

    test('no-op when there are no secondaries', () async {
      runner.stdout = 'clide-claude-foo\n';
      await tmux.reapSecondaries('clide-claude-foo');
      expect(runner.calls, hasLength(1)); // just the list call
    });
  });

  group('killAllForRepo', () {
    test('kills primary and every secondary for the repo', () async {
      runner.stdout = 'clide-claude-foo\nclide-claude-foo-1\nclide-claude-bar\n';
      await tmux.killAllForRepo('clide-claude-foo');
      final kills = runner.calls.skip(1).toList();
      expect(kills, [
        ['-L', 'clide', 'kill-session', '-t', 'clide-claude-foo'],
        ['-L', 'clide', 'kill-session', '-t', 'clide-claude-foo-1'],
      ]);
    });
  });
}
