/// Unit tests for the read-only file tail follower (T-325).
library;

import 'dart:convert';
import 'dart:io';

import 'package:clide/builtin/claude/src/file_tail_follower.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late File file;
  late List<String> chunks;
  FileTailFollower follower(File f) => FileTailFollower(f.path, tailBytes: 8, onData: (b) => chunks.add(utf8.decode(b)));

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('clide-tail-test-');
    file = File('${dir.path}/app.log');
    chunks = [];
  });
  tearDown(() async => dir.existsSync() ? dir.delete(recursive: true) : null);

  test('emits the trailing window on the first read, not the whole file', () async {
    file.writeAsStringSync('0123456789ABCDEF'); // 16 bytes, tailBytes=8
    final f = follower(file);
    await f.pollOnce();
    expect(chunks, ['89ABCDEF']); // last 8 bytes only
    f.stop();
  });

  test('emits only newly-appended bytes on subsequent reads', () async {
    file.writeAsStringSync('start');
    final f = follower(file);
    await f.pollOnce(); // primes at the tail
    chunks.clear();
    file.writeAsStringSync(' MORE', mode: FileMode.append);
    await f.pollOnce();
    expect(chunks, [' MORE']); // only the appended delta
    f.stop();
  });

  test('a missing file is tolerated until it appears', () async {
    final f = follower(File('${dir.path}/not-yet.log'));
    await f.pollOnce(); // no file → no emit, no throw
    expect(chunks, isEmpty);
    f.stop();
  });

  test('truncation/rotation re-reads from the top', () async {
    file.writeAsStringSync('aaaaaaaaaaaa'); // 12 bytes
    final f = follower(file);
    await f.pollOnce();
    chunks.clear();
    file.writeAsStringSync('XY'); // shrink to 2 bytes (rotated)
    await f.pollOnce();
    expect(chunks, ['XY']);
    f.stop();
  });

  test('start() emits the initial window and arms the poll', () async {
    file.writeAsStringSync('hello world'); // 11 bytes, tailBytes=8
    final f = follower(file);
    await f.start(); // awaits the initial pollOnce before arming the timer
    f.stop(); // tear the timer down before it fires
    expect(chunks, ['lo world']); // last 8 bytes
  });

  test('stop() makes further polls no-ops', () async {
    file.writeAsStringSync('hello');
    final f = follower(file);
    f.stop();
    await f.pollOnce();
    expect(chunks, isEmpty);
  });
}
