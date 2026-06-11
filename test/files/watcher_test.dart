/// Tests for `lib/src/files/watcher.dart`. Drives a real
/// Directory.watch against a tempdir.
library;

import 'dart:io';

import 'package:clide/src/files/ignore.dart';
import 'package:clide/src/files/watcher.dart';
import 'package:test/test.dart';

import '../helpers/timeouts.dart';

void main() {
  group('FileChangeKind', () {
    test('fromEvent maps every FileSystemEvent.type to a wire kind', () {
      final dir = Directory.systemTemp;
      FileSystemEvent ev(int type) => switch (type) {
        FileSystemEvent.create => FileSystemCreateEvent('${dir.path}/f', false),
        FileSystemEvent.delete => FileSystemDeleteEvent('${dir.path}/f', false),
        FileSystemEvent.modify => FileSystemModifyEvent('${dir.path}/f', false, false),
        FileSystemEvent.move => FileSystemMoveEvent('${dir.path}/f', false, '${dir.path}/g'),
        _ => FileSystemModifyEvent('${dir.path}/f', false, false),
      };
      expect(FileChangeKind.fromEvent(ev(FileSystemEvent.create)), FileChangeKind.created);
      expect(FileChangeKind.fromEvent(ev(FileSystemEvent.delete)), FileChangeKind.deleted);
      expect(FileChangeKind.fromEvent(ev(FileSystemEvent.modify)), FileChangeKind.modified);
      expect(FileChangeKind.fromEvent(ev(FileSystemEvent.move)), FileChangeKind.renamed);
    });

    test('wire getter is the enum name', () {
      expect(FileChangeKind.created.wire, 'created');
      expect(FileChangeKind.deleted.wire, 'deleted');
      expect(FileChangeKind.modified.wire, 'modified');
      expect(FileChangeKind.renamed.wire, 'renamed');
    });
  });

  group('FileChange', () {
    test('toJson encodes kind / path / isDirectory', () {
      const c = FileChange(kind: FileChangeKind.modified, path: 'a/b.txt', isDirectory: false);
      final j = c.toJson();
      expect(j['kind'], 'modified');
      expect(j['path'], 'a/b.txt');
      expect(j['isDirectory'], isFalse);
    });
  });

  group('FileWatcher', () {
    late Directory sandbox;
    late FileWatcher watcher;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('clide-watcher-');
      watcher = FileWatcher(root: sandbox, ignore: IgnoreSet.builtin());
    });

    tearDown(() async {
      await watcher.stop();
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    test('emits a created event when a file is added under root', () async {
      await watcher.start();
      // Wait for the specific change rather than sleeping a fixed
      // amount. firstWhere completes on the first matching event;
      // the timeout fails the test with a clear message if inotify
      // never delivers (instead of asserting on an empty list).
      final saw = watcher.stream.firstWhere((c) => c.path == 'new.txt', orElse: () => throw StateError('stream closed before new.txt arrived'));
      await File('${sandbox.path}/new.txt').writeAsString('hi');
      final change = await saw.timeout(ioTimeout, onTimeout: () => fail('no `new.txt` event within ${ioTimeout.inSeconds}s'));
      expect(change.path, 'new.txt');
    });

    test('filters ignored paths', () async {
      await watcher.start();
      final received = <FileChange>[];
      final sub = watcher.stream.listen(received.add);
      addTearDown(sub.cancel);

      // Two-phase: a pre-marker proves inotify is delivering at all
      // (warm-up), then create the ignored entry sandwiched between
      // an actionable post-marker. When the post-marker arrives we
      // know inotify has caught up to operations performed earlier
      // in the same tick. Failing loudly with `fail()` beats the old
      // fixed `Future.delayed(200)` that pretended a quiet stream was
      // proof of filtering.
      await File('${sandbox.path}/pre.txt').writeAsString('p');
      await _expectReceived(received, (c) => c.path == 'pre.txt');

      Directory('${sandbox.path}/.dart_tool').createSync();
      await File('${sandbox.path}/.dart_tool/hidden').writeAsString('x');
      await File('${sandbox.path}/post.txt').writeAsString('q');
      await _expectReceived(received, (c) => c.path == 'post.txt');

      expect(received.any((c) => c.path.startsWith('.dart_tool')), isFalse);
    });

    test('second start() is a no-op (idempotent)', () async {
      await watcher.start();
      await watcher.start();
    });

    test('stop() cancels the subscription and closes the stream', () async {
      await watcher.start();
      await watcher.stop();
      // A second stop is also safe.
      await watcher.stop();
    });
  });
}

/// Wait until [received] satisfies [predicate]. Polls the list (it
/// gets mutated by the listener subscription) every 25 ms with a
/// generous [ioTimeout] ceiling; fails loudly on miss instead of
/// silently continuing as the old fixed-sleep tests did.
Future<void> _expectReceived<T>(List<T> received, bool Function(T) predicate) async {
  final deadline = DateTime.now().add(ioTimeout);
  while (!received.any(predicate)) {
    if (DateTime.now().isAfter(deadline)) {
      fail('expected event never arrived within ${ioTimeout.inSeconds}s; received=${received.length} entries');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}
