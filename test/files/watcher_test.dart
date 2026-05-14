/// Tests for `lib/src/files/watcher.dart`. Drives a real
/// Directory.watch against a tempdir.
library;

import 'dart:async';
import 'dart:io';

import 'package:clide/src/files/ignore.dart';
import 'package:clide/src/files/watcher.dart';
import 'package:test/test.dart';

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
      final received = <FileChange>[];
      final sub = watcher.stream.listen(received.add);
      addTearDown(sub.cancel);
      // Give inotify a moment to settle, then create a file.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await File('${sandbox.path}/new.txt').writeAsString('hi');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(received.any((c) => c.path == 'new.txt'), isTrue);
    });

    test('filters ignored paths', () async {
      await watcher.start();
      final received = <FileChange>[];
      final sub = watcher.stream.listen(received.add);
      addTearDown(sub.cancel);
      // .dart_tool/ is in the builtin ignore set.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final dt = Directory('${sandbox.path}/.dart_tool')..createSync();
      await File('${dt.path}/hidden').writeAsString('x');
      await Future<void>.delayed(const Duration(milliseconds: 200));
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
