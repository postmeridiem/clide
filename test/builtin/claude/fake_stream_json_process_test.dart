/// Pins the shared fake to the real process contract (T-638), so it can't
/// drift the way the per-file copies did.
library;

import 'dart:async';

import 'package:test/test.dart';

import '../../helpers/fake_stream_json_process.dart';

void main() {
  test('lines is single-subscription, like decoded stdout', () {
    final p = FakeStreamJsonProcess();
    p.lines.listen((_) {});
    expect(() => p.lines.listen((_) {}), throwsStateError);
  });

  test('exitCode is never null and completes when the process exits', () async {
    final p = FakeStreamJsonProcess();
    expect(p.exitCode, isNotNull);
    var done = false;
    unawaited(p.exitCode.then((_) => done = true));
    await pumpEventQueue();
    expect(done, isFalse);
    p.exit(3);
    expect(await p.exitCode, 3);
  });

  test('exiting closes stdout', () async {
    final p = FakeStreamJsonProcess();
    final got = <String>[];
    final closed = p.lines.listen(got.add).asFuture<void>();
    p.emit({'type': 'system'});
    p.exit();
    await closed;
    expect(got, ['{"type":"system"}']);
  });

  test('kill ends the process with SIGTERM\'s code and waits for it', () async {
    final p = FakeStreamJsonProcess();
    await p.kill();
    expect(p.exited, isTrue);
    expect(await p.exitCode, FakeStreamJsonProcess.killedExitCode);
    expect(p.killCount, 1);
  });

  test('a kill gate holds the exit until it opens', () async {
    final gate = Completer<void>();
    final p = FakeStreamJsonProcess(killGate: gate.future);
    var returned = false;
    unawaited(p.kill().then((_) => returned = true));
    await pumpEventQueue();
    expect(returned, isFalse);
    expect(p.exited, isFalse);
    gate.complete();
    await pumpEventQueue();
    expect(returned, isTrue);
    expect(p.exited, isTrue);
  });

  test('onWrite sees every line', () {
    final seen = <String>[];
    FakeStreamJsonProcess(onWrite: seen.add).writeLine('x');
    expect(seen, ['x']);
  });

  test('only the first exit counts', () async {
    final p = FakeStreamJsonProcess()..exit(1);
    await p.kill();
    expect(await p.exitCode, 1);
  });

  test('writes are recorded, and ones after exit are flagged', () {
    final p = FakeStreamJsonProcess()..writeLine('{"a":1}');
    p.exit();
    p.writeLine('{"b":2}');
    expect(p.writtenMessages, [
      {'a': 1},
      {'b': 2},
    ]);
    expect(p.writesAfterExit, ['{"b":2}']);
  });

  test('lines emitted after exit are dropped', () async {
    final p = FakeStreamJsonProcess();
    final got = <String>[];
    final done = p.lines.listen(got.add).asFuture<void>();
    p.exit();
    p.emitLine('late');
    await done;
    expect(got, isEmpty);
  });
}
