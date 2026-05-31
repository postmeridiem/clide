/// T-188: Decision reader — static-tab fix.
///
/// Verifies that clicking a decision opens it in the static `decisions.detail`
/// context-panel tab (no per-click uncontribute/contribute churn), that a
/// second click switches the content, that clicking the same id twice is
/// idempotent, and that rapid sequential selections all resolve.
///
/// Extension-level tests use [KernelFixture] + the real [ExtensionManager].
/// Widget-level tests use the [harness] wrapper to pump [DecisionDetailView]
/// and assert IPC-stub + message-bus wiring.
library;

import 'package:clide/builtin/decisions/src/decision_detail_view.dart';
import 'package:clide/builtin/decisions/src/extension.dart';
import 'package:clide/extension/extension.dart' show LayoutPresetContribution, LayoutSlot;
import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Registers and activates [DecisionsExtension] against [f], and seeds the
/// [Slots.contextPanel] slot into the arrangement so that
/// [setVisible]/[setCollapsed] have a state entry to mutate.
Future<void> _bootExtension(KernelFixture f) async {
  f.services.panels.registerSlot(
    const SlotDefinition(
      id: Slots.contextPanel,
      position: SlotPosition.right,
    ),
  );
  // Seed the ARRANGEMENT with the context-panel slot (visible:false) so the
  // extension's setVisible/setCollapsed reveal actually round-trips — in
  // production the default-layout preset does this; LayoutArrangement.setVisible
  // is a no-op for a slot it has no state entry for.
  f.services.arrangement.applyPreset(
    const LayoutPresetContribution(
      id: 'test.preset',
      displayName: 'test',
      slots: [
        LayoutSlot(slot: Slots.contextPanel, position: SlotPosition.right, visible: false),
      ],
    ),
  );
  f.services.extensions.register(DecisionsExtension());
  await f.services.extensions.activate('builtin.decisions');
}

/// Publishes a `builtin.decisions / selection` message on [f]'s bus.
void _select(KernelFixture f, String id) {
  f.services.messages.publish('builtin.decisions', 'selection', {'id': id});
}

// ---------------------------------------------------------------------------
// IPC stub: pql.decisions.read
// ---------------------------------------------------------------------------

IpcResponse _decisionResponse(String id) => IpcResponse.ok(
      id: '',
      data: {
        'id': id,
        'title': 'Decision $id',
        'type': 'confirmed',
        'domain': 'architecture',
        'status': 'active',
        'date': '2026-01-01',
        'body': 'Body of $id.',
        'refs': <Object?>[],
      },
    );

// ---------------------------------------------------------------------------
// Extension-level unit tests (no Flutter widgets, no IPC)
// ---------------------------------------------------------------------------

void main() {
  group('DecisionsExtension — static-tab wiring (T-188)', () {
    late KernelFixture f;

    setUp(() async {
      f = await KernelFixture.create();
      await _bootExtension(f);
    });
    tearDown(() => f.dispose());

    test('activate contributes decisions.detail as a static tab', () {
      final tabs = f.services.panels.tabsFor(Slots.contextPanel);
      expect(tabs.any((t) => t.id == 'decisions.detail'), isTrue, reason: 'decisions.detail must be contributed once at activate');
    });

    test('decisions.detail tab count stays at 1 after multiple selections', () async {
      _select(f, 'D-1');
      await Future<void>.delayed(Duration.zero);
      _select(f, 'D-2');
      await Future<void>.delayed(Duration.zero);

      final tabs = f.services.panels.tabsFor(Slots.contextPanel);
      expect(tabs.where((t) => t.id == 'decisions.detail').length, 1, reason: 'no per-click re-contribution — exactly one decisions.detail tab');
    });

    test('selection activates decisions.detail tab', () async {
      _select(f, 'D-1');
      await Future<void>.delayed(Duration.zero);

      expect(f.services.panels.activeTabIn(Slots.contextPanel), 'decisions.detail');
    });

    test('second selection switches to decisions.detail (already active, stays)', () async {
      _select(f, 'D-1');
      await Future<void>.delayed(Duration.zero);
      _select(f, 'D-2');
      await Future<void>.delayed(Duration.zero);

      expect(f.services.panels.activeTabIn(Slots.contextPanel), 'decisions.detail');
    });

    test('clicking the same decision twice leaves decisions.detail active', () async {
      _select(f, 'D-5');
      await Future<void>.delayed(Duration.zero);
      _select(f, 'D-5');
      await Future<void>.delayed(Duration.zero);

      expect(f.services.panels.activeTabIn(Slots.contextPanel), 'decisions.detail');
      expect(f.services.panels.tabsFor(Slots.contextPanel).where((t) => t.id == 'decisions.detail').length, 1);
    });

    test('selection reveals the context panel', () async {
      // The panel starts with visible=false for this slot (no preset applied,
      // but registerSlot sets the default state; setVisible is a no-op when
      // visible is already true, so we flip it first).
      f.services.arrangement.setVisible(Slots.contextPanel, false);
      f.services.arrangement.setCollapsed(Slots.contextPanel, true);

      _select(f, 'D-3');
      await Future<void>.delayed(Duration.zero);

      expect(f.services.arrangement.isVisible(Slots.contextPanel), isTrue, reason: 'panel must be made visible on selection');
      expect(f.services.arrangement.isCollapsed(Slots.contextPanel), isFalse, reason: 'panel must be un-collapsed on selection');
    });

    test('rapid sequential selections all leave decisions.detail active', () async {
      for (var i = 1; i <= 10; i++) {
        _select(f, 'D-$i');
      }
      await Future<void>.delayed(Duration.zero);

      expect(f.services.panels.activeTabIn(Slots.contextPanel), 'decisions.detail');
      expect(f.services.panels.tabsFor(Slots.contextPanel).where((t) => t.id == 'decisions.detail').length, 1);
    });

    test('null id in selection message is ignored', () async {
      // Seed a valid tab selection first.
      _select(f, 'D-1');
      await Future<void>.delayed(Duration.zero);

      // Then send a bad message.
      f.services.messages.publish('builtin.decisions', 'selection', {'id': null});
      await Future<void>.delayed(Duration.zero);

      // Tab still active, still only one.
      expect(f.services.panels.activeTabIn(Slots.contextPanel), 'decisions.detail');
      expect(f.services.panels.tabsFor(Slots.contextPanel).where((t) => t.id == 'decisions.detail').length, 1);
    });

    test('deactivate cancels subscription — selections after deactivate are no-ops', () async {
      await f.services.extensions.deactivate('builtin.decisions');

      // After deactivation contributions are removed, so no decisions.detail
      // tab at all — but the panel activation path must not fire either.
      f.services.panels.registerSlot(
        const SlotDefinition(
          id: Slots.contextPanel,
          position: SlotPosition.right,
        ),
      );
      f.services.messages.publish('builtin.decisions', 'selection', {'id': 'D-99'});
      await Future<void>.delayed(Duration.zero);

      expect(f.services.panels.activeTabIn(Slots.contextPanel), isNot('decisions.detail'),
          reason: 'deactivated extension must not respond to selection messages');
    });
  });

  // -------------------------------------------------------------------------
  // Widget tests for DecisionDetailView
  // -------------------------------------------------------------------------

  group('DecisionDetailView — widget (T-188)', () {
    late KernelFixture f;

    setUp(() async {
      f = await KernelFixture.create();
      // Stub the IPC call made by _load().
      f.ipc.stub('pql.decisions.read', (args) async {
        final id = args['id'] as String? ?? 'unknown';
        return _decisionResponse(id);
      });
    });
    tearDown(() => f.dispose());

    Future<void> pumpView(WidgetTester tester, {String? initialId}) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        harness(f, DecisionDetailView(initialId: initialId)),
      );
      await pumpAsync(tester);
    }

    testWidgets('shows placeholder when no decision selected', (tester) async {
      await pumpView(tester);
      expect(find.text('Select a decision to view details.'), findsOneWidget);
    });

    testWidgets('loads and renders initialId on first mount', (tester) async {
      await pumpView(tester, initialId: 'D-1');
      expect(find.text('D-1'), findsOneWidget);
      expect(find.text('Decision D-1'), findsOneWidget);
    });

    testWidgets('selection message loads a decision into the view', (tester) async {
      await pumpView(tester);
      // Starts empty.
      expect(find.text('Select a decision to view details.'), findsOneWidget);

      // Publish a selection.
      f.services.messages.publish('builtin.decisions', 'selection', {'id': 'D-7'});
      // Give the broadcast stream a microtask to deliver.
      await pumpAsync(tester);

      expect(find.text('D-7'), findsOneWidget);
      expect(find.text('Decision D-7'), findsOneWidget);
    });

    testWidgets('second selection switches the displayed decision', (tester) async {
      await pumpView(tester, initialId: 'D-1');
      expect(find.text('Decision D-1'), findsOneWidget);

      f.services.messages.publish('builtin.decisions', 'selection', {'id': 'D-2'});
      await pumpAsync(tester);

      expect(find.text('Decision D-2'), findsOneWidget);
      expect(find.text('Decision D-1'), findsNothing);
    });

    testWidgets('clicking the same decision twice leaves view stable', (tester) async {
      await pumpView(tester, initialId: 'D-5');
      expect(find.text('Decision D-5'), findsOneWidget);

      f.services.messages.publish('builtin.decisions', 'selection', {'id': 'D-5'});
      await pumpAsync(tester);

      // Still shows D-5, no crash, no duplicate.
      expect(find.text('Decision D-5'), findsOneWidget);
    });

    testWidgets('rapid sequential selections resolve to the last one', (tester) async {
      await pumpView(tester);

      for (var i = 1; i <= 5; i++) {
        f.services.messages.publish('builtin.decisions', 'selection', {'id': 'D-$i'});
      }
      await pumpAsync(tester);

      // The last resolved data should be for D-5 (stub is synchronous so
      // each load completes before the next, but all 5 fire in order).
      expect(find.text('Decision D-5'), findsOneWidget);
    });

    testWidgets('cross-reference tap publishes a new selection', (tester) async {
      // Stub: D-10 has a ref pointing to D-11.
      f.ipc.stub('pql.decisions.read', (args) async {
        final id = args['id'] as String? ?? 'unknown';
        if (id == 'D-10') {
          return IpcResponse.ok(
            id: '',
            data: {
              'id': 'D-10',
              'title': 'Decision D-10',
              'type': 'confirmed',
              'domain': 'architecture',
              'status': 'active',
              'date': '2026-01-01',
              'body': '',
              'refs': [
                {'target_id': 'D-11', 'ref_type': 'implements'},
              ],
            },
          );
        }
        return _decisionResponse(id);
      });

      await pumpView(tester, initialId: 'D-10');
      expect(find.text('D-10'), findsOneWidget);
      expect(find.text('D-11'), findsOneWidget);

      // Tap the ref card — it should publish selection for D-11.
      Message? received;
      final sub = f.services.messages.subscribe(publisher: 'builtin.decisions', channel: 'selection').listen((m) => received = m);
      addTearDown(sub.cancel);

      await tester.tap(find.text('D-11').first);
      await pumpAsync(tester);

      expect(received, isNotNull);
      expect(received!.data['id'], 'D-11');
    });
  });
}
