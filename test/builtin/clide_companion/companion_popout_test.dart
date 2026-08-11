import 'dart:async';

import 'package:clide/builtin/claude/src/conversation_controller.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:clide/builtin/clide_companion/src/companion_popout.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

/// T-566 — what the developer sees of Clide.
///
/// The filter is the interesting part and it runs opposite to the digest's: that
/// one decides what Clide may see, this one decides what may be seen of him.
UserMessage _user(String text) => UserMessage(uuid: 'u${text.hashCode}', timestamp: DateTime(2026), isSidechain: false, text: text);

AssistantTextMessage _clide(String text, {bool synthetic = false}) =>
    AssistantTextMessage(uuid: 'a${text.hashCode}', timestamp: DateTime(2026), isSidechain: false, text: text, synthetic: synthetic);

void main() {
  group('what reaches the popout', () {
    test('a question and his answer, with the protocol stripped', () {
      final turns = companionExchange([_user('[direct] user: what did that mean?'), _clide('[watching]\nThe timeout was never the problem.')]);

      expect(turns.map((t) => t.text), ['what did that mean?', 'The timeout was never the problem.']);
      expect(turns.map((t) => t.mine), [true, false]);
    });

    test('the digest never appears', () {
      // Those lines are the developer's own conversation. Showing them back
      // inside Clide's window would be a strange mirror.
      final turns = companionExchange([
        _user('[observed] user: skip the changelog\n[observed] claude: Committed.'),
        _clide('[unimpressed]\nThat one will be missed later.'),
      ]);

      expect(turns, hasLength(1));
      expect(turns.single.mine, isFalse);
      expect(turns.single.text, 'That one will be missed later.');
    });

    test('notices and events are bookkeeping, not conversation', () {
      final turns = companionExchange([_user('[notice] You were not watching for about 20 minutes.'), _user('[event] the turn failed')]);
      expect(turns, isEmpty);
    });

    test('his silences are not empty rows', () {
      // Most of his replies are a face and nothing else. Rendering those would
      // fill the popout with blanks.
      final turns = companionExchange([_clide('[idle]'), _clide('[watching]\n'), _clide('[concerned]\nThose accumulate.')]);
      expect(turns.map((t) => t.text), ['Those accumulate.']);
    });

    test('the face tag never survives into the view', () {
      final turns = companionExchange([_clide('[amused]\nthat one actually landed')]);
      expect(turns.single.text, 'that one actually landed');
    });

    test('synthetic prose is the CLI, not him', () {
      expect(companionExchange([_clide('[idle]\nlocal output', synthetic: true)]), isEmpty);
    });

    test('an unknown item type is invisible until someone decides otherwise', () {
      // Same allow-list discipline as the digest: a new kind of item must not
      // appear here by default.
      final turns = companionExchange([
        ToolResultMessage(uuid: 't1', timestamp: DateTime(2026), isSidechain: false, toolUseId: 'x', content: 'secret', isError: false),
        _clide('[idle]\nsomething'),
      ]);
      expect(turns.map((t) => t.text), ['something']);
    });
  });

  group('the surface', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() => f.dispose());

    Widget host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: ClideKernel(
        services: f.services,
        child: ClideTheme(controller: f.services.theme, child: child),
      ),
    );

    testWidgets('says so plainly when he has not spoken', (tester) async {
      // An empty panel reads as broken; "nothing said yet" is true and calm.
      await tester.pumpWidget(host(CompanionPopout(conversation: null, onDismiss: () {}, onAsk: (_) {})));
      expect(find.text('Nothing said yet.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('it follows him when his session is replaced under it', (tester) async {
      // A restart swaps the ManagedSession — after a `/clear` on the primary, a
      // workspace switch, or any brief change. A popout still listening to the
      // old conversation shows the previous transcript for ever and never the
      // answer to whatever was asked next.
      final oldStream = StreamController<ConversationItem>.broadcast();
      final newStream = StreamController<ConversationItem>.broadcast();
      addTearDown(oldStream.close);
      addTearDown(newStream.close);
      final before = ConversationController(stream: oldStream.stream);
      final after = ConversationController(stream: newStream.stream);

      await tester.pumpWidget(host(CompanionPopout(conversation: before, onDismiss: () {}, onAsk: (_) {})));
      await tester.pumpWidget(host(CompanionPopout(conversation: after, onDismiss: () {}, onAsk: (_) {})));

      newStream.add(_clide('[watching]\nStill here.'));
      // The controller coalesces a burst behind a zero-duration Timer, which a
      // bare `pump()` does not advance the clock far enough to fire.
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.text('Still here.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a half-typed question survives being dismissed', (tester) async {
      // Losing what someone was in the middle of writing is the kind of small
      // betrayal that makes a surface untrustworthy.
      final draft = TextEditingController();
      addTearDown(draft.dispose);

      Widget popout() => host(CompanionPopout(conversation: null, draft: draft, onDismiss: () {}, onAsk: (_) {}));

      await tester.pumpWidget(popout());
      await tester.enterText(find.byType(EditableText), 'half a thought');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(popout());

      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'half a thought');
      await tester.pumpWidget(const SizedBox());
    });
  });
}
