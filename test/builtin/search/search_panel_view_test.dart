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

void main() {
  late KernelFixture f;

  setUp(() async {
    f = await KernelFixture.create();
    f.ipc.stub('search.grep', (_) async => _ok({'searchId': 's1'}));
    f.ipc.stub('search.cancel', (_) async => _ok(const {}));
  });
  tearDown(() => f.dispose());

  void emitMatches() {
    f.services.events.emit(DaemonEvent(
      subsystem: 'search',
      kind: 'search.match',
      data: const {
        'searchId': 's1',
        'matches': [
          {'path': 'lib/a.dart', 'line': 12, 'matchStart': 6, 'matchEnd': 9, 'preview': 'final foo = 1;'},
        ],
      },
      ts: DateTime.now().toUtc(),
    ));
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
}
