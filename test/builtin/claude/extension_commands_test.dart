/// T-391: the claude builtin's command handlers must honor the D-6
/// exit-code contract — a failure is an ERROR envelope (non-zero CLI
/// exit), never `ok` with an `error` field a script can't detect.
/// `clide claude.agent.set-permission-mode bogus` exited 0 before this.
library;

import 'package:clide/builtin/claude/src/extension.dart';
import 'package:clide/clide.dart';
import 'package:clide/extension/extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ext = ClaudeExtension();
  CommandContribution cmd(String id) => ext.contributions.whereType<CommandContribution>().firstWhere((c) => c.id == id);

  group('failure paths return error envelopes (T-391, D-6)', () {
    // (command id, args, expected error kind)
    final cases = <(String, List<String>, String)>[
      ('claude.agent.show', [], IpcErrorKind.userError),
      ('claude.agent.hide', [], IpcErrorKind.userError),
      ('claude.agent.close', [], IpcErrorKind.userError),
      ('claude.agent.mute', [], IpcErrorKind.userError),
      ('claude.agent.unmute', [], IpcErrorKind.userError),
      ('claude.agent.inject-message', [], IpcErrorKind.userError),
      ('claude.agent.inject-message', ['some-id'], IpcErrorKind.userError),
      ('claude.agent.set-permission-mode', [], IpcErrorKind.userError),
      ('claude.agent.set-permission-mode', ['some-id'], IpcErrorKind.userError),
      ('claude.agent.set-permission-mode', ['some-id', 'bogus'], IpcErrorKind.userError),
      ('claude.mode.cycle', [], IpcErrorKind.notFound),
      ('claude.task.reassign', [], IpcErrorKind.userError),
      ('claude.team-chat.post', [], IpcErrorKind.userError),
      ('claude.agent.fork', [], IpcErrorKind.userError),
      // No orchestrator is wired in this test (extension not activated),
      // so a fork with a source id fails as unavailable tooling.
      ('claude.agent.fork', ['some-id'], IpcErrorKind.toolError),
    ];

    for (final (id, args, kind) in cases) {
      test('$id ${args.isEmpty ? '(no args)' : args.join(' ')} → $kind', () async {
        final r = await cmd(id).run(args);
        expect(r.ok, isFalse, reason: 'a failure must not report ok');
        expect(r.error!.kind, kind);
        expect(r.error!.code, isNot(0), reason: 'the CLI must exit non-zero');
      });
    }
  });
}
