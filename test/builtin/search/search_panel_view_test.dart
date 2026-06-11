/// Widget test for [SearchPanelView] — searching renders streamed
/// matches grouped by file and clicking a match opens it (T-52).
library;

import 'package:clide/builtin/search/src/search_panel_view.dart';
import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

IpcResponse _ok(Map<String, Object?> data) => IpcResponse.ok(id: '', data: data);

/// SearchPanelView wrapped in a DialogHost so the replace confirm /
/// not-clean dialogs render and can be driven.
Widget _withDialogs(KernelFixture f) => DialogHost(router: f.services.dialog, child: const SearchPanelView());

void main() {
  late KernelFixture f;

  setUp(() async {
    f = await KernelFixture.create();
    f.ipc.stub('search.grep', (_) async => _ok({'searchId': 's1'}));
    f.ipc.stub('search.cancel', (_) async => _ok(const {}));
  });
  tearDown(() => f.dispose());

  void emitMatches() {
    f.services.events.emit(
      DaemonEvent(
        subsystem: 'search',
        kind: 'search.match',
        data: const {
          'searchId': 's1',
          'matches': [
            {'path': 'lib/a.dart', 'line': 12, 'matchStart': 6, 'matchEnd': 9, 'preview': 'final foo = 1;'},
          ],
        },
        ts: DateTime.now().toUtc(),
      ),
    );
  }

  testWidgets('search renders matches grouped by file', (tester) async {
    await tester.pumpWidget(harness(f, const SearchPanelView()));
    await tester.enterText(find.byType(EditableText).first, 'foo');
    await tester.pump(const Duration(milliseconds: 250)); // debounce → run()
    await pumpAsync(tester); // search.grep resolves; activeSearchId set
    emitMatches();
    await pumpAsync(tester);

    expect(find.text('lib/a.dart'), findsOneWidget); // file group header
    expect(find.text('12'), findsOneWidget); // line number
  });

  testWidgets('tapping a match opens the editor at its line', (tester) async {
    Map<String, Object?>? opened;
    f.ipc.stub('editor.open', (args) async {
      opened = args;
      return _ok(const {});
    });
    await tester.pumpWidget(harness(f, const SearchPanelView()));
    await tester.enterText(find.byType(EditableText).first, 'foo');
    await tester.pump(const Duration(milliseconds: 250));
    await pumpAsync(tester);
    emitMatches();
    await pumpAsync(tester);

    await tester.tap(find.text('12')); // the match row's line number
    await pumpAsync(tester);

    expect(opened, isNotNull);
    expect(opened!['path'], 'lib/a.dart');
    expect(opened!['line'], 12);
  });

  testWidgets('no results shows the No results status', (tester) async {
    await tester.pumpWidget(harness(f, const SearchPanelView()));
    await tester.enterText(find.byType(EditableText).first, 'foo');
    await tester.pump(const Duration(milliseconds: 250));
    await pumpAsync(tester);
    f.services.events.emit(
      DaemonEvent(subsystem: 'search', kind: 'search.done', data: const {'searchId': 's1', 'cancelled': false}, ts: DateTime.now().toUtc()),
    );
    await pumpAsync(tester);
    expect(find.text('No results'), findsOneWidget);
  });

  testWidgets('a search error is shown in the panel', (tester) async {
    await tester.pumpWidget(harness(f, const SearchPanelView()));
    await tester.enterText(find.byType(EditableText).first, '(bad');
    await tester.pump(const Duration(milliseconds: 250));
    await pumpAsync(tester);
    f.services.events.emit(
      DaemonEvent(subsystem: 'search', kind: 'search.error', data: const {'searchId': 's1', 'message': 'invalid regex: boom'}, ts: DateTime.now().toUtc()),
    );
    await pumpAsync(tester);
    expect(find.textContaining('invalid regex'), findsOneWidget);
  });

  testWidgets('toggling regex re-runs the search', (tester) async {
    var grepCalls = 0;
    f.ipc.stub('search.grep', (_) async {
      grepCalls++;
      return _ok({'searchId': 's1'});
    });
    await tester.pumpWidget(harness(f, const SearchPanelView()));
    await tester.enterText(find.byType(EditableText).first, 'foo');
    await tester.pump(const Duration(milliseconds: 250));
    await pumpAsync(tester);
    final before = grepCalls;
    await tester.tap(find.text('.*')); // regex toggle
    await pumpAsync(tester);
    expect(grepCalls, greaterThan(before));
  });

  // Drive a search so there are matches + set a replacement string.
  Future<void> seedReplace(WidgetTester tester) async {
    await tester.enterText(find.byType(EditableText).first, 'foo');
    await tester.pump(const Duration(milliseconds: 250));
    await pumpAsync(tester);
    emitMatches();
    await pumpAsync(tester);
    await tester.enterText(find.byType(EditableText).at(1), 'bar'); // replace field
    await pumpAsync(tester);
  }

  testWidgets('replace preview renders the rewritten line', (tester) async {
    await tester.pumpWidget(harness(f, _withDialogs(f)));
    await seedReplace(tester);
    // The emitted match line is 'final foo = 1;' → preview shows the after
    // (rendered as a RichText span, so match on the plain text).
    expect(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText() == 'final bar = 1;'), findsOneWidget);
  });

  testWidgets('Replace all on a dirty tree shows a guard dialog, no apply', (tester) async {
    var applyCalled = false;
    f.ipc.stub('git.status', (_) async => _ok(const {'clean': false}));
    f.ipc.stub('search.replace', (_) async {
      applyCalled = true;
      return _ok(const {'apply': true, 'filesChanged': 0, 'totalCount': 0});
    });
    await tester.pumpWidget(harness(f, _withDialogs(f)));
    await seedReplace(tester);
    await tester.tap(find.text('Replace all'));
    await pumpAsync(tester);
    expect(find.text('Working tree not clean'), findsOneWidget);
    expect(applyCalled, isFalse);
  });

  testWidgets('Replace all on a clean tree confirms then applies', (tester) async {
    Map<String, Object?>? applyArgs;
    f.ipc.stub('git.status', (_) async => _ok(const {'clean': true}));
    f.ipc.stub('search.replace', (args) async {
      applyArgs = args;
      return _ok(const {'apply': true, 'filesChanged': 1, 'totalCount': 1});
    });
    await tester.pumpWidget(harness(f, _withDialogs(f)));
    await seedReplace(tester);
    await tester.tap(find.text('Replace all'));
    await pumpAsync(tester);
    // Confirm dialog up; confirm it.
    await tester.tap(find.text('Confirm'));
    await pumpAsync(tester);
    expect(applyArgs, isNotNull);
    expect(applyArgs!['apply'], isTrue);
    expect(applyArgs!['replacement'], 'bar');
  });

  // -- Merged pql modes (T-201) ----------------------------------------------

  testWidgets('Vault mode runs a ranked pql search and lists results', (tester) async {
    Map<String, Object?>? grepArgs;
    f.ipc.stub('pql.search', (args) async {
      grepArgs = args;
      return _ok({
        'results': [
          {'path': 'docs/vault-hit.md', 'score': 0.9},
        ],
      });
    });
    await tester.pumpWidget(harness(f, const SearchPanelView()));
    await pumpAsync(tester);

    await tester.tap(find.text('Vault'));
    await pumpAsync(tester);
    await tester.enterText(find.byType(EditableText).first, 'concept');
    await tester.pump(const Duration(milliseconds: 350)); // ranked-search debounce
    await pumpAsync(tester);

    expect(grepArgs?['terms'], 'concept');
    expect(find.text('docs/vault-hit.md'), findsOneWidget);
  });

  testWidgets('Query mode runs a PQL DSL query on submit', (tester) async {
    Map<String, Object?>? queryArgs;
    f.ipc.stub('pql.query', (args) async {
      queryArgs = args;
      return _ok({
        'results': [
          {'name': 'T-1', 'status': 'backlog'},
        ],
      });
    });
    await tester.pumpWidget(harness(f, const SearchPanelView()));
    await pumpAsync(tester);

    await tester.tap(find.text('Query'));
    await pumpAsync(tester);
    await tester.enterText(find.byType(EditableText).first, "type = 'ticket'");
    await tester.testTextInput.receiveAction(TextInputAction.done); // onSubmitted
    await pumpAsync(tester);

    expect(queryArgs?['query'], "type = 'ticket'");
    expect(find.text('T-1'), findsOneWidget);
  });

  testWidgets('Markdown mode lists markdown files on switch', (tester) async {
    f.ipc.stub(
      'pql.files',
      (_) async => _ok({
        'files': [
          {'path': 'docs/initial-plan.md'},
        ],
      }),
    );
    await tester.pumpWidget(harness(f, const SearchPanelView()));
    await pumpAsync(tester);

    await tester.tap(find.text('Markdown'));
    await pumpAsync(tester);

    expect(find.text('docs/initial-plan.md'), findsOneWidget);
  });

  testWidgets('Vault mode surfaces a pql search error', (tester) async {
    f.ipc.stub(
      'pql.search',
      (_) async => IpcResponse.err(
        id: '',
        error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'pql down'),
      ),
    );
    await tester.pumpWidget(harness(f, const SearchPanelView()));
    await pumpAsync(tester);
    await tester.tap(find.text('Vault'));
    await pumpAsync(tester);
    await tester.enterText(find.byType(EditableText).first, 'x');
    await tester.pump(const Duration(milliseconds: 350));
    await pumpAsync(tester);
    expect(find.textContaining('pql down'), findsOneWidget);
  });

  testWidgets('Markdown mode shows the empty state and filters by glob', (tester) async {
    Map<String, Object?>? filesArgs;
    f.ipc.stub('pql.files', (args) async {
      filesArgs = args;
      return _ok(const {'files': []});
    });
    await tester.pumpWidget(harness(f, const SearchPanelView()));
    await pumpAsync(tester);
    await tester.tap(find.text('Markdown'));
    await pumpAsync(tester);
    expect(find.text('No markdown files found.'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, 'plan');
    await tester.pump(const Duration(milliseconds: 250));
    await pumpAsync(tester);
    expect(filesArgs?['glob'], contains('plan'));
  });
}
