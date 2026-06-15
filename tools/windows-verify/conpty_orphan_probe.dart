/// ConPTY orphan probe — the ABRUPT-DEATH half of the windows-verify kit.
///
/// `soak-conpty.ps1` measures the CLEAN path: dart exits normally, the ConPTY
/// teardown (`close()` → ClosePseudoConsole → handle release) runs, and the
/// hosts are reaped. On GitHub's windows-latest that path showed NO leak —
/// orderly shutdown reclaims everything. But the freeze hypothesis (T-424) is
/// not about orderly shutdown; it is about the parent dying WITHOUT teardown
/// (a crash, a Ctrl-C, a wedged reader isolate) while the child is still live.
///
/// This probe exercises exactly that. It starts [count] real [WindowsPty]
/// sessions — the production backend, no mocks — each running a long-lived
/// child, prints a READY line carrying the dart pid + each child pid, then
/// blocks forever and NEVER calls `close()`. Its companion driver
/// (`soak-conpty-kill.ps1`) force-kills this dart.exe (`taskkill /F`, NOT
/// `/T`, so only the parent dies) once the children are up, then counts the
/// conhost / OpenConsole / cmd processes that SURVIVE the parent's death.
///
/// Because the children are not placed in a kill-on-close Job Object, abrupt
/// parent death is expected to orphan them — that is the leak this probe is
/// built to expose. The same probe will later PROVE the T-424 fix: once each
/// child lives in a JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE job, killing the
/// parent should take the job — and every host — down with it, and the
/// survivor count should drop to zero.
library;

import 'dart:io';

import 'package:clide/src/pty/pty_log.dart';
import 'package:clide/src/pty/windows_pty.dart';

Future<void> main(List<String> args) async {
  if (!Platform.isWindows) {
    stderr.writeln('conpty_orphan_probe: Windows only (ConPTY).');
    exit(2);
  }
  final count = args.isNotEmpty ? (int.tryParse(args.first) ?? 1) : 1;

  // When CLIDE_LOG_DIR is set (the soak workflow sets it), emit FFI breadcrumbs
  // so that when soak-conpty-kill.ps1 force-kills this process mid-life, the
  // reader/waiter isolates' LAST crumb (e.g. "ReadFile enter") is on disk —
  // CI then uploads it, naming what the reader was doing when killed (T-436).
  final logDir = Platform.environment['CLIDE_LOG_DIR'];
  final ptyLog = (logDir == null || logDir.isEmpty) ? PtyLog.none : PtyLog(crumbPath: '$logDir/clide-pty.crumbs.log', verbose: true);

  final sessions = <WindowsPty>[];
  for (var i = 0; i < count; i++) {
    final s = WindowsPty.start(
      executable: 'cmd.exe',
      // A long-lived child so the ConPTY host stays alive across the whole
      // kill window. `ping -n 600` loops for ~10 min with no extra deps.
      arguments: ['/c', 'ping -n 600 127.0.0.1'],
      columns: 80,
      rows: 24,
      environment: {...Platform.environment, 'TERM': 'xterm-256color'},
      log: ptyLog,
    );
    // Drain output so the reader isolate is actively pumping, closest to a
    // real live pane. Discard the bytes.
    s.output.listen((_) {}, onError: (_) {});
    sessions.add(s);
  }

  // Signal the driver that the children are up. It waits for the host count
  // to rise, then kills us.
  stdout.writeln('PROBE READY dart_pid=$pid child_pids=${sessions.map((s) => s.pid).join(',')}');
  await stdout.flush();

  // Block WITHOUT ever calling close() — the driver kills us mid-sleep. That
  // missing teardown is the entire point; do not add a finally/close here.
  await Future<void>.delayed(const Duration(minutes: 10));
  exit(0);
}
