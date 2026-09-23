/// Widget coverage for the queued-messages dock (T-587): hidden when empty,
/// each message tagged "queued", dismiss, and an edit that holds the queue
/// from its start until it is saved, cancelled, or its message vanishes.
library;

import 'package:clide/builtin/claude/src/queued_messages_dock.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart' show QueuedMessage;
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  final dismissed = <String>[];
  final edits = <(String, String)>[];
  var holds = 0;
  var releases = 0;
  setUp(() {
    dismissed.clear();
    edits.clear();
    holds = 0;
    releases = 0;
  });

  const two = [QueuedMessage(id: 'q1', text: 'first queued'), QueuedMessage(id: 'q2', text: 'second queued')];

  // The harness mounts its child in an OverlayEntry, which is built once — so
  // a later pumpWidget never reaches the dock. Changes go through these
  // notifiers inside the one mounted tree instead.
  late ValueNotifier<List<QueuedMessage>> queue;
  late ValueNotifier<bool> mounted;

  Future<void> pump(WidgetTester tester, List<QueuedMessage> messages) async {
    queue = ValueNotifier(messages);
    mounted = ValueNotifier(true);
    addTearDown(queue.dispose);
    addTearDown(mounted.dispose);
    await tester.pumpWidget(
      harness(
        f,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 500,
            child: ListenableBuilder(
              listenable: Listenable.merge([queue, mounted]),
              builder: (_, _) => !mounted.value
                  ? const SizedBox.shrink()
                  : QueuedMessagesDock(
                      messages: queue.value,
                      onDismiss: dismissed.add,
                      onEdit: (id, text) => edits.add((id, text)),
                      onEditStart: () => holds++,
                      onEditEnd: () => releases++,
                    ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders nothing when the queue is empty', (tester) async {
    await pump(tester, const []);
    expect(find.byType(ClideText), findsNothing);
  });

  testWidgets('each message shows tagged as queued', (tester) async {
    await pump(tester, two);
    expect(find.text('first queued'), findsOneWidget);
    expect(find.text('second queued'), findsOneWidget);
    expect(find.text('queued'), findsNWidgets(2));
  });

  testWidgets('dismiss reports the message id', (tester) async {
    await pump(tester, two);
    await tester.tap(find.byKey(const Key('queued-dismiss-q2')));
    await tester.pump();
    expect(dismissed, ['q2']);
  });

  testWidgets('starting an edit holds the queue; saving commits and releases', (tester) async {
    await pump(tester, two);
    await tester.tap(find.byKey(const Key('queued-edit-q1')));
    await tester.pump();
    expect(holds, 1, reason: 'hold as soon as editing starts');
    expect(releases, 0);
    expect(find.text('editing'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('queued-editor')), 'rewritten');
    await tester.tap(find.byKey(const Key('queued-save')));
    await tester.pump();
    expect(edits, [('q1', 'rewritten')]);
    expect(releases, 1);
    expect(find.text('editing'), findsNothing);
  });

  testWidgets('Enter saves and Escape cancels, like the composer', (tester) async {
    await pump(tester, two);
    await tester.tap(find.byKey(const Key('queued-edit-q1')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('queued-editor')), 'via enter');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(edits, [('q1', 'via enter')]);

    await tester.tap(find.byKey(const Key('queued-edit-q2')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('queued-editor')), 'thrown away');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(edits, hasLength(1), reason: 'cancel commits nothing');
    expect(holds, 2);
    expect(releases, 2);
  });

  testWidgets('switching the edit to another message keeps a single hold', (tester) async {
    await pump(tester, two);
    await tester.tap(find.byKey(const Key('queued-edit-q1')));
    await tester.pump();
    // The other row's edit button is still there; moving to it is one edit.
    await tester.tap(find.byKey(const Key('queued-edit-q2')));
    await tester.pump();
    expect(holds, 1);
    expect(releases, 0);
    await tester.tap(find.byKey(const Key('queued-cancel')));
    await tester.pump();
    expect(releases, 1);
  });

  testWidgets('the edited message vanishing releases the hold', (tester) async {
    await pump(tester, two);
    await tester.tap(find.byKey(const Key('queued-edit-q1')));
    await tester.pump();
    queue.value = const [QueuedMessage(id: 'q2', text: 'second queued')];
    await tester.pump();
    expect(releases, 1);
    expect(find.text('editing'), findsNothing);
  });

  testWidgets('unmounting mid-edit releases the hold', (tester) async {
    await pump(tester, two);
    await tester.tap(find.byKey(const Key('queued-edit-q1')));
    await tester.pump();
    mounted.value = false;
    await tester.pump();
    expect(releases, 1);
  });
}
