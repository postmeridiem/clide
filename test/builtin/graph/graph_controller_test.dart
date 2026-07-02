import 'package:clide/builtin/graph/src/graph_controller.dart';
import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_ipc.dart';

void main() {
  group('GraphController.load', () {
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

    /// Stubs `pql.files` (from the map's keys) and `pql.outlinks` (per path).
    void stubVault(Map<String, List<String>> vault) {
      ipc.stub(
        'pql.files',
        (_) async => ok({
          'files': [
            for (final p in vault.keys) {'path': p},
          ],
        }),
      );
      ipc.stub('pql.outlinks', (args) async {
        final path = args['path'] as String?;
        final links = vault[path] ?? const [];
        return ok({
          'links': [
            for (final t in links) {'target': t},
          ],
        });
      });
    }

    test('assembles a graph from files + their outlinks', () async {
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
      expect(notified, greaterThan(0)); // loading toggle + final
    });

    test('a pql.files failure clears the graph and surfaces the error', () async {
      ipc.stub('pql.files', (_) async => err('index locked'));
      final c = GraphController(ipc: ipc, events: bus);
      await c.load();
      expect(c.graph.isEmpty, isTrue);
      expect(c.error, contains('index locked'));
      expect(c.loading, isFalse);
    });

    test('a per-file outlinks failure drops that file\'s edges, keeps the node', () async {
      ipc.stub(
        'pql.files',
        (_) async => ok({
          'files': [
            {'path': 'a.md'},
            {'path': 'b.md'},
          ],
        }),
      );
      ipc.stub('pql.outlinks', (args) async {
        if (args['path'] == 'a.md') return err('boom');
        return ok({'links': const []});
      });
      final c = GraphController(ipc: ipc, events: bus);
      await c.load();
      expect(c.graph.nodes.map((n) => n.id), containsAll(['a.md', 'b.md']));
      expect(c.graph.edgePairs, isEmpty); // a.md's edges were lost, no crash
      expect(c.error, isNull); // a partial failure isn't a load failure
    });

    test('dangling + self links are dropped by the model', () async {
      stubVault({
        'a.md': ['a.md', 'ghost.md', 'b.md'],
        'b.md': [],
      });
      final c = GraphController(ipc: ipc, events: bus);
      await c.load();
      expect(c.graph.edgePairs, [('a.md', 'b.md')]);
    });

    test('a files event triggers a debounced reload; non-files events do not', () async {
      var files = 0;
      ipc.stub('pql.files', (_) async {
        files++;
        return ok({'files': const []});
      });
      ipc.stub('pql.outlinks', (_) async => ok({'links': const []}));
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
      ipc.stub('pql.outlinks', (_) async => ok({'links': const []}));
      final c = GraphController(ipc: ipc, events: bus, refreshDebounce: const Duration(milliseconds: 20));

      for (var i = 0; i < 5; i++) {
        bus.emit(DaemonEvent(subsystem: 'files', kind: 'files.changed', data: {'path': '$i.md'}, ts: DateTime.now()));
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(files, 1); // five events, one reload
      c.dispose();
    });
  });
}
