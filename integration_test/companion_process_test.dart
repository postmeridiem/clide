import 'dart:io';

import 'package:clide/builtin/claude/src/session_naming.dart';
import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/clide_companion/src/companion_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// The kill switch against a **real `claude` process** (T-545, D-107).
///
/// `companion_lifecycle_test.dart` proves the controller calls `kill()`; it
/// cannot prove anything dies, because its process is a fake. The gap between
/// those two is `ClaudeStreamJsonProcess.kill()` — SIGTERM, then SIGKILL after
/// two seconds, awaiting the real exit — and only a real child can close it.
///
/// It lives here rather than in the fast suite because it needs `claude` on
/// PATH. No prompt is ever sent, so no quota is spent: the process starts, is
/// counted, and is killed.
///
/// Finding it by PID: the companion's session id is on the command line as
/// `--session-id <uuid>`, and that id is unique per spawn, so `pgrep -f` matches
/// exactly this child and nothing else on the machine.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<List<String>> pidsFor(String sessionId) async {
    final r = await Process.run('pgrep', ['-f', sessionId]);
    return r.stdout.toString().trim().split('\n').where((l) => l.isNotEmpty).toList();
  }

  testWidgets('turning the companion off leaves no claude process behind', (tester) async {
    final orch = ClaudeSessionOrchestrator();
    activeSessionOrchestrator = orch;
    addTearDown(() => activeSessionOrchestrator = null);

    late String sessionId;
    final companion = CompanionSessionController(orchestrator: orch, newSessionId: () => sessionId = companionSessionId());
    addTearDown(companion.shutdown);

    final root = Directory.current.path;

    await tester.runAsync(() async {
      await companion.sync(enabled: true, open: true, root: root);
      // `claude` takes a moment to be a process worth finding.
      await Future<void>.delayed(const Duration(seconds: 3));
    });

    final running = await tester.runAsync(() => pidsFor(sessionId));
    expect(running, hasLength(1), reason: 'exactly one companion process per workspace — not zero, and not two');

    await tester.runAsync(() async {
      await companion.sync(enabled: false, open: true, root: root);
      // kill() has already awaited the real exit; this only covers the gap
      // between the child dying and the kernel reaping it.
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });

    final left = await tester.runAsync(() => pidsFor(sessionId));
    expect(left, isEmpty, reason: 'off must mean off — a survivor keeps the primary session\'s quota pool at risk');
    expect(companion.running, isFalse);
  }, timeout: const Timeout(Duration(seconds: 90)));
}
