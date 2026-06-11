/// Tests for the `search.*` command handlers (T-52 / D-79).
library;

import 'dart:io';

import 'package:clide/clide.dart';
import 'package:clide/src/daemon/search_commands.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late RecordingEventSink sink;
  late DaemonDispatcher d;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('clide-search-cmd-');
    File('${dir.path}/a.dart').writeAsStringSync('final answer = 42;\n');
    File('${dir.path}/b.dart').writeAsStringSync('// no hits here\n');
    sink = RecordingEventSink();
    final service = SearchService(root: dir, ignore: IgnoreSet([]), events: sink, useIsolates: false);
    d = DaemonDispatcher();
    registerSearchCommands(d, service);
  });
  tearDown(() async => dir.delete(recursive: true));

  Future<IpcResponse> call(String cmd, Map<String, Object?> args) => d.dispatch(IpcRequest(id: '1', cmd: cmd, args: args));

  test('search.grep returns a searchId and streams match + done', () async {
    // Subscribe before dispatching: the result events are broadcast and
    // can fire before a post-call listener would attach.
    final doneFuture = sink.stream.firstWhere((e) => e.kind == 'search.done');
    final r = await call('search.grep', const {'pattern': 'answer'});
    expect(r.ok, isTrue);
    final id = r.data['searchId'] as String;

    final done = await doneFuture;
    expect(done.data['searchId'], id);
    expect(done.data['cancelled'], isFalse);

    final matches = sink.events.where((e) => e.kind == 'search.match').toList();
    expect(matches, isNotEmpty);
    final batch = (matches.first.data['matches'] as List).cast<Map>();
    expect(batch.first['path'], 'a.dart');
    expect(batch.first['line'], 1);
  });

  test('search.grep with no matches still emits done', () async {
    final doneFuture = sink.stream.firstWhere((e) => e.kind == 'search.done');
    await call('search.grep', const {'pattern': 'zzz-not-present'});
    final done = await doneFuture;
    expect(done.data['cancelled'], isFalse);
    expect(sink.events.where((e) => e.kind == 'search.match'), isEmpty);
  });

  test('empty pattern is a userError', () async {
    final r = await call('search.grep', const {'pattern': ''});
    expect(r.ok, isFalse);
    expect(r.error!.kind, IpcErrorKind.userError);
  });

  test('invalid regex emits a search.error event', () async {
    final errFuture = sink.stream.firstWhere((e) => e.kind == 'search.error');
    final r = await call('search.grep', const {'pattern': '(unclosed', 'regex': true});
    expect(r.ok, isTrue); // the request is accepted; the error streams
    final err = await errFuture;
    expect(err.data['message'], contains('invalid regex'));
  });

  test('search.cancel requires a searchId', () async {
    final r = await call('search.cancel', const {});
    expect(r.ok, isFalse);
    expect(r.error!.kind, IpcErrorKind.userError);
  });

  test('search.cancel acks a (possibly finished) id', () async {
    final r = await call('search.cancel', const {'searchId': 'search-0'});
    expect(r.ok, isTrue);
    expect(r.data['cancelled'], 'search-0');
  });

  test('search.replace preview reports edits without touching disk', () async {
    final r = await call('search.replace', const {'pattern': 'answer', 'replacement': 'result'});
    expect(r.ok, isTrue);
    expect(r.data['apply'], isFalse);
    expect(r.data['fileCount'], 1);
    expect(r.data['totalCount'], 1);
    // File is untouched.
    expect(File('${dir.path}/a.dart').readAsStringSync(), 'final answer = 42;\n');
  });

  test('search.replace apply rewrites the matching files', () async {
    final r = await call('search.replace', const {'pattern': 'answer', 'replacement': 'result', 'apply': true});
    expect(r.ok, isTrue);
    expect(r.data['apply'], isTrue);
    expect(r.data['filesChanged'], 1);
    expect(File('${dir.path}/a.dart').readAsStringSync(), 'final result = 42;\n');
  });

  test('search.replace with an empty pattern is a userError', () async {
    final r = await call('search.replace', const {'pattern': '', 'replacement': 'x'});
    expect(r.ok, isFalse);
    expect(r.error!.kind, IpcErrorKind.userError);
  });

  test('search.replace with an invalid regex is a userError', () async {
    final r = await call('search.replace', const {'pattern': '(bad', 'regex': true, 'replacement': 'x'});
    expect(r.ok, isFalse);
    expect(r.error!.kind, IpcErrorKind.userError);
  });
}
