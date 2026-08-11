import 'package:clide/builtin/clide_companion/src/ask_box.dart';
import 'package:clide/builtin/clide_companion/src/clide_face.dart';
import 'package:clide/builtin/clide_companion/src/clide_strip.dart';
import 'package:clide/builtin/clide_companion/src/face_state.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

/// T-564 — the box you ask Clide things in, and the face acknowledging that you
/// are talking *to* him rather than about him.
void main() {
  late KernelFixture f;

  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  Widget host({ValueChanged<String>? onAsk, bool canAsk = true, double width = 600}) => Directionality(
    textDirection: TextDirection.ltr,
    child: ClideKernel(
      services: f.services,
      child: ClideTheme(
        controller: f.services.theme,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: ClideStrip(onAsk: onAsk, canAsk: canAsk, message: 'Those accumulate.'),
            ),
          ),
        ),
      ),
    ),
  );

  group('the input', () {
    testWidgets('is absent until something can receive a question', (tester) async {
      // A box that submits into nowhere is worse than no box.
      await tester.pumpWidget(host());
      expect(find.byType(ClideAskBox), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('appears beside the face when there is somewhere to send', (tester) async {
      await tester.pumpWidget(host(onAsk: (_) {}));
      expect(find.byType(ClideAskBox), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('submitting sends the question and clears the box', (tester) async {
      // Clearing matters: the answer arrives in the bubble above, so a question
      // left sitting in the field reads as unsent.
      final asked = <String>[];
      await tester.pumpWidget(host(onAsk: asked.add));

      await tester.enterText(find.byType(EditableText), 'what did that mean?');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(asked, ['what did that mean?']);
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an empty question is not a question', (tester) async {
      final asked = <String>[];
      await tester.pumpWidget(host(onAsk: asked.add));

      await tester.enterText(find.byType(EditableText), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(asked, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('with no session it is dimmed rather than removed', (tester) async {
      // A control that vanishes reads as a bug; a dimmed one reads as "not now".
      final asked = <String>[];
      await tester.pumpWidget(host(onAsk: asked.add, canAsk: false));
      expect(find.byType(ClideAskBox), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'anyone there?');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(asked, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('being addressed', () {
    testWidgets('focusing his box turns the face forward', (tester) async {
      // The T-514 spike's ADDRESSED state: "the lean releasing IS the
      // acknowledgement — no chrome needed". It is also what tells the developer
      // which of the two composers they are typing into.
      await tester.pumpWidget(host(onAsk: (_) {}));
      expect(tester.widget<ClideFace>(find.byType(ClideFace)).gaze, isNot(Gaze.forward));

      await tester.tap(find.byType(EditableText));
      await tester.pump();

      expect(tester.widget<ClideFace>(find.byType(ClideFace)).gaze, Gaze.forward);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('a narrow panel', () {
    testWidgets('drops the input with the bubble rather than cramming it', (tester) async {
      // At the context panel's 220px minimum there is not enough width for the
      // face and a legible input together. The popout (T-566) is the escape
      // hatch; a cramped box here would be worse than none.
      await tester.pumpWidget(host(onAsk: (_) {}, width: 200));
      expect(find.byType(ClideAskBox), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
