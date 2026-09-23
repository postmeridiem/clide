/// The one fake `claude` process for tests (T-638).
///
/// About seventeen local `_FakeProc` copies had drifted from the real
/// [ClaudeStreamJsonProcess] in ways that hid bugs:
///
///  * **`lines` was a broadcast stream.** The real one is stdout through a
///    decoder — single-subscription — so a second `listen` throws. The fakes
///    let double-listen bugs through.
///  * **`exitCode` was null** (the base-class default), so a session never saw
///    its process end and `ClaudePane._onSessionEnd` was unreachable. The real
///    process always has an exit code, and it completes when the child dies.
///  * **`kill()` returned at once.** The real one waits for the child to
///    actually exit (T-437), and the exit then fires like any other.
///
/// This fake keeps all three: [lines] is single-subscription and closes when
/// the process exits, [exitCode] is never null, and [kill] ends the process
/// (code [killedExitCode], SIGTERM's -15) and returns only once it has.
///
/// Flutter-free, so suites under plain `dart test` can use it too.
library;

import 'dart:async';
import 'dart:convert';

import 'package:clide/builtin/claude/src/stream_json_session.dart';

class FakeStreamJsonProcess extends StreamJsonProcess {
  /// [killGate] models a child slow to die: [kill] doesn't end the process
  /// until it completes, so a test can prove its caller waits for the real
  /// exit (T-437).
  FakeStreamJsonProcess({List<String> stderrTail = const [], this.killGate, this.onWrite}) : stderr = [...stderrTail];

  final Future<void>? killGate;

  /// Called on every [writeLine], after it is recorded.
  void Function(String line)? onWrite;

  /// What a killed child exits with: SIGTERM, as `Process.exitCode` reports it.
  static const int killedExitCode = -15;

  final _out = StreamController<String>();
  final _exit = Completer<int>();

  /// The child's stderr tail; tests append to it before an exit.
  final List<String> stderr;

  /// Every line written to stdin, in order.
  final List<String> writes = [];

  /// Lines written after the process had exited — the real pipe would
  /// reject them, so a test can assert none were sent.
  final List<String> writesAfterExit = [];

  /// How many times [kill] was called.
  int killCount = 0;

  bool get killed => killCount > 0;

  /// Whether the process has exited (on its own via [exit], or by [kill]).
  bool get exited => _exit.isCompleted;

  /// stdout, one JSON event per line. Single-subscription, like the real
  /// process's decoded stdout: listening twice throws.
  @override
  Stream<String> get lines => _out.stream;

  @override
  void writeLine(String line) {
    writes.add(line);
    if (exited) writesAfterExit.add(line);
    onWrite?.call(line);
  }

  /// [writes] decoded, for asserting on protocol messages.
  List<Map<String, Object?>> get writtenMessages => [for (final w in writes) (jsonDecode(w) as Map).cast<String, Object?>()];

  @override
  Future<void> kill() async {
    killCount++;
    final gate = killGate;
    if (gate != null) await gate;
    exit(killedExitCode);
    await _exit.future;
  }

  @override
  List<String> get stderrTail => List.unmodifiable(stderr);

  @override
  Future<int> get exitCode => _exit.future;

  /// Emit one stdout line. Ignored once the process has exited.
  void emitLine(String line) {
    if (!_out.isClosed) _out.add(line);
  }

  /// Emit one stdout event as a JSON line.
  void emit(Map<String, Object?> event) => emitLine(jsonEncode(event));

  /// The child exits with [code]: stdout closes (EOF) and [exitCode]
  /// completes. Idempotent — only the first exit counts.
  void exit([int code = 0]) {
    if (_exit.isCompleted) return;
    unawaited(_out.close());
    _exit.complete(code);
  }
}
