import 'package:clide/builtin/graph/src/graph_controller.dart';
import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/graph/graph_filter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_ipc.dart';

void main() {
  group('GraphController', () {
    late DaemonBus bus;
    late FakeDaemonClient ipc;

    setUp(() {
      bus = DaemonBus();
      ipc = FakeDaemonClient(log: Logger(), events: bus);
    });
    tearDown(() => bus.dispose());

    IpcResponse ok(Map<String, Object?> data) => IpcResponse.ok(id: '1', data: data);
    IpcResponse err(String msg) => IpcResponse.err(
      id: '1',
      error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: msg),
    );

    /// Stubs `pql.files` (from the map's keys) and `pql.meta` (per path):
    /// outlinks from [vault], tags from [tags].
    void stubVault(Map<String, List<String>> vault, {Map<String, List<String>> tags = const {}}) {
      ipc.stub(
        'pql.files',
        (_) async => ok({
          'files': [
            for (final p in vault.keys) {'path': p},
          ],
        }),
      );
      ipc.stub('pql.meta', (args) async {
        final path = args['path'] as String?;
        return ok({
          'outlinks': [
            for (final t in vault[path] ?? const []) {'target': t},
          ],
          'tags': tags[path] ?? const <String>[],
        });
      });
    }

    test('assembles a graph from files + their meta outlinks', () async {
      stubVault({
        'a.md': ['b.md'],
        'b.md': [],
      });
      final c = GraphController(ipc: ipc, events: bus);
      var notified = 0;
      c.addListener(() => notified++);
      await c.load();

      expect(c.graph.nodes.map((n) => n.id), containsAll(['a.md', 'b.md']));
      expect(c.graph.edgePairs, [('a.md', 'b.md')]);
      expect(c.loading, isFalse);
      expect(c.error, isNull);
      expect(notified, greaterThan(0));
    });

    test('strips #heading fragments so a heading link still connects the notes', () async {
      stubVault({
        'a.md': ['b.md#a-heading'],
        'b.md': [],
      });
      final c = GraphController(ipc: ipc, events: bus);
      await c.load();
      expect(c.graph.edgePairs, [('a.md', 'b.md')]); // fragment stripped → real edge
    });

    test('collects tags into a sorted availableTags union', () async {
      stubVault(
        {'a.md': const [], 'b.md': const []},
        tags: {
          'a.md': ['project', 'note'],
          'b.md': ['note'],
        },
      );
      final c = GraphController(ipc: ipc, events: bus);
      await c.load();
      expect(c.availableTags, ['note', 'project']);
    });

    test('a pql.files failure clears the graph and surfaces the error', () async {
      ipc.stub('pql.files', (_) async => err('index locked'));
      final c = GraphController(ipc: ipc, events: bus);
      await c.load();
      expect(c.graph.isEmpty, isTrue);
      expect(c.error, contains('index locked'));
      expect(c.loading, isFalse);
    });

    test('a per-file meta failure drops that file\'s edges, keeps the node', () async {
      ipc.stub(
        'pql.files',
        (_) async => ok({
          'files': [
            {'path': 'a.md'},
            {'path': 'b.md'},
          ],
        }),
      );
      ipc.stub('pql.meta', (args) async {
        if (args['path'] == 'a.md') return err('boom');
        return ok({'outlinks': const [], 'tags': const []});
      });
      final c = GraphController(ipc: ipc, events: bus);
      await c.load();
      expect(c.graph.nodes.map((n) => n.id), containsAll(['a.md', 'b.md']));
      expect(c.graph.edgePairs, isEmpty);
      expect(c.error, isNull);
    });

    test('setGlob reloads with the new glob; the same glob is a no-op', () async {
      final globs = <String>[];
      ipc.stub('pql.files', (args) async {
        globs.add(args['glob'] as String);
        return ok({'files': const []});
      });
      ipc.stub('pql.meta', (_) async => ok({'outlinks': const [], 'tags': const []}));
      final c = GraphController(ipc: ipc, events: bus);
      await c.load();
      c.setGlob('notes/**');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      c.setGlob('notes/**'); // no-op
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(globs, ['**/*.md', 'notes/**']);
      expect(c.glob, 'notes/**');
    });

    test('setFilter narrows visibleGraph without reloading', () async {
      var files = 0;
      ipc.stub('pql.files', (_) async {
        files++;
        return ok({
          'files': [
            {'path': 'a.md'},
            {'path': 'b.md'},
          ],
        });
      });
      ipc.stub(
        'pql.meta',
        (args) async => ok({
          'outlinks': const [],
          'tags': args['path'] == 'a.md' ? ['project'] : const <String>[],
        }),
      );
      final c = GraphController(ipc: ipc, events: bus);
      await c.load();
      expect(files, 1);
      expect(c.visibleGraph.nodes.map((n) => n.id), unorderedEquals(['a.md', 'b.md']));
      c.setFilter(const GraphFilter(includeTags: {'project'}));
      expect(c.visibleGraph.nodes.map((n) => n.id), ['a.md']);
      expect(files, 1); // client-side — no reload
    });

    test('a depth filter re-centres on the active editor file', () async {
      stubVault({
        'a.md': ['b.md'],
        'b.md': ['c.md'],
        'c.md': [],
      });
      final c = GraphController(ipc: ipc, events: bus);
      await c.load();
      c.setFilter(const GraphFilter(depth: 1));
      expect(c.visibleGraph.isEmpty, isTrue); // no active file yet
      bus.emit(DaemonEvent(subsystem: 'editor', kind: 'editor.active-changed', data: const {'path': 'b.md'}, ts: DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(c.activePath, 'b.md');
      expect(c.visibleGraph.nodes.map((n) => n.id), unorderedEquals(['a.md', 'b.md', 'c.md']));
    });

    test('a files event triggers a debounced reload; non-files events do not', () async {
      var files = 0;
      ipc.stub('pql.files', (_) async {
        files++;
        return ok({'files': const []});
      });
      ipc.stub('pql.meta', (_) async => ok({'outlinks': const [], 'tags': const []}));
      final c = GraphController(ipc: ipc, events: bus, refreshDebounce: Duration.zero);
      expect(files, 0);

      bus.emit(DaemonEvent(subsystem: 'git', kind: 'git.status', data: const {}, ts: DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(files, 0); // non-files event ignored

      bus.emit(DaemonEvent(subsystem: 'files', kind: 'files.changed', data: const {'path': 'x.md'}, ts: DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(files, 1); // reload fired
      c.dispose();
    });

    test('a burst of files events coalesces into a single reload', () async {
      var files = 0;
      ipc.stub('pql.files', (_) async {
        files++;
        return ok({'files': const []});
      });
      ipc.stub('pql.meta', (_) async => ok({'outlinks': const [], 'tags': const []}));
      final c = GraphController(ipc: ipc, events: bus, refreshDebounce: const Duration(milliseconds: 20));

      for (var i = 0; i < 5; i++) {
        bus.emit(DaemonEvent(subsystem: 'files', kind: 'files.changed', data: {'path': '$i.md'}, ts: DateTime.now()));
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(files, 1);
      c.dispose();
    });
  });
}
