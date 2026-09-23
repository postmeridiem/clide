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

IpcResponse _ticket(String id, {List<Map<String, Object?>>? children}) => IpcResponse.ok(
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
    'children': ?children,
  },
);

Map<String, Object?> _child(String id, String status, {String type = 'task'}) => {
  'id': id,
  'type': type,
  'title': 'Child $id',
  'status': status,
  'priority': 'medium',
};

// pql returns children in id order; the detail view re-ranks them by status.
final _mixedChildren = [
  _child('T-10', 'backlog'),
  _child('T-11', 'done'),
  _child('T-12', 'in_progress'),
  _child('T-13', 'backlog', type: 'bug'),
  _child('T-14', 'ready'),
  _child('T-15', 'review'),
  _child('T-16', 'cancelled'),
];

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
      await pumpEventQueue();
      expect(c!.detail?.id, 'T-1');
    });

    test('a bare selection does NOT load (the nav re-emits as load)', () async {
      c = TicketDetailController(ipc: f.ipc, messages: f.services.messages);
      f.services.messages.publish('builtin.tickets', 'selection', {'id': 'T-9'});
      await pumpEventQueue();
      expect(c!.detail, isNull);
    });

    test('requests children and orders them open-first, closed last (T-595)', () async {
      Map<String, Object?>? showArgs;
      f.ipc.stub('pql.tickets.show', (args) async {
        showArgs = args;
        return _ticket('T-1', children: _mixedChildren);
      });
      c = TicketDetailController(ipc: f.ipc, messages: f.services.messages);
      await c!.load('T-1');

      expect(showArgs?['withChildren'], isTrue);
      expect(showArgs?['withContext'], isTrue);
      expect(c!.detail!.children.map((e) => e['id']), ['T-12', 'T-15', 'T-14', 'T-10', 'T-13', 'T-11', 'T-16']);
    });

    test('a ticket without children gets an empty list', () async {
      c = TicketDetailController(ipc: f.ipc, messages: f.services.messages);
      await c!.load('T-1');
      expect(c!.detail!.children, isEmpty);
    });
  });

  group('TicketDetail.orderChildren (T-595)', () {
    test('ties keep pql order; unknown statuses sit between backlog and done', () {
      final ordered = TicketDetail.orderChildren([
        {'id': 'a', 'status': 'done'},
        {'id': 'b', 'status': 'backlog'},
        {'id': 'c', 'status': 'blocked'},
        {'id': 'd', 'status': 'backlog'},
        {'id': 'e'},
      ]);
      expect(ordered.map((e) => e['id']), ['b', 'd', 'c', 'e', 'a']);
    });

    test('isClosed covers done and cancelled only', () {
      expect(TicketDetail.isClosed({'status': 'done'}), isTrue);
      expect(TicketDetail.isClosed({'status': 'cancelled'}), isTrue);
      expect(TicketDetail.isClosed({'status': 'review'}), isFalse);
      expect(TicketDetail.isClosed(const {}), isFalse);
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
      await pumpEventQueue();
      f.services.messages.publish('builtin.tickets', 'selection', {'id': 'T-2'});
      await pumpEventQueue();
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

    // -- Children (T-595) ---------------------------------------------------

    testWidgets('a leaf ticket shows no CHILDREN section', (tester) async {
      await pumpView(tester);
      await open(tester, 'T-1');
      expect(find.text('CHILDREN'), findsNothing);
    });

    testWidgets('lists open children with status; closed ones fold behind a toggle', (tester) async {
      f.ipc.stub('pql.tickets.show', (args) async => _ticket(args['id'] as String? ?? '?', children: _mixedChildren));
      await pumpView(tester);
      await open(tester, 'T-1');

      expect(find.text('CHILDREN'), findsOneWidget);
      for (final id in ['T-10', 'T-12', 'T-13', 'T-14', 'T-15']) {
        expect(find.text('Child $id'), findsOneWidget);
      }
      expect(find.text('Child T-11'), findsNothing);
      expect(find.text('Child T-16'), findsNothing);
      // Open work is ranked: in-progress above backlog.
      expect(tester.getTopLeft(find.text('Child T-12')).dy, lessThan(tester.getTopLeft(find.text('Child T-10')).dy));
      expect(find.text('WIP'), findsNWidgets(2)); // the status control + T-12's row label

      await tester.tap(find.text('2 closed'));
      await pumpAsync(tester);
      expect(find.text('Child T-11'), findsOneWidget);
      expect(find.text('Child T-16'), findsOneWidget);
      expect(find.text('CANCELLED'), findsOneWidget);
      // Closed rows sit below the open ones.
      expect(tester.getTopLeft(find.text('Child T-11')).dy, greaterThan(tester.getTopLeft(find.text('Child T-13')).dy));

      await tester.tap(find.text('Hide closed'));
      await pumpAsync(tester);
      expect(find.text('Child T-11'), findsNothing);
      expect(find.text('2 closed'), findsOneWidget);
    });

    testWidgets('clicking a child opens it; back returns to the parent', (tester) async {
      f.ipc.stub('pql.tickets.show', (args) async {
        final id = args['id'] as String? ?? '?';
        return _ticket(id, children: id == 'T-1' ? [_child('T-12', 'in_progress')] : null);
      });
      await pumpView(tester);
      await open(tester, 'T-1');

      await tester.tap(find.text('Child T-12'));
      await pumpAsync(tester);
      expect(find.text('Ticket T-12'), findsWidgets);
      expect(find.text('CHILDREN'), findsNothing);

      await tester.tap(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Back' && (w.properties.enabled ?? true)).first);
      await pumpAsync(tester);
      expect(find.text('Ticket T-1'), findsWidgets);
      expect(find.text('Child T-12'), findsOneWidget);
    });
  });
}
