/// Unit tests for [ReaderHistory] and [ReaderHistoryMixin] (T-189, T-190).
library;

import 'package:clide/builtin/shared/reader_chrome.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// ReaderHistory unit tests (no Flutter needed — plain test())
// ---------------------------------------------------------------------------

void main() {
  group('ReaderHistory', () {
    late ReaderHistory<String> h;

    setUp(() => h = ReaderHistory<String>());

    test('starts empty — canGoBack/Forward false, current null', () {
      expect(h.canGoBack, isFalse);
      expect(h.canGoForward, isFalse);
      expect(h.current, isNull);
    });

    test('push one — current is that entry, no back/forward', () {
      h.push('A');
      expect(h.current, 'A');
      expect(h.canGoBack, isFalse);
      expect(h.canGoForward, isFalse);
    });

    test('push two — canGoBack true, canGoForward false', () {
      h.push('A');
      h.push('B');
      expect(h.current, 'B');
      expect(h.canGoBack, isTrue);
      expect(h.canGoForward, isFalse);
    });

    test('back() after two pushes returns first entry', () {
      h.push('A');
      h.push('B');
      final result = h.back();
      expect(result, 'A');
      expect(h.current, 'A');
      expect(h.canGoBack, isFalse);
      expect(h.canGoForward, isTrue);
    });

    test('forward() after back() returns second entry', () {
      h.push('A');
      h.push('B');
      h.back();
      final result = h.forward();
      expect(result, 'B');
      expect(h.current, 'B');
      expect(h.canGoForward, isFalse);
    });

    test('back() at start returns null', () {
      h.push('A');
      expect(h.back(), isNull);
    });

    test('forward() at end returns null', () {
      h.push('A');
      h.push('B');
      expect(h.forward(), isNull);
    });

    test('new push truncates forward history', () {
      h.push('A');
      h.push('B');
      h.push('C');
      h.back(); // now at B
      h.back(); // now at A
      expect(h.canGoForward, isTrue);

      h.push('D'); // truncates [B, C], appends D
      expect(h.current, 'D');
      expect(h.canGoBack, isTrue);
      expect(h.canGoForward, isFalse);

      final prev = h.back();
      expect(prev, 'A');
    });

    test('pushing duplicate of current is a no-op', () {
      h.push('A');
      h.push('A');
      expect(h.canGoBack, isFalse); // still only one entry
      expect(h.current, 'A');
    });

    test('three entries back/forward round-trip', () {
      h.push('A');
      h.push('B');
      h.push('C');
      expect(h.back(), 'B');
      expect(h.back(), 'A');
      expect(h.forward(), 'B');
      expect(h.forward(), 'C');
      expect(h.canGoForward, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // ReaderHistoryMixin widget integration test — uses a minimal StatefulWidget.
  // -------------------------------------------------------------------------

  group('ReaderHistoryMixin', () {
    testWidgets('pin current / jump-to-pin round-trip', (tester) async {
      String? jumpedTo;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _MixinHarness(onJump: (v) => jumpedTo = v),
        ),
      );

      final state = tester.state<_MixinHarnessState>(find.byType(_MixinHarness));

      // No pin yet.
      expect(state.hasPinned, isFalse);
      expect(state.pinnedEntry, isNull);

      // Push 'A', then pin it.
      state.historyPush('A');
      await tester.pump();
      state.pinCurrent();
      await tester.pump();

      expect(state.hasPinned, isTrue);
      expect(state.pinnedEntry, 'A');

      // Push 'B', jump to pin → should get 'A'.
      state.historyPush('B');
      await tester.pump();
      final pinEntry = state.jumpToPin();
      jumpedTo = pinEntry;
      expect(jumpedTo, 'A');
    });

    testWidgets('pin replaces previous pin', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _MixinHarness(onJump: (_) {}),
        ),
      );

      final state = tester.state<_MixinHarnessState>(find.byType(_MixinHarness));
      state.historyPush('A');
      state.pinCurrent();
      await tester.pump();
      expect(state.pinnedEntry, 'A');

      state.historyPush('B');
      state.pinCurrent();
      await tester.pump();
      expect(state.pinnedEntry, 'B'); // replaced
    });

    testWidgets('historyBack / historyForward returns correct entries', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _MixinHarness(onJump: (_) {}),
        ),
      );

      final state = tester.state<_MixinHarnessState>(find.byType(_MixinHarness));
      state.historyPush('X');
      state.historyPush('Y');
      await tester.pump();

      expect(state.canGoBack, isTrue);
      expect(state.canGoForward, isFalse);

      final back = state.historyBack();
      await tester.pump();
      expect(back, 'X');
      expect(state.canGoBack, isFalse);
      expect(state.canGoForward, isTrue);

      final fwd = state.historyForward();
      await tester.pump();
      expect(fwd, 'Y');
    });

    testWidgets('pinCurrent with empty history is a no-op', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _MixinHarness(onJump: (_) {}),
        ),
      );

      final state = tester.state<_MixinHarnessState>(find.byType(_MixinHarness));
      state.pinCurrent(); // no current entry — must not throw
      await tester.pump();
      expect(state.hasPinned, isFalse);
    });
  });
}

// ---------------------------------------------------------------------------
// Minimal harness widget that mixes in ReaderHistoryMixin.
// ---------------------------------------------------------------------------

class _MixinHarness extends StatefulWidget {
  const _MixinHarness({required this.onJump});
  final void Function(String?) onJump;

  @override
  State<_MixinHarness> createState() => _MixinHarnessState();
}

class _MixinHarnessState extends State<_MixinHarness> with ReaderHistoryMixin<String, _MixinHarness> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
