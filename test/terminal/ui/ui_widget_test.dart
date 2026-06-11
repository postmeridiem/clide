/// Widget tests for `lib/src/terminal/src/ui/` widget-level helpers —
/// just CustomKeyboardListener now; the other widgets in this folder
/// either don't need a widget tree or were retired as dead surface.
library;

import 'package:clide/src/terminal/src/ui/keyboard_listener.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double width = 400, double height = 200}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: Center(
        child: SizedBox(width: width, height: height, child: child),
      ),
    ),
  );
}

void main() {
  group('CustomKeyboardListener', () {
    testWidgets('falls through to onInsert when onKeyEvent returns ignored and a character is present', (tester) async {
      final inserts = <String>[];
      final composings = <String?>[];
      final focus = FocusNode();
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        _host(
          CustomKeyboardListener(
            focusNode: focus,
            autofocus: true,
            onInsert: inserts.add,
            onComposing: composings.add,
            onKeyEvent: (_, _) => KeyEventResult.ignored,
            child: const ColoredBox(color: Color(0xFF000000), child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pump();
      // A character key with non-empty `character` triggers the insert path.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
      await tester.pump();
      expect(inserts, contains('a'));
    });

    testWidgets('does not call onInsert when onKeyEvent returns handled', (tester) async {
      final inserts = <String>[];
      final focus = FocusNode();
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        _host(
          CustomKeyboardListener(
            focusNode: focus,
            autofocus: true,
            onInsert: inserts.add,
            onComposing: (_) {},
            onKeyEvent: (_, _) => KeyEventResult.handled,
            child: const ColoredBox(color: Color(0xFF000000), child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
      await tester.pump();
      expect(inserts, isEmpty);
    });

    testWidgets('does not call onInsert when the key event has no character', (tester) async {
      final inserts = <String>[];
      final focus = FocusNode();
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        _host(
          CustomKeyboardListener(
            focusNode: focus,
            autofocus: true,
            onInsert: inserts.add,
            onComposing: (_) {},
            onKeyEvent: (_, _) => KeyEventResult.ignored,
            child: const ColoredBox(color: Color(0xFF000000), child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pump();
      // ArrowUp has no `character` — ignored result + no character means
      // _onKeyEvent returns ignored without firing onInsert.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(inserts, isEmpty);
    });
  });
}
