/// T-54: Output dock tab — OutputController filtering + OutputView rendering.
library;

import 'package:clide/builtin/output/output.dart';
import 'package:clide/kernel/src/log.dart';
import 'package:clide/kernel/src/log_ring.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

LogRecord _rec(LogLevel level, String source, String message) =>
    LogRecord(level: level, source: source, message: message, timestamp: DateTime.utc(2026, 6, 6, 10, 42, 3));

LogRing _seeded() => LogRing(capacity: 100)
  ..add(_rec(LogLevel.info, 'ipc', 'alpha'))
  ..add(_rec(LogLevel.warn, 'pql', 'beta'))
  ..add(_rec(LogLevel.error, 'extensions', 'gamma'));

bool _textIs(Object? w, String s) => w is ClideText && w.data == s;

void main() {
  group('OutputController filtering', () {
    test('minLevel hides lower levels', () {
      final c = OutputController(_seeded())..setMinLevel(LogLevel.warn);
      expect(c.filtered.map((r) => r.message), ['beta', 'gamma']);
    });

    test('source filter narrows to one subsystem', () {
      final c = OutputController(_seeded())..setSource('pql');
      expect(c.filtered.map((r) => r.message), ['beta']);
    });

    test('text filter matches message or source', () {
      final c = OutputController(_seeded());
      c.setText('gam');
      expect(c.filtered.map((r) => r.message), ['gamma']);
      c.setText('ipc'); // matches by source
      expect(c.filtered.map((r) => r.message), ['alpha']);
    });

    test('clear empties via the ring', () {
      final ring = _seeded();
      OutputController(ring).clear();
      expect(ring.isEmpty, isTrue);
    });
  });

  group('OutputView', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() => f.dispose());

    testWidgets('renders a row per record', (tester) async {
      await tester.pumpWidget(harness(f, OutputView(ring: _seeded())));
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => _textIs(w, 'alpha')), findsOneWidget);
      expect(find.byWidgetPredicate((w) => _textIs(w, 'beta')), findsOneWidget);
      expect(find.byWidgetPredicate((w) => _textIs(w, 'gamma')), findsOneWidget);
    });

    testWidgets('empty ring shows the empty state', (tester) async {
      await tester.pumpWidget(harness(f, OutputView(ring: LogRing(capacity: 10))));
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => _textIs(w, 'No output yet.')), findsOneWidget);
    });

    testWidgets('the level chip cycles its label', (tester) async {
      await tester.pumpWidget(harness(f, OutputView(ring: _seeded())));
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => _textIs(w, 'Level: debug')), findsOneWidget);
      await tester.tap(find.ancestor(of: find.byWidgetPredicate((w) => _textIs(w, 'Level: debug')), matching: find.byType(GestureDetector)));
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => _textIs(w, 'Level: info')), findsOneWidget);
    });

    testWidgets('the source chip cycles and filters', (tester) async {
      await tester.pumpWidget(harness(f, OutputView(ring: _seeded())));
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => _textIs(w, 'Source: all')), findsOneWidget);
      await tester.tap(find.ancestor(of: find.byWidgetPredicate((w) => _textIs(w, 'Source: all')), matching: find.byType(GestureDetector)));
      await tester.pumpAndSettle();
      // First source alphabetically is 'extensions'.
      expect(find.byWidgetPredicate((w) => _textIs(w, 'Source: extensions')), findsOneWidget);
      expect(find.byWidgetPredicate((w) => _textIs(w, 'alpha')), findsNothing); // ipc row filtered out
      expect(find.byWidgetPredicate((w) => _textIs(w, 'gamma')), findsOneWidget);
    });

    testWidgets('shows the no-match state when a filter excludes everything', (tester) async {
      final ring = LogRing(capacity: 10)..add(_rec(LogLevel.debug, 'x', 'only-debug'));
      await tester.pumpWidget(harness(f, OutputView(ring: ring)));
      await tester.pumpAndSettle();
      // Cycle level debug → info, hiding the only (debug) record.
      await tester.tap(find.ancestor(of: find.byWidgetPredicate((w) => _textIs(w, 'Level: debug')), matching: find.byType(GestureDetector)));
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => _textIs(w, 'No output matches the filter.')), findsOneWidget);
    });

    testWidgets('follows the tail, shows jump-to-latest on scroll-up, resumes on tap', (tester) async {
      final ring = LogRing(capacity: 500);
      for (var i = 0; i < 60; i++) {
        ring.add(_rec(LogLevel.info, 'ipc', 'line $i'));
      }
      // Bounded viewport so the list actually scrolls (shared harness is
      // unbounded; impose a tight box).
      await tester.pumpWidget(harness(f, SizedBox(width: 600, height: 140, child: OutputView(ring: ring))));
      await tester.pumpAndSettle();
      // A new record auto-scrolls to the tail (follow).
      ring.add(_rec(LogLevel.info, 'ipc', 'tail line'));
      await tester.pump();
      await tester.pump();
      // Scroll up (drag content down) → follow pauses, pill appears.
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 250));
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => _textIs(w, 'Jump to latest ↓')), findsOneWidget);
      // Tap it → resume follow, pill gone.
      await tester.tap(find.byWidgetPredicate((w) => _textIs(w, 'Jump to latest ↓')));
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => _textIs(w, 'Jump to latest ↓')), findsNothing);
    });

    testWidgets('Clear empties the view', (tester) async {
      await tester.pumpWidget(harness(f, OutputView(ring: _seeded())));
      await tester.pumpAndSettle();
      await tester.tap(find.ancestor(of: find.byWidgetPredicate((w) => _textIs(w, 'Clear')), matching: find.byType(GestureDetector)));
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => _textIs(w, 'alpha')), findsNothing);
      expect(find.byWidgetPredicate((w) => _textIs(w, 'No output yet.')), findsOneWidget);
    });
  });
}
