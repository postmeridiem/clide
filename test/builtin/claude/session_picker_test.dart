import 'package:clide/builtin/claude/src/session_index.dart';
import 'package:clide/builtin/claude/src/session_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('relativeTime', () {
    final now = DateTime(2026, 5, 23, 12);
    test('buckets recent times', () {
      expect(relativeTime(now.subtract(const Duration(seconds: 10)), now: now), 'just now');
      expect(relativeTime(now.subtract(const Duration(minutes: 5)), now: now), '5m ago');
      expect(relativeTime(now.subtract(const Duration(hours: 3)), now: now), '3h ago');
      expect(relativeTime(now.subtract(const Duration(days: 2)), now: now), '2d ago');
    });

    test('falls back to a date for older sessions', () {
      expect(relativeTime(DateTime(2026, 1, 9), now: now), '2026-01-09');
    });
  });

  group('SessionPickerDialog', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() => f.dispose());

    List<SessionSummary> two() => [
          SessionSummary(id: 'aaa', modified: DateTime.now(), firstUser: 'first a', lastUser: 'last a'),
          SessionSummary(id: 'bbb', modified: DateTime.now(), firstUser: 'first b', lastUser: 'last b'),
        ];

    testWidgets('renders first … last labels and picks with arrow + Enter', (tester) async {
      String? picked;
      await tester.pumpWidget(harness(
        f,
        SessionPickerDialog(sessions: two(), onPick: (id) => picked = id, onCancel: () {}),
      ));
      await tester.pump();
      expect(find.text('first a … last a'), findsOneWidget);
      expect(find.text('first b … last b'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // select bbb
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(picked, 'bbb');
    });

    testWidgets('Escape cancels', (tester) async {
      var cancelled = false;
      await tester.pumpWidget(harness(
        f,
        SessionPickerDialog(sessions: two(), onPick: (_) {}, onCancel: () => cancelled = true),
      ));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(cancelled, isTrue);
    });

    testWidgets('tap picks a row', (tester) async {
      String? picked;
      await tester.pumpWidget(harness(
        f,
        SessionPickerDialog(sessions: two(), onPick: (id) => picked = id, onCancel: () {}),
      ));
      await tester.pump();
      await tester.tap(find.text('first b … last b'));
      expect(picked, 'bbb');
    });

    testWidgets('empty list shows a message', (tester) async {
      await tester.pumpWidget(harness(
        f,
        SessionPickerDialog(sessions: const [], onPick: (_) {}, onCancel: () {}),
      ));
      await tester.pump();
      expect(find.text('No sessions found for this workspace.'), findsOneWidget);
    });
  });
}
