/// Tests for ClideMarkdown workspace file references (T-300): paths that the
/// resolver confirms exist become clickable and open in the editor; everything
/// else stays literal. The resolver is stubbed so no real filesystem is touched.
library;

import 'package:clide/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  // Resolves only the one known repo path; everything else is "not a file".
  String? resolve(String p) => p == 'lib/app.dart' ? '/repo/lib/app.dart' : null;

  ClideMarkdown md(String src, {void Function(String, int?)? onOpen}) => ClideMarkdown(src, resolveFileRef: resolve, onOpenFile: onOpen ?? (_, _) {});

  testWidgets('a bare repo path in prose is tappable and opens with no line', (tester) async {
    String? path;
    int? line = -1;
    await tester.pumpWidget(
      harness(
        f,
        md(
          'see lib/app.dart for the entry point',
          onOpen: (p, l) {
            path = p;
            line = l;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('lib/app.dart'));
    await tester.pump();
    expect(path, '/repo/lib/app.dart');
    expect(line, isNull);
  });

  testWidgets('a path:line ref opens at the line', (tester) async {
    String? path;
    int? line;
    await tester.pumpWidget(
      harness(
        f,
        md(
          'crash at lib/app.dart:42 today',
          onOpen: (p, l) {
            path = p;
            line = l;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('lib/app.dart:42'));
    await tester.pump();
    expect(path, '/repo/lib/app.dart');
    expect(line, 42);
  });

  testWidgets('a path:line:col ref opens at the line, ignoring the column', (tester) async {
    int? line;
    await tester.pumpWidget(harness(f, md('lib/app.dart:42:8', onOpen: (_, l) => line = l)));
    await tester.pump();

    await tester.tap(find.text('lib/app.dart:42:8'));
    await tester.pump();
    expect(line, 42);
  });

  testWidgets('a backticked path is clickable', (tester) async {
    String? path;
    int? line;
    await tester.pumpWidget(
      harness(
        f,
        md(
          'open `lib/app.dart:7`',
          onOpen: (p, l) {
            path = p;
            line = l;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('lib/app.dart:7'));
    await tester.pump();
    expect(path, '/repo/lib/app.dart');
    expect(line, 7);
  });

  testWidgets('a markdown [text](path) link opens the resolved href file', (tester) async {
    String? path;
    await tester.pumpWidget(harness(f, md('[the app](lib/app.dart)', onOpen: (p, _) => path = p)));
    await tester.pump();

    await tester.tap(find.text('the app'));
    await tester.pump();
    expect(path, '/repo/lib/app.dart');
  });

  testWidgets('a path that does not resolve stays literal (no link, no fire)', (tester) async {
    var calls = 0;
    await tester.pumpWidget(harness(f, md('nothing at lib/ghost.dart here', onOpen: (_, _) => calls++)));
    await tester.pumpAndSettle();

    // Rendered as plain text — tapping it does nothing.
    await tester.tap(find.textContaining('lib/ghost.dart'), warnIfMissed: false);
    await tester.pump();
    expect(calls, 0);
  });

  testWidgets('dotted prose (a version number) does not linkify', (tester) async {
    var calls = 0;
    await tester.pumpWidget(harness(f, md('shipped version 2.2.0 today', onOpen: (_, _) => calls++)));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('2.2.0'), warnIfMissed: false);
    await tester.pump();
    expect(calls, 0);
  });

  testWidgets('with no file hooks, a path renders inert (no crash)', (tester) async {
    await tester.pumpWidget(harness(f, const ClideMarkdown('see lib/app.dart here')));
    await tester.pumpAndSettle();
    expect(find.textContaining('lib/app.dart'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a backticked non-path code span stays verbatim (not linkified)', (tester) async {
    await tester.pumpWidget(harness(f, md('run `flutter test` now')));
    await tester.pumpAndSettle();

    // A linkified ref renders as its own tappable Text; an inert code span is a
    // styled run inside the paragraph, so it is not a standalone Text widget.
    expect(find.text('flutter test'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
