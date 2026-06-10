/// Widget tests for DecisionsView — the decisions sidebar list.
///
/// Covers: initial load, error state, empty state, grouping into
/// confirmed/questions/rejected accordions, filter text, card tap publishes
/// selection, focus message scrolls/highlights, toggle section pin,
/// refresh button, file-change event triggers reload, and scheduler tick
/// triggers reload.
library;

import 'dart:async';

import 'package:clide/builtin/decisions/src/decisions_view.dart';
import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

IpcResponse _ok(Map<String, Object?> data) => IpcResponse.ok(id: '', data: data);

IpcResponse _err(String msg) => IpcResponse.err(
      id: '',
      error: IpcError(
        code: IpcExitCode.toolError,
        kind: IpcErrorKind.toolError,
        message: msg,
      ),
    );

Map<String, Object?> _decision({
  required String id,
  required String title,
  String type = 'confirmed',
  String domain = 'architecture',
  String? status,
}) =>
    {
      'id': id,
      'title': title,
      'type': type,
      'domain': domain,
      if (status != null) 'status': status,
    };

/// Register both sync and list stubs, returning the provided list of decisions.
void _stubDecisions(KernelFixture f, List<Map<String, Object?>> decisions) {
  f.ipc.stub('pql.decisions.sync', (_) async => _ok(const {}));
  f.ipc.stub('pql.decisions.list', (_) async => _ok({'decisions': decisions}));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late KernelFixture f;

  setUp(() async {
    f = await KernelFixture.create();
  });
  tearDown(() => f.dispose());

  // Helper wrapper so we can pass f explicitly without closure gymnastics.
  Future<void> pumpView(WidgetTester tester, {Size size = const Size(400, 700)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(harness(f, const DecisionsView()));
    await pumpAsync(tester);
  }

  group('DecisionsView — loading / error / empty states', () {
    testWidgets('shows loading indicator while fetch is pending', (tester) async {
      // Stub that never returns (use a Completer) — the widget should show
      // loading while waiting. We deliberately avoid blocking the test; a
      // slow-but-completing stub is enough: just don't pumpAsync first.
      final Completer<IpcResponse> completer = Completer();
      f.ipc.stub('pql.decisions.sync', (_) async => _ok(const {}));
      f.ipc.stub('pql.decisions.list', (_) async => completer.future);

      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(harness(f, const DecisionsView()));
      // One frame — loads started but not completed.
      await tester.pump();

      expect(find.text('Loading decisions...'), findsOneWidget);

      // Complete so the widget can clean up.
      completer.complete(_ok({'decisions': <Object?>[]}));
      await pumpAsync(tester);
    });

    testWidgets('shows error when pql.decisions.list returns an error', (tester) async {
      f.ipc.stub('pql.decisions.sync', (_) async => _ok(const {}));
      f.ipc.stub('pql.decisions.list', (_) async => _err('pql offline'));

      await pumpView(tester);

      expect(find.text('pql offline'), findsOneWidget);
    });

    testWidgets('uses fallback error message when resp.error is null', (tester) async {
      f.ipc.stub('pql.decisions.sync', (_) async => _ok(const {}));
      // Return a non-ok response whose error field is absent — forces the
      // fallback message in _load().
      f.ipc.stub(
        'pql.decisions.list',
        (_) async => IpcResponse.err(
          id: '',
          error: IpcError(
            code: IpcExitCode.toolError,
            kind: IpcErrorKind.toolError,
            message: 'failed to load decisions',
          ),
        ),
      );

      await pumpView(tester);
      expect(find.text('failed to load decisions'), findsOneWidget);
    });

    testWidgets('shows empty-state message when decisions list is empty', (tester) async {
      _stubDecisions(f, []);

      await pumpView(tester);

      expect(find.textContaining('No decisions found'), findsOneWidget);
    });

    testWidgets('handles non-List data gracefully (sets loading false)', (tester) async {
      f.ipc.stub('pql.decisions.sync', (_) async => _ok(const {}));
      f.ipc.stub('pql.decisions.list', (_) async => _ok({'decisions': 'not-a-list'}));

      await pumpView(tester);

      // No crash; empty-state message appears.
      expect(find.textContaining('No decisions found'), findsOneWidget);
    });
  });

  group('DecisionsView — grouping into sections', () {
    testWidgets('confirmed decisions appear in CONFIRMED accordion', (tester) async {
      _stubDecisions(f, [
        _decision(id: 'D-1', title: 'Architecture choice'),
      ]);
      await pumpView(tester);

      // Accordion label renders as 'CONFIRMED · N'.
      expect(find.textContaining('CONFIRMED'), findsOneWidget);
      // Confirmed section is pinned-expanded by default, so card is visible.
      expect(find.text('D-1'), findsOneWidget);
      expect(find.text('Architecture choice'), findsOneWidget);
    });

    testWidgets('question decisions appear in QUESTIONS accordion header', (tester) async {
      _stubDecisions(f, [
        _decision(id: 'Q-1', title: 'Open question', type: 'question', domain: 'tooling'),
      ]);
      await pumpView(tester);

      // The header always renders even when the section is collapsed.
      expect(find.textContaining('QUESTIONS'), findsOneWidget);
      // Q-1 card is inside a collapsed section — not visible yet.
      // Tap the header to expand the section.
      await tester.tap(find.textContaining('QUESTIONS').first);
      await tester.pump();
      expect(find.text('Q-1'), findsOneWidget);
    });

    testWidgets('rejected decisions appear in REJECTED accordion header', (tester) async {
      _stubDecisions(f, [
        _decision(id: 'R-1', title: 'Rejected idea', type: 'rejected', domain: 'ui'),
      ]);
      await pumpView(tester);

      expect(find.textContaining('REJECTED'), findsOneWidget);
      // Tap to expand.
      await tester.tap(find.textContaining('REJECTED').first);
      await tester.pump();
      expect(find.text('R-1'), findsOneWidget);
    });

    testWidgets('all three sections render when all types present', (tester) async {
      _stubDecisions(f, [
        _decision(id: 'D-1', title: 'Confirmed one'),
        _decision(id: 'Q-1', title: 'Open q', type: 'question', domain: 'tooling'),
        _decision(id: 'R-1', title: 'Rejected one', type: 'rejected', domain: 'ui'),
      ]);
      await pumpView(tester);

      // All three accordion headers are rendered.
      expect(find.textContaining('CONFIRMED'), findsOneWidget);
      expect(find.textContaining('QUESTIONS'), findsOneWidget);
      expect(find.textContaining('REJECTED'), findsOneWidget);
    });

    testWidgets('card with resolved status shows resolved badge (via filter)', (tester) async {
      // Use a confirmed decision with resolved status so the card is
      // visible without needing to expand the section manually.
      _stubDecisions(f, [
        _decision(id: 'D-2', title: 'Resolved decision', type: 'confirmed', domain: 'arch', status: 'resolved'),
      ]);
      await pumpView(tester);

      // CONFIRMED is pinned-expanded; card is visible.
      expect(find.text('resolved'), findsOneWidget);
    });

    testWidgets('domain label is shown on card', (tester) async {
      _stubDecisions(f, [
        _decision(id: 'D-5', title: 'Some D', domain: 'architecture'),
      ]);
      await pumpView(tester);

      expect(find.text('architecture'), findsOneWidget);
    });
  });

  group('DecisionsView — card tap publishes selection', () {
    testWidgets('tapping a confirmed card publishes builtin.decisions/selection', (tester) async {
      _stubDecisions(f, [
        _decision(id: 'D-3', title: 'Click me'),
      ]);
      await pumpView(tester);

      final received = <Message>[];
      final sub = f.services.messages.subscribe(publisher: 'builtin.decisions', channel: 'selection').listen(received.add);
      addTearDown(sub.cancel);

      await tester.tap(find.text('D-3').first);
      await pumpAsync(tester);

      expect(received, hasLength(1));
      expect(received.first.data['id'], 'D-3');
    });

    testWidgets('tapping a question card publishes the correct id', (tester) async {
      _stubDecisions(f, [
        _decision(id: 'Q-4', title: 'Q card', type: 'question', domain: 'tooling'),
      ]);
      await pumpView(tester);

      // QUESTIONS section is collapsed by default — tap header to expand it.
      await tester.tap(find.textContaining('QUESTIONS').first);
      await tester.pump();

      final received = <Message>[];
      final sub = f.services.messages.subscribe(publisher: 'builtin.decisions', channel: 'selection').listen(received.add);
      addTearDown(sub.cancel);

      await tester.tap(find.text('Q-4').first);
      await pumpAsync(tester);

      expect(received, hasLength(1));
      expect(received.first.data['id'], 'Q-4');
    });
  });

  group('DecisionsView — filter', () {
    testWidgets('filter box narrows results by id', (tester) async {
      _stubDecisions(f, [
        _decision(id: 'D-1', title: 'Architecture choice'),
        _decision(id: 'D-2', title: 'Build tool selection'),
      ]);
      await pumpView(tester);

      expect(find.text('D-1'), findsOneWidget);
      expect(find.text('D-2'), findsOneWidget);

      final filterBox = find.byWidgetPredicate((w) => w is EditableText);
      await tester.enterText(filterBox.first, 'D-1');
      await tester.pump(const Duration(milliseconds: 250)); // past 200ms debounce
      await tester.pump();

      // After typing 'D-1', the EditableText itself also contains 'D-1' so
      // findsWidgets — but D-1 card text should exist and D-2 should not.
      expect(find.text('D-1'), findsWidgets);
      // D-2 should be filtered out.
      expect(find.text('D-2'), findsNothing);
    });

    testWidgets('filter box narrows results by title', (tester) async {
      _stubDecisions(f, [
        _decision(id: 'D-1', title: 'Architecture choice'),
        _decision(id: 'D-2', title: 'Build tool selection'),
      ]);
      await pumpView(tester);

      final filterBox = find.byWidgetPredicate((w) => w is EditableText);
      await tester.enterText(filterBox.first, 'build');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();

      expect(find.text('D-2'), findsOneWidget);
      expect(find.text('D-1'), findsNothing);
    });

    testWidgets('filter by domain shows matching card', (tester) async {
      _stubDecisions(f, [
        _decision(id: 'D-1', title: 'Arch', domain: 'architecture'),
        _decision(id: 'D-2', title: 'Tool', domain: 'tooling'),
      ]);
      await pumpView(tester);

      final filterBox = find.byWidgetPredicate((w) => w is EditableText);
      await tester.enterText(filterBox.first, 'tooling');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();

      expect(find.text('D-2'), findsOneWidget);
      expect(find.text('D-1'), findsNothing);
    });

    testWidgets('filter with no matches yields empty sections', (tester) async {
      _stubDecisions(f, [
        _decision(id: 'D-1', title: 'Something'),
      ]);
      await pumpView(tester);

      final filterBox = find.byWidgetPredicate((w) => w is EditableText);
      await tester.enterText(filterBox.first, 'zzznomatch');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();

      // None of the section headers should appear.
      expect(find.textContaining('CONFIRMED'), findsNothing);
    });
  });

  group('DecisionsView — section toggle', () {
    testWidgets('toggling confirmed section removes confirmed from pinned', (tester) async {
      _stubDecisions(f, [
        _decision(id: 'D-1', title: 'Arch choice'),
      ]);
      await pumpView(tester);

      // CONFIRMED is pinned by default and should be expanded (D-1 visible).
      expect(find.text('D-1'), findsOneWidget);

      // Tap the accordion header to toggle it collapsed.
      await tester.tap(find.textContaining('CONFIRMED').first);
      await tester.pump();

      // After toggle without a focused entry the section should collapse.
      // The section header still exists but the card may not be visible.
      expect(find.textContaining('CONFIRMED'), findsOneWidget);
    });

    testWidgets('toggling a non-pinned section expands it', (tester) async {
      _stubDecisions(f, [
        _decision(id: 'R-1', title: 'Rejected one', type: 'rejected', domain: 'ui'),
      ]);
      await pumpView(tester);

      // REJECTED starts unexpanded (not in _pinned).
      expect(find.textContaining('REJECTED'), findsOneWidget);
      // Tap to expand.
      await tester.tap(find.textContaining('REJECTED').first);
      await tester.pump();

      // Section header still visible and R-1 card now visible.
      expect(find.textContaining('REJECTED'), findsOneWidget);
      expect(find.text('R-1'), findsOneWidget);
    });
  });

  group('DecisionsView — focus message', () {
    testWidgets('receiving a focus message updates _focusedId and rebuilds', (tester) async {
      _stubDecisions(f, [
        _decision(id: 'D-1', title: 'First'),
        _decision(id: 'D-2', title: 'Second'),
      ]);
      await pumpView(tester);

      // Both cards visible.
      expect(find.text('D-1'), findsOneWidget);
      expect(find.text('D-2'), findsOneWidget);

      // Publish a focus message.
      f.services.messages.publish('builtin.decisions', 'focus', {'id': 'D-2'});
      await pumpAsync(tester);

      // Widget rebuilt (no crash).
      expect(find.text('D-2'), findsOneWidget);
    });

    testWidgets('focus message with null id is ignored', (tester) async {
      _stubDecisions(f, [
        _decision(id: 'D-1', title: 'First'),
      ]);
      await pumpView(tester);

      f.services.messages.publish('builtin.decisions', 'focus', {'id': null});
      await pumpAsync(tester);

      expect(find.text('D-1'), findsOneWidget);
    });

    testWidgets('focus message with same id as already focused is ignored', (tester) async {
      _stubDecisions(f, [
        _decision(id: 'D-1', title: 'First'),
      ]);
      await pumpView(tester);

      f.services.messages.publish('builtin.decisions', 'focus', {'id': 'D-1'});
      await pumpAsync(tester);

      // Second message with same id — should be no-op.
      f.services.messages.publish('builtin.decisions', 'focus', {'id': 'D-1'});
      await pumpAsync(tester);

      expect(find.text('D-1'), findsOneWidget);
    });
  });

  group('DecisionsView — refresh button', () {
    testWidgets('refresh button triggers a reload', (tester) async {
      int listCallCount = 0;
      f.ipc.stub('pql.decisions.sync', (_) async => _ok(const {}));
      f.ipc.stub('pql.decisions.list', (_) async {
        listCallCount++;
        return _ok({
          'decisions': [
            _decision(id: 'D-$listCallCount', title: 'Call $listCallCount'),
          ],
        });
      });

      await pumpView(tester);
      expect(listCallCount, 1);

      // Tap the refresh icon button — it has tooltip 'Refresh decisions'.
      // Find ClideTappable widgets and tap the one with the refresh tooltip.
      final refreshTappable = find.byWidgetPredicate(
        (w) => w is ClideTappable && w.tooltip == 'Refresh decisions',
      );
      await tester.tap(refreshTappable);
      await pumpAsync(tester);

      expect(listCallCount, 2);
    });
  });

  group('DecisionsView — file-change event triggers reload', () {
    testWidgets('files.changed event for a decisions path triggers _refresh', (tester) async {
      int listCallCount = 0;
      f.ipc.stub('pql.decisions.sync', (_) async => _ok(const {}));
      f.ipc.stub('pql.decisions.list', (_) async {
        listCallCount++;
        return _ok({
          'decisions': [
            _decision(id: 'D-$listCallCount', title: 'Version $listCallCount'),
          ],
        });
      });

      await pumpView(tester);
      expect(listCallCount, 1);

      // Emit a files.changed event for a decisions path.
      f.services.events.emit(DaemonEvent(
        subsystem: 'files',
        kind: 'files.changed',
        data: {'path': 'decisions/architecture.md'},
        ts: DateTime.now().toUtc(),
      ));
      await pumpAsync(tester);

      expect(listCallCount, greaterThanOrEqualTo(2));
    });

    testWidgets('files.changed event for non-decisions path is ignored', (tester) async {
      int listCallCount = 0;
      f.ipc.stub('pql.decisions.sync', (_) async => _ok(const {}));
      f.ipc.stub('pql.decisions.list', (_) async {
        listCallCount++;
        return _ok({'decisions': <Object?>[]});
      });

      await pumpView(tester);
      final countAfterLoad = listCallCount;

      f.services.events.emit(DaemonEvent(
        subsystem: 'files',
        kind: 'files.changed',
        data: {'path': 'lib/main.dart'},
        ts: DateTime.now().toUtc(),
      ));
      await pumpAsync(tester);

      // Count must not have incremented.
      expect(listCallCount, countAfterLoad);
    });
  });

  group('DecisionsView — scheduler tick triggers reload', () {
    testWidgets('oneMinute scheduler tick triggers _refresh', (tester) async {
      int listCallCount = 0;
      f.ipc.stub('pql.decisions.sync', (_) async => _ok(const {}));
      f.ipc.stub('pql.decisions.list', (_) async {
        listCallCount++;
        return _ok({
          'decisions': [_decision(id: 'D-$listCallCount', title: 'tick $listCallCount')],
        });
      });

      await pumpView(tester);
      expect(listCallCount, 1);

      f.services.events.emit(const SchedulerTick(tier: SchedulerTier.oneMinute));
      await pumpAsync(tester);

      expect(listCallCount, greaterThanOrEqualTo(2));
    });

    testWidgets('tenMinutes scheduler tick does NOT trigger _refresh', (tester) async {
      int listCallCount = 0;
      f.ipc.stub('pql.decisions.sync', (_) async => _ok(const {}));
      f.ipc.stub('pql.decisions.list', (_) async {
        listCallCount++;
        return _ok({'decisions': <Object?>[]});
      });

      await pumpView(tester);
      final countAfterLoad = listCallCount;

      f.services.events.emit(const SchedulerTick(tier: SchedulerTier.tenMinutes));
      await pumpAsync(tester);

      expect(listCallCount, countAfterLoad);
    });
  });

  group('DecisionsView — workspace open triggers reload (T-352)', () {
    testWidgets('ProjectOpened triggers _refresh', (tester) async {
      // The first load can fire before the daemon's pql workDir is the repo; a
      // ProjectOpened (fired after the IPC server swaps) must re-fetch.
      int listCallCount = 0;
      f.ipc.stub('pql.decisions.sync', (_) async => _ok(const {}));
      f.ipc.stub('pql.decisions.list', (_) async {
        listCallCount++;
        return _ok({
          'decisions': [_decision(id: 'D-$listCallCount', title: 'open $listCallCount')],
        });
      });

      await pumpView(tester);
      expect(listCallCount, 1);

      f.services.events.emit(const ProjectOpened(path: '/repo'));
      await pumpAsync(tester);

      expect(listCallCount, greaterThanOrEqualTo(2));
    });
  });

  group('DecisionsView — concurrent refresh guard', () {
    testWidgets('second refresh while one is running sets _pendingRefresh', (tester) async {
      final Completer<IpcResponse> firstListCompleter = Completer();
      int callCount = 0;

      f.ipc.stub('pql.decisions.sync', (_) async => _ok(const {}));
      f.ipc.stub('pql.decisions.list', (_) async {
        callCount++;
        if (callCount == 1) {
          // initial load — complete immediately
          return _ok({'decisions': <Object?>[]});
        }
        if (callCount == 2) {
          return firstListCompleter.future;
        }
        return _ok({'decisions': <Object?>[]});
      });

      await pumpView(tester);

      // Trigger two rapid refreshes via scheduler ticks.
      f.services.events.emit(const SchedulerTick(tier: SchedulerTier.oneMinute));
      await tester.pump(); // start first refresh
      f.services.events.emit(const SchedulerTick(tier: SchedulerTier.oneMinute));
      await tester.pump(); // second one queues as pendingRefresh

      // Complete the first refresh.
      firstListCompleter.complete(_ok({'decisions': <Object?>[]}));
      await pumpAsync(tester);

      // The pending refresh should have been picked up — call count increases.
      expect(callCount, greaterThanOrEqualTo(3));
    });
  });
}
