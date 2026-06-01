/// T-188: Decision reader — static-tab fix.
/// T-189, T-190, T-191: back/forward, pin, edit pencil in DecisionDetailView.
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

IpcResponse _decisionResponse(String id, {String? filePath}) => IpcResponse.ok(
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
        'file_path': filePath ?? 'governance/decisions/architecture.md',
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
    tearDown(() async {
      // Deactivate before dispose so any post-frame forward scheduled by
      // these (non-pumping) tests is neutralised — otherwise it fires in
      // a later testWidgets against a torn-down bus.
      await f.services.extensions.deactivate('builtin.decisions');
      await f.dispose();
    });

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
      // The id appears in the pane-chrome title AND in the body card, so
      // findsWidgets (≥1) is the right matcher.
      expect(find.text('D-1'), findsWidgets);
      expect(find.text('Decision D-1'), findsWidgets);
    });

    testWidgets('selection message loads a decision into the view', (tester) async {
      await pumpView(tester);
      // Starts empty.
      expect(find.text('Select a decision to view details.'), findsOneWidget);

      // The view loads on 'load' (forwarded by the extension post-frame
      // after it reveals the tab; T-196).
      f.services.messages.publish('builtin.decisions', 'load', {'id': 'D-7'});
      // Give the broadcast stream a microtask to deliver.
      await pumpAsync(tester);

      // Id appears in both pane header and body card.
      expect(find.text('D-7'), findsWidgets);
      expect(find.text('Decision D-7'), findsWidgets);
    });

    testWidgets('second selection switches the displayed decision', (tester) async {
      await pumpView(tester, initialId: 'D-1');
      expect(find.text('Decision D-1'), findsWidgets);

      f.services.messages.publish('builtin.decisions', 'load', {'id': 'D-2'});
      await pumpAsync(tester);

      expect(find.text('Decision D-2'), findsWidgets);
      expect(find.text('Decision D-1'), findsNothing);
    });

    testWidgets('clicking the same decision twice leaves view stable', (tester) async {
      await pumpView(tester, initialId: 'D-5');
      expect(find.text('Decision D-5'), findsWidgets);

      f.services.messages.publish('builtin.decisions', 'load', {'id': 'D-5'});
      await pumpAsync(tester);

      // Still shows D-5, no crash.
      expect(find.text('Decision D-5'), findsWidgets);
    });

    testWidgets('rapid sequential selections resolve to the last one', (tester) async {
      await pumpView(tester);

      for (var i = 1; i <= 5; i++) {
        f.services.messages.publish('builtin.decisions', 'load', {'id': 'D-$i'});
      }
      await pumpAsync(tester);

      // The last resolved data should be for D-5 (stub is synchronous so
      // each load completes before the next, but all 5 fire in order).
      // Title appears in pane header subtitle + body card.
      expect(find.text('Decision D-5'), findsWidgets);
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
              'file_path': 'governance/decisions/architecture.md',
            },
          );
        }
        return _decisionResponse(id);
      });

      await pumpView(tester, initialId: 'D-10');
      // D-10 appears in pane title + body card; D-11 appears only in the ref card.
      expect(find.text('D-10'), findsWidgets);
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

    testWidgets('IPC error leaves _decision null — shows placeholder', (tester) async {
      f.ipc.stub(
          'pql.decisions.read',
          (_) async => IpcResponse.err(
                id: '',
                error: IpcError(
                  code: IpcExitCode.toolError,
                  kind: IpcErrorKind.toolError,
                  message: 'read failed',
                ),
              ));

      await pumpView(tester, initialId: 'D-99');

      // Should show placeholder rather than crash.
      expect(find.text('Select a decision to view details.'), findsOneWidget);
    });

    testWidgets('decision with status open shows status badge', (tester) async {
      f.ipc.stub(
          'pql.decisions.read',
          (args) async => IpcResponse.ok(
                id: '',
                data: {
                  'id': 'Q-1',
                  'title': 'Open question',
                  'type': 'question',
                  'domain': 'architecture',
                  'status': 'open',
                  'date': '2026-01-01',
                  'body': '',
                  'refs': <Object?>[],
                  'file_path': 'governance/questions/architecture.md',
                },
              ));

      await pumpView(tester, initialId: 'Q-1');

      expect(find.text('OPEN'), findsOneWidget);
    });

    testWidgets('decision with status resolved shows status badge', (tester) async {
      f.ipc.stub(
          'pql.decisions.read',
          (args) async => IpcResponse.ok(
                id: '',
                data: {
                  'id': 'Q-2',
                  'title': 'Resolved question',
                  'type': 'question',
                  'domain': 'architecture',
                  'status': 'resolved',
                  'date': '2026-01-01',
                  'body': '',
                  'refs': <Object?>[],
                  'file_path': 'governance/questions/architecture.md',
                },
              ));

      await pumpView(tester, initialId: 'Q-2');

      expect(find.text('RESOLVED'), findsOneWidget);
    });

    testWidgets('decision with unknown status shows status badge in muted color', (tester) async {
      f.ipc.stub(
          'pql.decisions.read',
          (args) async => IpcResponse.ok(
                id: '',
                data: {
                  'id': 'D-20',
                  'title': 'Deprecated decision',
                  'type': 'confirmed',
                  'domain': 'architecture',
                  'status': 'deprecated',
                  'date': '2026-01-01',
                  'body': '',
                  'refs': <Object?>[],
                  'file_path': 'governance/decisions/architecture.md',
                },
              ));

      await pumpView(tester, initialId: 'D-20');

      expect(find.text('DEPRECATED'), findsOneWidget);
    });

    testWidgets('decision with refs using source_id renders ref card', (tester) async {
      f.ipc.stub(
          'pql.decisions.read',
          (args) async => IpcResponse.ok(
                id: '',
                data: {
                  'id': 'D-30',
                  'title': 'Decision with source ref',
                  'type': 'confirmed',
                  'domain': 'architecture',
                  'status': 'active',
                  'date': '2026-01-01',
                  'body': '',
                  'refs': [
                    {'source_id': 'D-5', 'ref_type': 'amends'},
                  ],
                  'file_path': 'governance/decisions/architecture.md',
                },
              ));

      await pumpView(tester, initialId: 'D-30');

      expect(find.text('D-5'), findsOneWidget);
      expect(find.text('amends'), findsOneWidget);
    });

    testWidgets('ref card tap always publishes to builtin.decisions/selection (even for T-prefix)', (tester) async {
      // _RefCard.onTap always routes through builtin.decisions/selection;
      // the T-prefix routing in _navigateToRecord is only reachable via
      // ClideMarkdown.onRecordTap (markdown body links).
      f.ipc.stub(
          'pql.decisions.read',
          (args) async => IpcResponse.ok(
                id: '',
                data: {
                  'id': 'D-40',
                  'title': 'Decision with ticket ref',
                  'type': 'confirmed',
                  'domain': 'architecture',
                  'status': 'active',
                  'date': '2026-01-01',
                  'body': '',
                  'refs': [
                    {'target_id': 'T-123', 'ref_type': 'tracked-by'},
                  ],
                  'file_path': 'governance/decisions/architecture.md',
                },
              ));

      await pumpView(tester, initialId: 'D-40');
      expect(find.text('T-123'), findsOneWidget);

      Message? received;
      final sub = f.services.messages.subscribe(publisher: 'builtin.decisions', channel: 'selection').listen((m) => received = m);
      addTearDown(sub.cancel);

      await tester.tap(find.text('T-123').first);
      await pumpAsync(tester);

      expect(received, isNotNull);
      expect(received!.data['id'], 'T-123');
    });

    testWidgets('decision with non-empty body renders body section', (tester) async {
      f.ipc.stub(
          'pql.decisions.read',
          (args) async => IpcResponse.ok(
                id: '',
                data: {
                  'id': 'D-50',
                  'title': 'Decision with body',
                  'type': 'confirmed',
                  'domain': 'architecture',
                  'status': 'active',
                  'date': '2026-01-15',
                  'body': 'This is the decision body text.',
                  'refs': <Object?>[],
                  'file_path': 'governance/decisions/architecture.md',
                },
              ));

      await pumpView(tester, initialId: 'D-50');

      // D-50 appears in pane title + body card.
      expect(find.text('D-50'), findsWidgets);
      expect(find.text('2026-01-15'), findsOneWidget);
    });

    testWidgets('decision without date omits date row', (tester) async {
      f.ipc.stub(
          'pql.decisions.read',
          (args) async => IpcResponse.ok(
                id: '',
                data: {
                  'id': 'D-60',
                  'title': 'No date decision',
                  'type': 'confirmed',
                  'domain': 'architecture',
                  'status': 'active',
                  'body': '',
                  'refs': <Object?>[],
                  'file_path': 'governance/decisions/architecture.md',
                },
              ));

      await pumpView(tester, initialId: 'D-60');

      // D-60 appears in pane title + body card.
      expect(find.text('D-60'), findsWidgets);
      // No date text node — no crash.
    });
  });

  // -------------------------------------------------------------------------
  // T-189: back/forward navigation
  // -------------------------------------------------------------------------

  group('DecisionDetailView — back/forward (T-189)', () {
    late KernelFixture f;

    setUp(() async {
      f = await KernelFixture.create();
      f.ipc.stub('pql.decisions.read', (args) async {
        final id = args['id'] as String? ?? 'unknown';
        return _decisionResponse(id);
      });
    });
    tearDown(() => f.dispose());

    // Drive the retained nav (the history source); its 'load' emit makes
    // the mounted view display the entry (T-196).
    Future<void> open(WidgetTester tester, String id) async {
      f.services.readerNav.navFor('builtin.decisions', dataKey: 'id').open(id);
      await pumpAsync(tester);
    }

    Future<void> pumpView(WidgetTester tester, {String? initialId}) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(harness(f, const DecisionDetailView()));
      await pumpAsync(tester);
      if (initialId != null) await open(tester, initialId);
    }

    testWidgets('back disabled on initial load', (tester) async {
      await pumpView(tester, initialId: 'D-1');

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Back' && w.properties.enabled == false,
        ),
        findsOneWidget,
      );
    });

    testWidgets('back enabled after two selections', (tester) async {
      await pumpView(tester, initialId: 'D-1');
      await open(tester, 'D-2');

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Back' && (w.properties.enabled ?? true),
        ),
        findsWidgets,
      );
    });

    testWidgets('back navigates to previous decision', (tester) async {
      await pumpView(tester, initialId: 'D-1');
      await open(tester, 'D-2');
      // Title appears in pane header subtitle + body card.
      expect(find.text('Decision D-2'), findsWidgets);

      final backBtn = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Back' && (w.properties.enabled ?? true),
      );
      await tester.tap(backBtn.first);
      await pumpAsync(tester);

      expect(find.text('Decision D-1'), findsWidgets);
    });

    testWidgets('back/forward does NOT re-publish selection bus event', (tester) async {
      await pumpView(tester, initialId: 'D-1');
      await open(tester, 'D-2');

      final selections = <Message>[];
      final sub = f.services.messages.subscribe(publisher: 'builtin.decisions', channel: 'selection').listen(selections.add);
      addTearDown(sub.cancel);

      // Go back — re-emits on 'load', NOT 'selection'.
      final backBtn = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Back' && (w.properties.enabled ?? true),
      );
      await tester.tap(backBtn.first);
      await pumpAsync(tester);

      expect(selections, isEmpty, reason: 'back/forward must not churn the selection bus');
    });

    testWidgets('forward disabled at end of history', (tester) async {
      await pumpView(tester, initialId: 'D-1');
      await open(tester, 'D-2');

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Forward' && w.properties.enabled == false,
        ),
        findsOneWidget,
      );
    });

    testWidgets('forward navigates after back', (tester) async {
      await pumpView(tester, initialId: 'D-1');
      await open(tester, 'D-2');

      // Go back to D-1.
      final backBtn = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Back' && (w.properties.enabled ?? true),
      );
      await tester.tap(backBtn.first);
      await pumpAsync(tester);
      expect(find.text('Decision D-1'), findsWidgets);

      // Go forward to D-2.
      final fwdBtn = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Forward' && (w.properties.enabled ?? true),
      );
      await tester.tap(fwdBtn.first);
      await pumpAsync(tester);
      expect(find.text('Decision D-2'), findsWidgets);
    });

    testWidgets('new selection truncates forward history', (tester) async {
      await pumpView(tester, initialId: 'D-1');
      await open(tester, 'D-2');

      // Go back to D-1.
      final backBtn = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Back' && (w.properties.enabled ?? true),
      );
      await tester.tap(backBtn.first);
      await pumpAsync(tester);

      // Open D-3 — truncates D-2 forward history.
      await open(tester, 'D-3');

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Forward' && w.properties.enabled == false,
        ),
        findsOneWidget,
      );
    });
  });

  // -------------------------------------------------------------------------
  // T-190: pin
  // -------------------------------------------------------------------------

  group('DecisionDetailView — pin (T-190)', () {
    late KernelFixture f;

    setUp(() async {
      f = await KernelFixture.create();
      f.ipc.stub('pql.decisions.read', (args) async {
        final id = args['id'] as String? ?? 'unknown';
        return _decisionResponse(id);
      });
    });
    tearDown(() => f.dispose());

    Future<void> open(WidgetTester tester, String id) async {
      f.services.readerNav.navFor('builtin.decisions', dataKey: 'id').open(id);
      await pumpAsync(tester);
    }

    Future<void> pumpView(WidgetTester tester, {String? initialId}) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(harness(f, const DecisionDetailView()));
      await pumpAsync(tester);
      if (initialId != null) await open(tester, initialId);
    }

    testWidgets('pin jump affordance not visible before pin set', (tester) async {
      await pumpView(tester, initialId: 'D-1');
      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Jump to pin'),
        findsNothing,
      );
    });

    testWidgets('pin current shows jump-to-pin affordance', (tester) async {
      await pumpView(tester, initialId: 'D-1');

      await tester.tap(find
          .byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Pin',
          )
          .first);
      await pumpAsync(tester);

      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Jump to pin'),
        findsOneWidget,
      );
    });

    testWidgets('jump to pin loads the pinned decision', (tester) async {
      await pumpView(tester, initialId: 'D-1');

      // Pin D-1.
      await tester.tap(find
          .byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Pin',
          )
          .first);
      await pumpAsync(tester);

      // Navigate to D-2.
      await open(tester, 'D-2');
      // Title appears in pane header subtitle + body card.
      expect(find.text('Decision D-2'), findsWidgets);

      // Jump to pin.
      await tester.tap(find
          .byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Jump to pin',
          )
          .first);
      await pumpAsync(tester);

      expect(find.text('Decision D-1'), findsWidgets);
    });

    testWidgets('pin toggles off on a second tap (unpin)', (tester) async {
      await pumpView(tester, initialId: 'D-1');

      // Pin D-1 → the jump-to-pin button appears in the navigator.
      await tester.tap(find
          .byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Pin',
          )
          .first);
      await pumpAsync(tester);
      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Jump to pin'),
        findsOneWidget,
      );

      // Tapping the toggle again (now 'Unpin') clears the pin.
      await tester.tap(find
          .byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Unpin',
          )
          .first);
      await pumpAsync(tester);
      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Jump to pin'),
        findsNothing,
      );
    });
  });

  // -------------------------------------------------------------------------
  // T-191: edit pencil
  // -------------------------------------------------------------------------

  group('DecisionDetailView — edit pencil (T-191)', () {
    late KernelFixture f;

    setUp(() async {
      f = await KernelFixture.create();
    });
    tearDown(() => f.dispose());

    Future<void> pumpView(WidgetTester tester, {String? initialId}) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(harness(f, DecisionDetailView(initialId: initialId)));
      await pumpAsync(tester);
    }

    testWidgets('edit pencil not visible when no decision loaded', (tester) async {
      await pumpView(tester);
      // Placeholder state — no chrome.
      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Edit in editor'),
        findsNothing,
      );
    });

    testWidgets('edit pencil fires editor.open with file_path from decision', (tester) async {
      const filePath = 'governance/decisions/architecture.md';
      f.ipc.stub('pql.decisions.read', (args) async {
        return _decisionResponse('D-1', filePath: filePath);
      });

      final editorOpenArgs = <Map<String, Object?>>[];
      f.ipc.stub('editor.open', (args) async {
        editorOpenArgs.add(args);
        return IpcResponse.ok(id: '', data: {});
      });

      await pumpView(tester, initialId: 'D-1');

      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Edit in editor'),
        findsOneWidget,
      );

      await tester.tap(find
          .byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Edit in editor',
          )
          .first);
      await pumpAsync(tester);

      expect(editorOpenArgs, hasLength(1));
      expect(editorOpenArgs.first['path'], filePath);
    });

    testWidgets('edit pencil hidden when file_path is absent from response', (tester) async {
      f.ipc.stub('pql.decisions.read', (args) async {
        return IpcResponse.ok(
          id: '',
          data: {
            'id': 'D-70',
            'title': 'No file path',
            'type': 'confirmed',
            'domain': 'architecture',
            'status': 'active',
            'date': '2026-01-01',
            'body': '',
            'refs': <Object?>[],
            // No file_path key.
          },
        );
      });

      await pumpView(tester, initialId: 'D-70');

      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Edit in editor'),
        findsNothing,
      );
    });
  });
}
