/// Tests for the tickets sidebar list (TicketsView): load, sectioned
/// rendering, filtering, card selection, and the empty/error states.
library;

import 'package:clide/builtin/tickets/src/tickets_view.dart';
import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

Map<String, Object?> _t(String id, String title, String status, {String? type, String? parentId}) => {
      'id': id,
      'title': title,
      'status': status,
      'type': type ?? 'task',
      'priority': 'medium',
      if (parentId != null) 'parent_id': parentId,
    };

IpcResponse _list(List<Map<String, Object?>> tickets) => IpcResponse.ok(id: '', data: {'tickets': tickets});

void main() {
  late KernelFixture f;

  setUp(() async {
    f = await KernelFixture.create();
  });
  tearDown(() => f.dispose());

  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(harness(f, const TicketsView()));
    await pumpAsync(tester);
  }

  testWidgets('shows a loading placeholder until the list resolves', (tester) async {
    f.ipc.stub('pql.tickets.list', (_) async => _list([_t('T-1', 'First', 'backlog')]));
    await tester.pumpWidget(harness(f, const TicketsView()));
    expect(find.text('Loading tickets...'), findsOneWidget);
    await pumpAsync(tester);
    expect(find.text('Loading tickets...'), findsNothing);
  });

  testWidgets('renders sectioned cards from the loaded list', (tester) async {
    f.ipc.stub(
        'pql.tickets.list',
        (_) async => _list([
              _t('T-1', 'Active thing', 'in_progress', parentId: 'T-9'),
              _t('T-2', 'Queued thing', 'backlog'),
            ]));
    await pumpView(tester);

    expect(find.textContaining('IN PROGRESS'), findsOneWidget);
    expect(find.textContaining('BACKLOG'), findsOneWidget);
    expect(find.text('T-1'), findsOneWidget);
    expect(find.text('Active thing'), findsOneWidget);
    expect(find.text('Queued thing'), findsOneWidget);
    // parent breadcrumb on T-1
    expect(find.text('T-9'), findsOneWidget);
  });

  testWidgets('filter narrows the visible cards', (tester) async {
    f.ipc.stub(
        'pql.tickets.list',
        (_) async => _list([
              _t('T-1', 'Alpha', 'backlog'),
              _t('T-2', 'Beta', 'backlog'),
            ]));
    await pumpView(tester);
    expect(find.text('Alpha'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, 'beta');
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
  });

  testWidgets('tapping a card publishes a selection', (tester) async {
    f.ipc.stub('pql.tickets.list', (_) async => _list([_t('T-1', 'Tap me', 'backlog')]));
    final selections = <Message>[];
    final sub = f.services.messages.subscribe(publisher: 'builtin.tickets', channel: 'selection').listen(selections.add);
    addTearDown(sub.cancel);
    await pumpView(tester);

    await tester.tap(find.text('Tap me'));
    await pumpAsync(tester);
    expect(selections.single.data['id'], 'T-1');
  });

  testWidgets('empty list shows the placeholder', (tester) async {
    f.ipc.stub('pql.tickets.list', (_) async => _list(const []));
    await pumpView(tester);
    expect(find.textContaining('No tickets'), findsOneWidget);
  });

  testWidgets('a load error is surfaced', (tester) async {
    f.ipc.stub(
        'pql.tickets.list',
        (_) async => IpcResponse.err(
              id: '',
              error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'boom'),
            ));
    await pumpView(tester);
    expect(find.text('boom'), findsOneWidget);
  });

  testWidgets('a changed event triggers a refresh', (tester) async {
    var calls = 0;
    f.ipc.stub('pql.tickets.list', (_) async {
      calls++;
      return _list([_t('T-1', 'Thing', 'backlog')]);
    });
    await pumpView(tester);
    final before = calls;
    f.services.messages.publish('builtin.tickets', 'changed', {'id': 'T-1'});
    await pumpAsync(tester);
    expect(calls, greaterThan(before));
  });
}
