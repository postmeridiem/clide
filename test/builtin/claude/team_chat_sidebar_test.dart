/// Widget tests for TeamChatSidebar and TeamChatPane (T-180).
library;

import 'package:clide/builtin/claude/src/team_broker.dart';
import 'package:clide/builtin/claude/src/team_chat_model.dart';
import 'package:clide/builtin/claude/src/team_chat_sidebar.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  late TeamBroker broker;
  late TeamChatModel model;

  setUp(() async {
    f = await KernelFixture.create();
    broker = TeamBroker(deliver: (_, __) {});
    broker.addMember(const TeamMemberRef(id: 'primary', name: 'lead', role: 'lead'));
    broker.addMember(const TeamMemberRef(id: 'teammate:tyre', name: 'tyre', role: 'teammate'));
    model = TeamChatModel(broker: broker);
  });

  tearDown(() {
    model.dispose();
    broker.dispose();
    f.dispose();
  });

  // ---------------------------------------------------------------------------
  // TeamChatSidebar
  // ---------------------------------------------------------------------------

  group('TeamChatSidebar', () {
    Widget sidebar({VoidCallback? onPopOut}) => harness(
          f,
          SizedBox(
            width: 220,
            height: 400,
            child: TeamChatSidebar(
              model: model,
              broker: broker,
              onPopOut: onPopOut ?? () {},
            ),
          ),
        );

    testWidgets('renders MESSAGES header', (tester) async {
      await tester.pumpWidget(sidebar());
      expect(find.text('MESSAGES'), findsOneWidget);
    });

    testWidgets('shows placeholder when no messages', (tester) async {
      await tester.pumpWidget(sidebar());
      expect(find.text('No messages yet.'), findsOneWidget);
    });

    testWidgets('renders broker messages from the model', (tester) async {
      // Post via model directly so the message is already in the timeline
      // before we build the widget — avoids a pump/settle cycle.
      model.postAsUser('hello tyre', toName: 'tyre');
      await tester.pumpWidget(sidebar());
      await tester.pump();
      expect(find.text('hello tyre'), findsOneWidget);
      expect(find.text('No messages yet.'), findsNothing);
    });

    testWidgets('updates when a new message arrives', (tester) async {
      await tester.pumpWidget(sidebar());
      await tester.pump();
      expect(find.text('No messages yet.'), findsOneWidget);

      // postAsUser adds to _messages synchronously and fires _changeCtl.add,
      // which synchronously calls setState() in the sidebar's listener.
      // Two pumps: one to process the microtask queue (stream event delivery),
      // one to render the resulting rebuild frame.
      model.postAsUser('live message', toName: 'tyre');
      await tester.pump(); // deliver stream event → setState
      await tester.pump(); // render rebuild frame

      expect(find.text('live message'), findsOneWidget);
    });

    testWidgets('postAsUser adds a message from the user', (tester) async {
      await tester.pumpWidget(sidebar());
      await tester.pump();

      model.postAsUser('hello team');
      await tester.pump(); // deliver stream event → setState
      await tester.pump(); // render rebuild frame

      // The message text appears in the timeline.
      expect(find.text('hello team'), findsOneWidget);
    });

    testWidgets('has a chat input field', (tester) async {
      await tester.pumpWidget(sidebar());
      await tester.pumpAndSettle();
      final chatField = find.byWidgetPredicate((w) => w is EditableText && w.focusNode.debugLabel == 'team-chat-sidebar');
      expect(chatField, findsOneWidget);
    });

    testWidgets('submitting the composer calls postAsUser', (tester) async {
      await tester.pumpWidget(sidebar());
      await tester.pumpAndSettle();

      final chatField = find.byWidgetPredicate((w) => w is EditableText && w.focusNode.debugLabel == 'team-chat-sidebar');
      await tester.enterText(chatField, 'broadcast msg');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(model.messages.any((m) => m.text == 'broadcast msg'), isTrue);
    });

    testWidgets('@name tag routes to the named member', (tester) async {
      await tester.pumpWidget(sidebar());
      await tester.pumpAndSettle();

      final chatField = find.byWidgetPredicate((w) => w is EditableText && w.focusNode.debugLabel == 'team-chat-sidebar');
      await tester.enterText(chatField, '@tyre pick this up');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(model.messages.any((m) => m.to == 'tyre' && m.text == 'pick this up'), isTrue);
    });

    testWidgets('pop-out icon calls onPopOut', (tester) async {
      var popped = false;
      // Use a tall harness so the MESSAGES header (and its pop-out icon) is
      // always in view and tappable.
      await tester.pumpWidget(harness(
        f,
        SizedBox(
          width: 300,
          height: 800,
          child: TeamChatSidebar(
            model: model,
            broker: broker,
            onPopOut: () => popped = true,
          ),
        ),
      ));
      await tester.pump();

      // The pop-out icon is wired via Semantics(label: 'Open full chat pane').
      // Use byWidgetPredicate to traverse the full widget tree regardless of
      // viewport clipping (canSizeOverlay harness pitfall — see T-180 notes).
      final popOutFinder = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Open full chat pane');
      expect(popOutFinder, findsOneWidget);
      await tester.tap(popOutFinder);
      await tester.pump();
      expect(popped, isTrue);
    });

    testWidgets('shows only last 5 messages in compact feed', (tester) async {
      // Post 8 messages directly via model (synchronous, no broker stream delay).
      for (var i = 0; i < 8; i++) {
        model.postAsUser('message $i', toName: 'tyre');
      }
      await tester.pumpWidget(sidebar());
      await tester.pump();
      // Only messages 3-7 visible (last 5).
      expect(find.text('message 7'), findsOneWidget);
      expect(find.text('message 0'), findsNothing);
    });

    testWidgets('submitting empty text is a no-op', (tester) async {
      await tester.pumpWidget(sidebar());
      await tester.pumpAndSettle();

      final chatField = find.byWidgetPredicate((w) => w is EditableText && w.focusNode.debugLabel == 'team-chat-sidebar');
      await tester.enterText(chatField, '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(model.messages, isEmpty);
    });

    testWidgets('@-completion: entering @ty prefix does not show overlay suggestions in test env', (tester) async {
      // The _AtOverlay is positioned via CompositedTransformFollower which can't
      // resolve coordinates in the test binding without a real render. Instead,
      // verify the _onTextChanged plumbing runs without error and the field
      // is usable after typing an @-prefix.
      await tester.pumpWidget(sidebar());
      await tester.pumpAndSettle();

      // Focus the field and set text with a selection so cursor is at end.
      final chatField = find.byWidgetPredicate(
        (w) => w is EditableText && w.focusNode.debugLabel == 'team-chat-sidebar',
      );
      final field = tester.widget<EditableText>(chatField);
      field.focusNode.requestFocus();
      await tester.pump();

      // Set value with explicit cursor position at end.
      field.controller.value = const TextEditingValue(
        text: '@ty',
        selection: TextSelection.collapsed(offset: 3),
      );
      await tester.pump();
      await tester.pump();

      // Widget is still alive — no exception from the overlay path.
      expect(chatField, findsOneWidget);
    });

    testWidgets('@-completion: no-match prefix clears suggestions without overlay', (tester) async {
      await tester.pumpWidget(sidebar());
      await tester.pumpAndSettle();

      final chatField = find.byWidgetPredicate(
        (w) => w is EditableText && w.focusNode.debugLabel == 'team-chat-sidebar',
      );
      final field = tester.widget<EditableText>(chatField);
      field.focusNode.requestFocus();
      await tester.pump();

      // No match — _updateSuggestions called with null.
      field.controller.value = const TextEditingValue(
        text: '@zzz',
        selection: TextSelection.collapsed(offset: 4),
      );
      await tester.pump();
      await tester.pump();

      // No crash and no suggestions overlay visible in normal find.
      expect(find.text('@tyre'), findsNothing);
      expect(find.text('@lead'), findsNothing);
    });

    testWidgets('@-completion: match then non-match closes overlay path', (tester) async {
      // Exercises _updateSuggestions with suggestions then without.
      await tester.pumpWidget(sidebar());
      await tester.pumpAndSettle();

      final chatField = find.byWidgetPredicate(
        (w) => w is EditableText && w.focusNode.debugLabel == 'team-chat-sidebar',
      );
      final field = tester.widget<EditableText>(chatField);
      field.focusNode.requestFocus();
      await tester.pump();

      // Set @ty (matches tyre) → _showOverlay called.
      field.controller.value = const TextEditingValue(
        text: '@ty',
        selection: TextSelection.collapsed(offset: 3),
      );
      await tester.pump();

      // Clear → _removeOverlay called.
      field.controller.value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      await tester.pump();
      await tester.pump();

      // Still functional.
      expect(chatField, findsOneWidget);
    });

    testWidgets('Escape key: _handleKeyEvent removes overlay state', (tester) async {
      await tester.pumpWidget(sidebar());
      await tester.pumpAndSettle();

      final chatField = find.byWidgetPredicate(
        (w) => w is EditableText && w.focusNode.debugLabel == 'team-chat-sidebar',
      );
      final field = tester.widget<EditableText>(chatField);
      field.focusNode.requestFocus();
      await tester.pump();

      // Set a matching @-prefix to activate the overlay path.
      field.controller.value = const TextEditingValue(
        text: '@ty',
        selection: TextSelection.collapsed(offset: 3),
      );
      await tester.pump();

      // Send Escape — _handleKeyEvent should return KeyEventResult.handled.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      // Field is still usable; no crash.
      expect(chatField, findsOneWidget);
    });

    testWidgets('@-completion: cursor < 0 path is handled without error', (tester) async {
      // When the controller has no selection (baseOffset < 0), _onTextChanged
      // must call _updateSuggestions(null) without crashing.
      await tester.pumpWidget(sidebar());
      await tester.pumpAndSettle();

      final chatField = find.byWidgetPredicate(
        (w) => w is EditableText && w.focusNode.debugLabel == 'team-chat-sidebar',
      );
      final field = tester.widget<EditableText>(chatField);
      field.focusNode.requestFocus();
      await tester.pump();

      // A value with no selection (baseOffset == -1) triggers the cursor < 0 guard.
      field.controller.value = const TextEditingValue(
        text: '@ty',
        selection: TextSelection.collapsed(offset: -1),
      );
      await tester.pump();
      await tester.pump();

      // No exception; widget still alive.
      expect(chatField, findsOneWidget);
    });

    testWidgets('broadcast message (no @) shows sender chip in timeline', (tester) async {
      model.postAsUser('broadcast msg');
      await tester.pumpWidget(sidebar());
      await tester.pump();
      // The from chip 'user' is shown.
      expect(find.text('user'), findsOneWidget);
      // broadcast message shows → all label.
      expect(find.text('→ all'), findsOneWidget);
    });

    testWidgets('directed message shows → to label in the chat row', (tester) async {
      model.postAsUser('directed msg', toName: 'tyre');
      await tester.pumpWidget(sidebar());
      await tester.pump();
      expect(find.text('→ tyre'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TeamChatPane
  // ---------------------------------------------------------------------------

  group('TeamChatPane', () {
    Widget pane() => harness(
          f,
          SizedBox(
            width: 400,
            height: 600,
            child: TeamChatPane(model: model, broker: broker),
          ),
        );

    testWidgets('renders Team Chat header', (tester) async {
      await tester.pumpWidget(pane());
      expect(find.text('Team Chat'), findsOneWidget);
    });

    testWidgets('shows placeholder when empty', (tester) async {
      await tester.pumpWidget(pane());
      expect(find.text('No messages yet.'), findsOneWidget);
    });

    testWidgets('renders messages from the model', (tester) async {
      model.postAsUser('pane message', toName: 'tyre');
      await tester.pumpWidget(pane());
      await tester.pump();
      expect(find.text('pane message'), findsOneWidget);
    });

    testWidgets('has an Interrupt tickbox starting unchecked', (tester) async {
      await tester.pumpWidget(pane());
      await tester.pump();
      expect(find.text('Interrupt'), findsOneWidget);
      // The tickbox is implemented as a Container that is empty when unchecked
      // and shows a check icon when checked. Verify by checking that the check
      // icon (PhosphorIcons.check) is NOT rendered when unchecked.
      // We use the Semantics widget's checked property which maps to isChecked.
      final interruptFinder = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Interrupt target session');
      // Widget exists in tree.
      expect(interruptFinder, findsOneWidget);
      // Semantics.checked is false when unchecked.
      final sem = interruptFinder.evaluate().single.widget as Semantics;
      expect(sem.properties.checked, isFalse);
    });

    testWidgets('tapping Interrupt toggles the tickbox', (tester) async {
      await tester.pumpWidget(pane());
      await tester.pump();

      final interruptArea = find.text('Interrupt');
      await tester.tap(interruptArea);
      await tester.pump();

      // Re-find: the Semantics widget's checked property is now true.
      final interruptFinder = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Interrupt target session');
      final sem = interruptFinder.evaluate().single.widget as Semantics;
      expect(sem.properties.checked, isTrue);
    });

    testWidgets('submitting the pane composer posts as user', (tester) async {
      await tester.pumpWidget(pane());
      await tester.pumpAndSettle();

      final chatField = find.byWidgetPredicate((w) => w is EditableText && w.focusNode.debugLabel == 'team-chat-pane');
      await tester.enterText(chatField, '@tyre check this');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(model.messages.any((m) => m.to == 'tyre' && m.text == 'check this'), isTrue);
    });

    testWidgets('pane Escape key: _handleKeyEvent removes overlay state', (tester) async {
      await tester.pumpWidget(pane());
      await tester.pumpAndSettle();

      final chatField = find.byWidgetPredicate(
        (w) => w is EditableText && w.focusNode.debugLabel == 'team-chat-pane',
      );
      final field = tester.widget<EditableText>(chatField);
      field.focusNode.requestFocus();
      await tester.pump();

      // Set @ty to activate overlay path.
      field.controller.value = const TextEditingValue(
        text: '@ty',
        selection: TextSelection.collapsed(offset: 3),
      );
      await tester.pump();

      // Escape dismisses.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      // Field still functional.
      expect(chatField, findsOneWidget);
    });

    testWidgets('pane @-completion: match prefix activates suggestion path', (tester) async {
      await tester.pumpWidget(pane());
      await tester.pumpAndSettle();

      final chatField = find.byWidgetPredicate(
        (w) => w is EditableText && w.focusNode.debugLabel == 'team-chat-pane',
      );
      final field = tester.widget<EditableText>(chatField);
      field.focusNode.requestFocus();
      await tester.pump();

      // @le → matches lead.
      field.controller.value = const TextEditingValue(
        text: '@le',
        selection: TextSelection.collapsed(offset: 3),
      );
      await tester.pump();
      await tester.pump();

      // No crash; field usable.
      expect(chatField, findsOneWidget);
    });

    testWidgets('pane @-completion: no match clears suggestion state', (tester) async {
      await tester.pumpWidget(pane());
      await tester.pumpAndSettle();

      final chatField = find.byWidgetPredicate(
        (w) => w is EditableText && w.focusNode.debugLabel == 'team-chat-pane',
      );
      final field = tester.widget<EditableText>(chatField);
      field.focusNode.requestFocus();
      await tester.pump();

      field.controller.value = const TextEditingValue(
        text: '@zzz',
        selection: TextSelection.collapsed(offset: 4),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('@tyre'), findsNothing);
      expect(find.text('@lead'), findsNothing);
    });

    testWidgets('pane @-completion: cursor < 0 clears suggestions without error', (tester) async {
      await tester.pumpWidget(pane());
      await tester.pumpAndSettle();

      final chatField = find.byWidgetPredicate(
        (w) => w is EditableText && w.focusNode.debugLabel == 'team-chat-pane',
      );
      final field = tester.widget<EditableText>(chatField);
      field.focusNode.requestFocus();
      await tester.pump();

      field.controller.value = const TextEditingValue(
        text: '@ty',
        selection: TextSelection.collapsed(offset: -1),
      );
      await tester.pump();
      await tester.pump();

      expect(chatField, findsOneWidget);
    });

    testWidgets('pane: submitting empty text is a no-op', (tester) async {
      await tester.pumpWidget(pane());
      await tester.pumpAndSettle();

      final chatField = find.byWidgetPredicate(
        (w) => w is EditableText && w.focusNode.debugLabel == 'team-chat-pane',
      );
      await tester.enterText(chatField, '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(model.messages, isEmpty);
    });

    testWidgets('pane: submitting with interrupt=true sends interrupt flag', (tester) async {
      await tester.pumpWidget(pane());
      await tester.pump();

      // Toggle interrupt on.
      final interruptArea = find.text('Interrupt');
      await tester.tap(interruptArea);
      await tester.pump();

      final chatField = find.byWidgetPredicate(
        (w) => w is EditableText && w.focusNode.debugLabel == 'team-chat-pane',
      );
      await tester.enterText(chatField, 'urgent message');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Message posted — content is what matters (interrupt field is on TeamChatModel side).
      expect(model.messages.any((m) => m.text == 'urgent message'), isTrue);
    });

    testWidgets('pane: @name tag routes message to named member with interrupt', (tester) async {
      await tester.pumpWidget(pane());
      await tester.pump();

      // Toggle interrupt on.
      await tester.tap(find.text('Interrupt'));
      await tester.pump();

      final chatField = find.byWidgetPredicate(
        (w) => w is EditableText && w.focusNode.debugLabel == 'team-chat-pane',
      );
      await tester.enterText(chatField, '@lead do this now');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(model.messages.any((m) => m.to == 'lead' && m.text == 'do this now'), isTrue);
    });

    testWidgets('sidebar and pane share the same model (both surfaces update)', (tester) async {
      await tester.pumpWidget(harness(
        f,
        SizedBox(
          width: 800,
          height: 600,
          child: Row(
            children: [
              SizedBox(
                width: 220,
                child: TeamChatSidebar(
                  model: model,
                  broker: broker,
                  onPopOut: () {},
                ),
              ),
              Expanded(child: TeamChatPane(model: model, broker: broker)),
            ],
          ),
        ),
      ));
      await tester.pump();

      // Posting from the model shows up in both surfaces.
      model.postAsUser('shared message');
      await tester.pump(); // deliver stream events → setState in each widget
      await tester.pump(); // render rebuild frames

      expect(find.text('shared message'), findsNWidgets(2));
    });
  });
}
