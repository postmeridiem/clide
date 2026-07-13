/// Tests for the backlinks panel — [BacklinksController] (active-file
/// tracking, pql fetches, event-driven refresh) and [BacklinksView]
/// (empty/loading/error states, link groups, row navigation). Previously
/// untested; brought under test when the T-511 coverage sweep exposed the
/// gap.
library;

import 'package:clide/builtin/pql/src/backlinks_controller.dart';
import 'package:clide/builtin/pql/src/backlinks_view.dart';
import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

IpcResponse _ok(Map<String, Object?> data) => IpcResponse.ok(id: '', data: data);
IpcResponse _err(String m) => IpcResponse.err(
  id: '',
  error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: m),
);

void main() {
  late KernelFixture f;

  setUp(() async => f = await KernelFixture.create());
  tearDown(() async => f.dispose());

  void stubLinks({Object? backlinks = const [], Object? outlinks = const [], bool fail = false}) {
    f.ipc.stub('pql.backlinks', (_) async => fail ? _err('vault gone') : _ok({'links': backlinks}));
    f.ipc.stub('pql.outlinks', (_) async => fail ? _err('vault gone') : _ok({'links': outlinks}));
  }

  DaemonEvent activeChanged(String path) => DaemonEvent(subsystem: 'editor', kind: 'editor.active-changed', data: {'path': path}, ts: DateTime.now().toUtc());

  group('BacklinksController', () {
    late BacklinksController c;

    setUp(() => c = BacklinksController(ipc: f.ipc, events: f.services.events));
    tearDown(() => c.dispose());

    test('loadForPath populates both link lists and toggles loading', () async {
      stubLinks(
        backlinks: [
          {'source': 'notes/in.md'},
        ],
        outlinks: [
          {'target': 'notes/out.md', 'alias': 'Out'},
        ],
      );
      final loadingSeen = <bool>[];
      c.addListener(() => loadingSeen.add(c.loading));

      await c.loadForPath('notes/a.md');

      expect(c.activePath, 'notes/a.md');
      expect(loadingSeen, [true, false]);
      expect(c.backlinks.single['source'], 'notes/in.md');
      expect(c.outlinks.single['alias'], 'Out');
      expect(c.error, isNull);
    });

    test('both fetches failing surfaces the error; lists stay empty', () async {
      stubLinks(fail: true);
      await c.loadForPath('a.md');
      expect(c.error, 'vault gone');
      expect(c.backlinks, isEmpty);
      expect(c.outlinks, isEmpty);
    });

    test('one side failing degrades to an empty list without an error', () async {
      f.ipc.stub('pql.backlinks', (_) async => _err('half down'));
      f.ipc.stub(
        'pql.outlinks',
        (_) async => _ok({
          'links': [
            {'target': 'b.md'},
          ],
        }),
      );
      await c.loadForPath('a.md');
      expect(c.error, isNull);
      expect(c.backlinks, isEmpty);
      expect(c.outlinks, hasLength(1));
    });

    test('a malformed links payload is tolerated as empty', () async {
      f.ipc.stub('pql.backlinks', (_) async => _ok(const {'links': 'nonsense'}));
      f.ipc.stub('pql.outlinks', (_) async => _ok(const {}));
      await c.loadForPath('a.md');
      expect(c.backlinks, isEmpty);
      expect(c.outlinks, isEmpty);
    });

    test('editor.active-changed refreshes; same path and foreign events do not', () async {
      var calls = 0;
      f.ipc.stub('pql.backlinks', (_) async {
        calls++;
        return _ok(const {'links': []});
      });
      f.ipc.stub('pql.outlinks', (_) async => _ok(const {'links': []}));

      f.services.events.emit(activeChanged('a.md'));
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);

      f.services.events.emit(activeChanged('a.md')); // same path — no refetch
      f.services.events.emit(DaemonEvent(subsystem: 'git', kind: 'changed', data: const {}, ts: DateTime.now().toUtc()));
      f.services.events.emit(DaemonEvent(subsystem: 'editor', kind: 'editor.saved', data: const {'path': 'b.md'}, ts: DateTime.now().toUtc()));
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);

      f.services.events.emit(activeChanged('b.md'));
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
    });

    test('dispose stops listening to the bus', () async {
      var calls = 0;
      f.ipc.stub('pql.backlinks', (_) async {
        calls++;
        return _ok(const {'links': []});
      });
      f.ipc.stub('pql.outlinks', (_) async => _ok(const {'links': []}));
      c.dispose();
      f.services.events.emit(activeChanged('a.md'));
      await Future<void>.delayed(Duration.zero);
      expect(calls, 0);
      c = BacklinksController(ipc: f.ipc, events: f.services.events); // tearDown disposes a live one
    });
  });

  group('BacklinksView', () {
    Future<void> pump(WidgetTester tester) => tester.pumpWidget(
      harness(
        f,
        const Align(
          alignment: Alignment.center,
          child: SizedBox(width: 320, height: 400, child: BacklinksView()),
        ),
      ),
    );

    testWidgets('no active file → empty-state prompt', (tester) async {
      await pump(tester);
      await tester.pump();
      expect(find.textContaining('Open a file'), findsOneWidget);
    });

    testWidgets('an active-file change renders the file name, groups, and rows', (tester) async {
      stubLinks(
        backlinks: [
          {'source': 'notes/in.md'},
        ],
        outlinks: [
          {'target': 'https://example.com', 'alias': 'Site'},
        ],
      );
      await pump(tester);
      f.services.events.emit(activeChanged('notes/active.md'));
      await tester.pump();
      await tester.pump();

      expect(find.text('active.md'), findsOneWidget, reason: 'header shows the basename');
      expect(find.text('Backlinks (1)'), findsOneWidget);
      expect(find.text('Outlinks (1)'), findsOneWidget);
      expect(find.text('notes/in.md'), findsOneWidget);
      expect(find.text('Site'), findsOneWidget, reason: 'alias wins over the raw target');
      expect(find.text('None'), findsNothing);
    });

    testWidgets('empty groups say None; a failed fetch surfaces the error', (tester) async {
      stubLinks(fail: true);
      await pump(tester);
      f.services.events.emit(activeChanged('a.md'));
      await tester.pump();
      await tester.pump();
      expect(find.text('vault gone'), findsOneWidget);
      expect(find.text('None'), findsNWidgets(2));
    });

    testWidgets('tapping a vault link opens it in the editor; an http link does not', (tester) async {
      final opened = <String>[];
      f.ipc.stub('editor.open', (args) async {
        opened.add(args['path']! as String);
        return _ok(const {});
      });
      stubLinks(
        backlinks: [
          {'source': 'notes/in.md'},
        ],
        outlinks: [
          {'target': 'https://example.com'},
        ],
      );
      await pump(tester);
      f.services.events.emit(activeChanged('a.md'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('notes/in.md'));
      await tester.pump();
      expect(opened, ['notes/in.md']);

      await tester.tap(find.text('https://example.com'));
      await tester.pump();
      expect(opened, ['notes/in.md'], reason: 'http links never route to the editor');
    });
  });
}
