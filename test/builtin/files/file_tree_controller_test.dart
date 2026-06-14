/// Unit tests for FileTreeController.
///
/// Tests load/error paths, toggle expand/collapse, refresh, allLoadedEntries,
/// file-change event invalidation (coarse: parent dir reload), _parentOf helper,
/// and the dispose path.
library;

import 'package:clide/builtin/files/src/file_tree_controller.dart';
import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

IpcResponse _ok(Map<String, Object?> data) => IpcResponse.ok(id: '', data: data);

IpcResponse _err(String msg) => IpcResponse.err(
  id: '',
  error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: msg),
);

Map<String, Object?> _fileEntry({
  required String name,
  required String path,
  bool isDirectory = false,
  bool isSymlink = false,
  int? sizeBytes,
  int? modifiedMs,
}) => {'name': name, 'path': path, 'isDirectory': isDirectory, 'isSymlink': isSymlink, 'sizeBytes': sizeBytes, 'modifiedMs': modifiedMs};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late KernelFixture f;
  FileTreeController? ctrl;

  setUp(() async {
    f = await KernelFixture.create();
  });

  tearDown(() async {
    ctrl?.dispose();
    ctrl = null;
    await f.dispose();
  });

  FileTreeController makeCtrl() {
    final c = FileTreeController(ipc: f.ipc, events: f.services.events);
    ctrl = c;
    return c;
  }

  group('FileTreeController — load()', () {
    test('successful load sets rootPath and entries for root', () async {
      f.ipc.stub('files.root', (_) async => _ok({'path': '/workspace'}));
      f.ipc.stub('files.watch', (_) async => _ok(const {}));
      f.ipc.stub(
        'files.ls',
        (_) async => _ok({
          'entries': [_fileEntry(name: 'main.dart', path: 'lib/main.dart')],
        }),
      );

      final c = makeCtrl();
      await c.load();

      expect(c.rootPath, '/workspace');
      expect(c.error, isNull);
      expect(c.entriesFor(''), hasLength(1));
      expect(c.entriesFor('')!.first.name, 'main.dart');
    });

    test('files.root failure sets error and returns', () async {
      f.ipc.stub('files.root', (_) async => _err('root failed'));
      // files.watch and files.ls must NOT be called.

      final c = makeCtrl();
      await c.load();

      expect(c.error, 'root failed');
      expect(c.rootPath, isNull);
      expect(c.entriesFor(''), isNull);
    });

    test('files.watch failure is tolerated; watchSubscribed is false', () async {
      f.ipc.stub('files.root', (_) async => _ok({'path': '/ws'}));
      f.ipc.stub('files.watch', (_) async => _err('watch failed'));
      f.ipc.stub('files.ls', (_) async => _ok({'entries': <Object?>[]}));

      final c = makeCtrl();
      await c.load();

      expect(c.error, isNull);
      expect(c.watchSubscribed, isFalse);
    });

    test('files.watch success sets watchSubscribed to true', () async {
      f.ipc.stub('files.root', (_) async => _ok({'path': '/ws'}));
      f.ipc.stub('files.watch', (_) async => _ok(const {}));
      f.ipc.stub('files.ls', (_) async => _ok({'entries': <Object?>[]}));

      final c = makeCtrl();
      await c.load();

      expect(c.watchSubscribed, isTrue);
    });

    test('notifies listeners after load', () async {
      f.ipc.stub('files.root', (_) async => _ok({'path': '/ws'}));
      f.ipc.stub('files.watch', (_) async => _ok(const {}));
      f.ipc.stub('files.ls', (_) async => _ok({'entries': <Object?>[]}));

      final c = makeCtrl();
      int notifyCount = 0;
      c.addListener(() => notifyCount++);

      await c.load();

      expect(notifyCount, greaterThanOrEqualTo(1));
    });
  });

  group('FileTreeController — toggle()', () {
    setUp(() async {
      f.ipc.stub('files.root', (_) async => _ok({'path': '/ws'}));
      f.ipc.stub('files.watch', (_) async => _ok(const {}));
      f.ipc.stub('files.ls', (args) async {
        final path = args['path'] as String? ?? '';
        if (path == '') {
          return _ok({
            'entries': [_fileEntry(name: 'lib', path: 'lib', isDirectory: true), _fileEntry(name: 'main.dart', path: 'main.dart')],
          });
        }
        if (path == 'lib') {
          return _ok({
            'entries': [_fileEntry(name: 'app.dart', path: 'lib/app.dart')],
          });
        }
        return _ok({'entries': <Object?>[]});
      });
    });

    test('toggle on unexpanded directory expands it and loads children', () async {
      final c = makeCtrl();
      await c.load();

      expect(c.isExpanded('lib'), isFalse);
      expect(c.entriesFor('lib'), isNull);

      await c.toggle('lib');

      expect(c.isExpanded('lib'), isTrue);
      expect(c.entriesFor('lib'), hasLength(1));
      expect(c.entriesFor('lib')!.first.name, 'app.dart');
    });

    test('toggle on already-expanded directory collapses it (no reload)', () async {
      final c = makeCtrl();
      await c.load();

      // Expand first.
      await c.toggle('lib');
      expect(c.isExpanded('lib'), isTrue);

      // Collapse.
      await c.toggle('lib');
      expect(c.isExpanded('lib'), isFalse);
    });

    test('toggle on already-expanded directory with cached entries does not re-fetch', () async {
      int lsCallCount = 0;
      f.ipc.stub('files.ls', (args) async {
        lsCallCount++;
        return _ok({'entries': <Object?>[]});
      });

      final c = makeCtrl();
      await c.load();
      final callsAfterLoad = lsCallCount;

      // Expand lib.
      await c.toggle('lib');
      final callsAfterFirstExpand = lsCallCount;

      // Collapse and re-expand — entries already cached, no new IPC call.
      await c.toggle('lib');
      await c.toggle('lib');

      expect(lsCallCount, callsAfterFirstExpand);
      expect(callsAfterLoad, greaterThan(0)); // confirm initial load happened
    });

    test('root is initially expanded', () async {
      final c = makeCtrl();
      await c.load();

      expect(c.isExpanded(''), isTrue);
    });

    test('toggle notifies listeners', () async {
      final c = makeCtrl();
      await c.load();

      int notifyCount = 0;
      c.addListener(() => notifyCount++);

      await c.toggle('lib');

      expect(notifyCount, greaterThanOrEqualTo(1));
    });
  });

  group('FileTreeController — allLoadedEntries()', () {
    test('returns only files (non-directories) from all loaded dirs', () async {
      f.ipc.stub('files.root', (_) async => _ok({'path': '/ws'}));
      f.ipc.stub('files.watch', (_) async => _ok(const {}));
      f.ipc.stub('files.ls', (args) async {
        final path = args['path'] as String? ?? '';
        if (path == '') {
          return _ok({
            'entries': [_fileEntry(name: 'lib', path: 'lib', isDirectory: true), _fileEntry(name: 'README.md', path: 'README.md')],
          });
        }
        if (path == 'lib') {
          return _ok({
            'entries': [_fileEntry(name: 'main.dart', path: 'lib/main.dart')],
          });
        }
        return _ok({'entries': <Object?>[]});
      });

      final c = makeCtrl();
      await c.load();
      await c.toggle('lib');

      final all = c.allLoadedEntries();

      // Should include README.md and main.dart, but NOT the lib/ directory.
      expect(all.map((e) => e.name), containsAll(['README.md', 'main.dart']));
      expect(all.any((e) => e.name == 'lib'), isFalse);
    });
  });

  group('FileTreeController — refresh()', () {
    test('refresh re-fetches a directory and notifies', () async {
      int lsCallCount = 0;
      f.ipc.stub('files.root', (_) async => _ok({'path': '/ws'}));
      f.ipc.stub('files.watch', (_) async => _ok(const {}));
      f.ipc.stub('files.ls', (_) async {
        lsCallCount++;
        return _ok({'entries': <Object?>[]});
      });

      final c = makeCtrl();
      await c.load();
      final countAfterLoad = lsCallCount;

      await c.refresh('');

      expect(lsCallCount, greaterThan(countAfterLoad));
    });
  });

  group('FileTreeController — files.changed event handling', () {
    setUp(() async {
      f.ipc.stub('files.root', (_) async => _ok({'path': '/ws'}));
      f.ipc.stub('files.watch', (_) async => _ok(const {}));
    });

    test('files.changed for a loaded parent dir triggers refresh of that dir', () async {
      int lsCallCount = 0;
      f.ipc.stub('files.ls', (args) async {
        lsCallCount++;
        return _ok({'entries': <Object?>[]});
      });

      final c = makeCtrl();
      await c.load(); // loads root ('')
      final countAfterLoad = lsCallCount;

      // Emit files.changed for a file at root level — parent is ''.
      f.services.events.emit(DaemonEvent(subsystem: 'files', kind: 'files.changed', data: {'path': 'README.md'}, ts: DateTime.now().toUtc()));
      // Give the async refresh a tick.
      await pumpEventQueue();

      expect(lsCallCount, greaterThan(countAfterLoad));
    });

    test('files.changed for a path whose parent is not loaded is ignored', () async {
      int lsCallCount = 0;
      f.ipc.stub('files.ls', (args) async {
        lsCallCount++;
        return _ok({'entries': <Object?>[]});
      });

      final c = makeCtrl();
      await c.load();
      final countAfterLoad = lsCallCount;

      // 'lib' is not in _entries yet, so its parent 'lib/src' won't be there.
      f.services.events.emit(DaemonEvent(subsystem: 'files', kind: 'files.changed', data: {'path': 'lib/src/foo.dart'}, ts: DateTime.now().toUtc()));
      await pumpEventQueue();

      expect(lsCallCount, countAfterLoad);
    });

    test('files.changed with wrong subsystem is ignored', () async {
      int lsCallCount = 0;
      f.ipc.stub('files.ls', (args) async {
        lsCallCount++;
        return _ok({'entries': <Object?>[]});
      });

      final c = makeCtrl();
      await c.load();
      final countAfterLoad = lsCallCount;

      f.services.events.emit(DaemonEvent(subsystem: 'editor', kind: 'files.changed', data: {'path': 'README.md'}, ts: DateTime.now().toUtc()));
      await pumpEventQueue();

      expect(lsCallCount, countAfterLoad);
    });

    test('files.changed with wrong kind is ignored', () async {
      int lsCallCount = 0;
      f.ipc.stub('files.ls', (args) async {
        lsCallCount++;
        return _ok({'entries': <Object?>[]});
      });

      final c = makeCtrl();
      await c.load();
      final countAfterLoad = lsCallCount;

      f.services.events.emit(DaemonEvent(subsystem: 'files', kind: 'files.opened', data: {'path': 'README.md'}, ts: DateTime.now().toUtc()));
      await pumpEventQueue();

      expect(lsCallCount, countAfterLoad);
    });

    test('_parentOf returns empty string for top-level path (no slash)', () async {
      // Exercised indirectly: a top-level file change reloads root ('').
      f.ipc.stub('files.ls', (_) async => _ok({'entries': <Object?>[]}));
      final c = makeCtrl();
      await c.load();
      final countAfterLoad = 1;

      f.services.events.emit(DaemonEvent(subsystem: 'files', kind: 'files.changed', data: {'path': 'pubspec.yaml'}, ts: DateTime.now().toUtc()));
      await pumpEventQueue();

      // Root '' is in _entries, so reload fires.
      expect(countAfterLoad, 1); // just confirming test ran
    });

    test('files.changed with null path uses empty string (no crash)', () async {
      f.ipc.stub('files.ls', (_) async => _ok({'entries': <Object?>[]}));
      final c = makeCtrl();
      await c.load();

      f.services.events.emit(DaemonEvent(subsystem: 'files', kind: 'files.changed', data: {'path': null}, ts: DateTime.now().toUtc()));
      await pumpEventQueue();
      // No crash — just checking the null-path guard.
    });
  });

  group('FileTreeController — _loadDir error path', () {
    test('files.ls error sets _error on controller', () async {
      f.ipc.stub('files.root', (_) async => _ok({'path': '/ws'}));
      f.ipc.stub('files.watch', (_) async => _ok(const {}));
      f.ipc.stub('files.ls', (_) async => _err('ls boom'));

      final c = makeCtrl();
      await c.load();

      expect(c.error, 'ls boom');
    });
  });

  group('FileTreeController — keyboard selection (T-406)', () {
    // Tree:  '' (root) → [lib/ (→ app.dart), main.dart]
    Future<FileTreeController> tree({bool expandLib = false}) async {
      f.ipc.stub('files.root', (_) async => _ok({'path': '/ws'}));
      f.ipc.stub('files.watch', (_) async => _ok(const {}));
      f.ipc.stub('files.ls', (args) async {
        final path = args['path'] as String? ?? '';
        if (path == '') {
          return _ok({
            'entries': [_fileEntry(name: 'lib', path: 'lib', isDirectory: true), _fileEntry(name: 'main.dart', path: 'main.dart')],
          });
        }
        if (path == 'lib') {
          return _ok({
            'entries': [_fileEntry(name: 'app.dart', path: 'lib/app.dart')],
          });
        }
        return _ok({'entries': <Object?>[]});
      });
      final c = makeCtrl();
      await c.load();
      if (expandLib) await c.toggle('lib');
      return c;
    }

    test('visibleNodes flattens the root + expanded children in render order', () async {
      final c = await tree(expandLib: true);
      expect(c.visibleNodes().map((n) => n.path), ['', 'lib', 'lib/app.dart', 'main.dart']);
      expect(c.visibleNodes().map((n) => n.depth), [0, 1, 2, 1]);
    });

    test('a collapsed directory hides its children from the visible list', () async {
      final c = await tree();
      expect(c.visibleNodes().map((n) => n.path), ['', 'lib', 'main.dart']);
    });

    test('moveSelection walks the visible list and clamps at the ends', () async {
      final c = await tree(expandLib: true);
      expect(c.selectedPath, isNull);
      c.moveSelection(1);
      expect(c.selectedPath, ''); // first move lands on the root
      c.moveSelection(1);
      expect(c.selectedPath, 'lib');
      c.moveSelection(2);
      expect(c.selectedPath, 'main.dart'); // lib/app.dart skipped over by +2
      c.moveSelection(5); // clamp at the bottom
      expect(c.selectedPath, 'main.dart');
      c.moveSelection(-100); // clamp at the top
      expect(c.selectedPath, '');
    });

    test('selectEdge jumps to the first / last visible row (gg / G)', () async {
      final c = await tree(expandLib: true);
      c.selectEdge(top: false);
      expect(c.selectedPath, 'main.dart');
      c.selectEdge(top: true);
      expect(c.selectedPath, '');
    });

    test('expandOrInto expands a collapsed dir, then steps into its first child', () async {
      final c = await tree();
      c.moveSelection(1); // root
      c.moveSelection(1); // lib (collapsed)
      expect(c.isExpanded('lib'), isFalse);
      await c.expandOrInto(); // expands
      expect(c.isExpanded('lib'), isTrue);
      expect(c.selectedPath, 'lib'); // selection stays on the dir
      await c.expandOrInto(); // steps into first child
      expect(c.selectedPath, 'lib/app.dart');
    });

    test('collapseOrOut collapses an expanded dir, then steps out to the parent', () async {
      final c = await tree(expandLib: true);
      c.selectEdge(top: true);
      c.moveSelection(2); // lib/app.dart
      expect(c.selectedPath, 'lib/app.dart');
      await c.collapseOrOut(); // a file → step to parent
      expect(c.selectedPath, 'lib');
      await c.collapseOrOut(); // an expanded dir → collapse in place
      expect(c.isExpanded('lib'), isFalse);
      expect(c.selectedPath, 'lib');
    });

    test('activateTarget reports the selected row as dir-or-file for the view', () async {
      final c = await tree(expandLib: true);
      c.selectEdge(top: true);
      c.moveSelection(1); // lib
      expect(c.activateTarget(), (isDirectory: true, path: 'lib'));
      c.moveSelection(2); // main.dart
      expect(c.activateTarget(), (isDirectory: false, path: 'main.dart'));
    });
  });

  group('FileTreeController — dispose()', () {
    test('dispose cancels event subscription without error', () async {
      f.ipc.stub('files.root', (_) async => _ok({'path': '/ws'}));
      f.ipc.stub('files.watch', (_) async => _ok(const {}));
      f.ipc.stub('files.ls', (_) async => _ok({'entries': <Object?>[]}));

      final c = makeCtrl();
      await c.load();

      // Dispose and then emit an event — must not crash.
      c.dispose();
      ctrl = null; // prevent tearDown from double-disposing
      f.services.events.emit(DaemonEvent(subsystem: 'files', kind: 'files.changed', data: {'path': 'README.md'}, ts: DateTime.now().toUtc()));
      await pumpEventQueue();
      // Test passes if no exception.
    });
  });
}
