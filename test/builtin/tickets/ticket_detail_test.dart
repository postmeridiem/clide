/// Tests for the tickets detail reader after the ReaderNav migration
/// (T-199): the controller loads on 'load', the extension reveals a
/// static tab (no per-click churn), and the view drives back/forward +
/// pin through the retained nav.
library;

import 'package:clide/builtin/tickets/src/extension.dart';
import 'package:clide/builtin/tickets/src/ticket_detail_controller.dart';
import 'package:clide/builtin/tickets/src/ticket_detail_view.dart';
import 'package:clide/clide.dart';
import 'package:clide/extension/extension.dart' show LayoutPresetContribution, LayoutSlot;
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

IpcResponse _ticket(String id) => IpcResponse.ok(
  id: '',
  data: {
    'id': id,
    'title': 'Ticket $id',
    'type': 'task',
    'status': 'backlog',
    'priority': 'medium',
    'description': 'Body of $id',
    'ancestors': <Object?>[],
    'decisions': <Object?>[],
  },
);

void main() {
  group('TicketDetailController — loads on load (T-199)', () {
    late KernelFixture f;
    TicketDetailController? c;
    setUp(() async {
      f = await KernelFixture.create();
      f.ipc.stub('pql.tickets.show', (args) async => _ticket(args['id'] as String? ?? '?'));
    });
    tearDown(() async {
      c?.dispose();
      c = null;
      await f.dispose();
    });

    test('a load message loads the ticket', () async {
      c = TicketDetailController(ipc: f.ipc, messages: f.services.messages);
      f.services.messages.publish('builtin.tickets', 'load', {'id': 'T-1'});
      await Future<void>.delayed(Duration.zero);
      expect(c!.detail?.id, 'T-1');
    });

    test('a bare selection does NOT load (the nav re-emits as load)', () async {
      c = TicketDetailController(ipc: f.ipc, messages: f.services.messages);
      f.services.messages.publish('builtin.tickets', 'selection', {'id': 'T-9'});
      await Future<void>.delayed(Duration.zero);
      expect(c!.detail, isNull);
    });
  });

  group('TicketsExtension — static tab reveal (T-199)', () {
    late KernelFixture f;
    setUp(() async {
      f = await KernelFixture.create();
      f.services.panels.registerSlot(const SlotDefinition(id: Slots.contextPanel, position: SlotPosition.right));
      f.services.arrangement.applyPreset(
        const LayoutPresetContribution(
          id: 'test',
          displayName: 'test',
          slots: [LayoutSlot(slot: Slots.contextPanel, position: SlotPosition.right, visible: false)],
        ),
      );
      f.services.extensions.register(TicketsExtension());
      await f.services.extensions.activate('builtin.tickets');
    });
    tearDown(() => f.dispose());

    test('selection reveals + activates the static detail tab without churn', () async {
      f.services.messages.publish('builtin.tickets', 'selection', {'id': 'T-1'});
      await Future<void>.delayed(Duration.zero);
      f.services.messages.publish('builtin.tickets', 'selection', {'id': 'T-2'});
      await Future<void>.delayed(Duration.zero);
      expect(f.services.panels.activeTabIn(Slots.contextPanel), 'tickets.detail');
      expect(f.services.panels.tabsFor(Slots.contextPanel).where((t) => t.id == 'tickets.detail').length, 1);
      expect(f.services.arrangement.isVisible(Slots.contextPanel), isTrue);
    });
  });

  group('TicketDetailView — nav-driven (T-199)', () {
    late KernelFixture f;
    setUp(() async {
      f = await KernelFixture.create();
      f.ipc.stub('pql.tickets.show', (args) async => _ticket(args['id'] as String? ?? '?'));
    });
    tearDown(() => f.dispose());

    Future<void> open(WidgetTester tester, String id) async {
      f.services.readerNav.navFor('builtin.tickets', dataKey: 'id').open(id);
      await pumpAsync(tester);
    }

    Future<void> pumpView(WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(harness(f, const TicketDetailView()));
      await pumpAsync(tester);
    }

    testWidgets('opening a ticket loads it; back returns to the previous', (tester) async {
      await pumpView(tester);
      await open(tester, 'T-1');
      await open(tester, 'T-2');
      expect(find.text('Ticket T-2'), findsWidgets);

      await tester.tap(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Back' && (w.properties.enabled ?? true)).first);
      await pumpAsync(tester);
      expect(find.text('Ticket T-1'), findsWidgets);
    });

    testWidgets('pin toggle shows jump-to-pin and toggles off', (tester) async {
      await pumpView(tester);
      await open(tester, 'T-1');
      await tester.tap(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Pin').first);
      await pumpAsync(tester);
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Jump to pin'), findsOneWidget);
      await tester.tap(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Unpin').first);
      await pumpAsync(tester);
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Jump to pin'), findsNothing);
    });

    testWidgets('renders parents, decisions, assignee, and applies a status change', (tester) async {
      Map<String, Object?>? statusArgs;
      f.ipc.stub(
        'pql.tickets.show',
        (args) async => IpcResponse.ok(
          id: '',
          data: {
            'id': 'T-1',
            'title': 'Rich ticket',
            'type': 'task',
            'status': 'backlog',
            'priority': 'high',
            'assigned_to': 'alice',
            'description': 'body',
            'ancestors': [
              {'id': 'T-9', 'title': 'Parent epic', 'type': 'epic'},
            ],
            'decisions': [
              {'id': 'D-1', 'title': 'Decision one', 'type': 'confirmed', 'domain': 'architecture'},
            ],
          },
        ),
      );
      f.ipc.stub('pql.tickets.status', (args) async {
        statusArgs = args;
        return IpcResponse.ok(id: '', data: const {});
      });
      await pumpView(tester);
      await open(tester, 'T-1');

      expect(find.text('high'), findsWidgets);
      expect(find.textContaining('assigned: alice'), findsOneWidget);
      expect(find.text('PARENT TREE'), findsOneWidget);
      expect(find.text('Parent epic'), findsOneWidget);
      expect(find.text('REFERENCED DECISIONS'), findsOneWidget);
      expect(find.text('Decision one'), findsOneWidget);

      // Tap the READY status control (current is backlog → tappable).
      await tester.tap(find.text('READY'));
      await pumpAsync(tester);
      expect(statusArgs?['status'], 'ready');
      expect(statusArgs?['ids'], ['T-1']);
    });
  });
}
