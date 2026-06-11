/// Widget tests for `TerminalView` — the StatefulWidget that wires
/// gesture / keyboard / scroll / render plumbing around a `Terminal`.
library;

import 'package:clide/src/terminal/src/core/mouse/mode.dart';
import 'package:clide/src/terminal/src/terminal.dart';
import 'package:clide/src/terminal/src/terminal_view.dart';
import 'package:clide/src/terminal/src/ui/controller.dart';
import 'package:clide/src/terminal/src/ui/render.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal widget tree to host a TerminalView. The widget brings its own
/// theme + text style, so we only need Directionality + a sized parent.
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

class _OutputRecorder {
  final outputs = <String>[];
  Terminal build() => Terminal(maxLines: 100, onOutput: outputs.add);
}

void main() {
  group('TerminalView — construction', () {
    testWidgets('builds without throwing and creates a RenderTerminal', (tester) async {
      final t = _OutputRecorder().build();
      await tester.pumpWidget(_host(TerminalView(t)));
      expect(find.byType(TerminalView), findsOneWidget);
      // The leaf render object is wrapped in Container/MouseRegion/etc, so
      // querying by type tells us it was built.
      final state = tester.state<TerminalViewState>(find.byType(TerminalView));
      expect(state, isNotNull);
      expect(state.renderTerminal, isA<RenderTerminal>());
    });

    testWidgets('uses the supplied controller / focusNode without disposing them', (tester) async {
      final t = _OutputRecorder().build();
      final controller = TerminalController();
      final focus = FocusNode();
      addTearDown(() {
        controller.dispose();
        focus.dispose();
      });

      await tester.pumpWidget(_host(TerminalView(t, controller: controller, focusNode: focus)));
      // Tear down via removing the widget; supplied controllers should NOT
      // throw on later use (the state didn't dispose them).
      await tester.pumpWidget(_host(const SizedBox()));
      expect(controller.selection, isNull); // still functional
    });

    testWidgets('hardwareKeyboardOnly path skips CustomTextEdit', (tester) async {
      final t = _OutputRecorder().build();
      await tester.pumpWidget(_host(TerminalView(t, hardwareKeyboardOnly: true)));
      // The state still builds; this just exercises the alternative branch.
      expect(find.byType(TerminalView), findsOneWidget);
    });

    testWidgets('readOnly + hardwareKeyboardOnly skips both keyboard widgets', (tester) async {
      final t = _OutputRecorder().build();
      await tester.pumpWidget(_host(TerminalView(t, readOnly: true, hardwareKeyboardOnly: true)));
      expect(find.byType(TerminalView), findsOneWidget);
    });
  });

  group('TerminalView — pointer + scroll', () {
    testWidgets('PointerScrollEvent translates to PgUp/PgDown keyInput', (tester) async {
      final r = _OutputRecorder();
      final t = r.build();
      await tester.pumpWidget(_host(TerminalView(t)));
      // Find the outer Listener that owns _onPointerSignal.
      final viewCenter = tester.getCenter(find.byType(TerminalView));
      final testGesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await testGesture.addPointer(location: viewCenter);
      // A scroll event with a positive dy → page-down keys; a negative
      // dy → page-up. Use a magnitude that comfortably rounds to 1+ lines.
      await tester.sendEventToBinding(PointerScrollEvent(position: viewCenter, scrollDelta: const Offset(0, 100)));
      await tester.pump();
      // Output should contain at least one PgDown escape.
      expect(r.outputs, isNotEmpty);
    });

    testWidgets('PointerScrollEvent forwards as xterm wheel escapes when mouseMode.reportScroll (T-74)', (tester) async {
      final r = _OutputRecorder();
      final t = r.build();
      // Have the inner program declare ?1000h (upDownScroll) so
      // mouseMode.reportScroll becomes true.
      t.setMouseMode(MouseMode.upDownScroll);
      await tester.pumpWidget(_host(TerminalView(t)));
      final viewCenter = tester.getCenter(find.byType(TerminalView));
      final testGesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await testGesture.addPointer(location: viewCenter);
      await tester.sendEventToBinding(PointerScrollEvent(position: viewCenter, scrollDelta: const Offset(0, 100)));
      await tester.pump();
      expect(r.outputs, isNotEmpty);
      // Wheel-down id is 64+5=69; normal-mode reporter encodes button
      // bytes as 32+id, but the reporter chunks across modes — the
      // load-bearing assertion is "no PgDn key escape was emitted".
      // PgDn under default keyboard sends ESC[6~. Scrolls in mouse
      // mode must NOT contain that — they contain CSI M / SGR mouse
      // sequences instead.
      final combined = r.outputs.join();
      expect(combined.contains('\x1b[6~'), isFalse, reason: 'expected wheel forwarded as mouse, not PgDn');
    });

    testWidgets('non-scroll PointerSignalEvent is a no-op', (tester) async {
      final r = _OutputRecorder();
      final t = r.build();
      await tester.pumpWidget(_host(TerminalView(t)));
      final viewCenter = tester.getCenter(find.byType(TerminalView));
      // PointerScaleEvent is a sibling of PointerScrollEvent; the handler
      // ignores anything other than PointerScrollEvent.
      await tester.sendEventToBinding(PointerScaleEvent(position: viewCenter, scale: 1.2));
      await tester.pump();
      expect(r.outputs, isEmpty);
    });
  });

  group('TerminalView — selection state', () {
    testWidgets('a controller with an active selection survives the widget unmounting', (tester) async {
      final t = _OutputRecorder().build();
      final controller = TerminalController();
      addTearDown(controller.dispose);

      // Set a non-empty selection — exercises the selection getter path.
      final anchorA = t.buffer.createAnchor(0, 0);
      final anchorB = t.buffer.createAnchor(2, 0);
      controller.setSelection(anchorA, anchorB);
      expect(controller.selection, isNotNull);

      await tester.pumpWidget(_host(TerminalView(t, controller: controller)));
      // Tear down the widget; the externally-owned controller stays alive.
      await tester.pumpWidget(_host(const SizedBox()));
      // Selection still readable on the controller.
      expect(controller.selection, isNotNull);
    });
  });

  group('TerminalView — didUpdateWidget', () {
    testWidgets('swapping focusNode disposes the old auto-created one', (tester) async {
      final t = _OutputRecorder().build();
      await tester.pumpWidget(_host(TerminalView(t)));
      final state = tester.state<TerminalViewState>(find.byType(TerminalView));
      // Now swap to an explicit FocusNode — the auto-created one should
      // get disposed, the new one becomes active.
      final external = FocusNode();
      addTearDown(external.dispose);
      await tester.pumpWidget(_host(TerminalView(t, focusNode: external)));
      // No assertion error means dispose flowed cleanly.
      expect(state.mounted, isTrue);
    });

    testWidgets('swapping controller disposes the old auto-created one', (tester) async {
      final t = _OutputRecorder().build();
      await tester.pumpWidget(_host(TerminalView(t)));
      final external = TerminalController();
      addTearDown(external.dispose);
      await tester.pumpWidget(_host(TerminalView(t, controller: external)));
      expect(find.byType(TerminalView), findsOneWidget);
    });
  });

  group('TerminalView — keyboard handle path', () {
    testWidgets('hardware key event with a non-modifier key reaches Terminal.keyInput', (tester) async {
      final r = _OutputRecorder();
      final t = r.build();
      await tester.pumpWidget(
        _host(
          TerminalView(
            t,
            autofocus: true,
            // hardwareKeyboardOnly: true,
          ),
        ),
      );
      // Wait one frame for autofocus to settle.
      await tester.pump();
      // Send a Down arrow keypress through the binding.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      // Default keytab maps Arrow Down to a non-empty escape.
      expect(r.outputs, isNotEmpty);
    });
  });

  group('TerminalView — cursor rects', () {
    testWidgets('cursorRect / globalCursorRect return non-zero rects after layout', (tester) async {
      final t = _OutputRecorder().build();
      await tester.pumpWidget(_host(TerminalView(t)));
      final state = tester.state<TerminalViewState>(find.byType(TerminalView));
      // After first layout, the render terminal has a non-zero cell size.
      final rect = state.cursorRect;
      expect(rect.width, greaterThan(0));
      expect(rect.height, greaterThan(0));
      final globalRect = state.globalCursorRect;
      expect(globalRect.width, rect.width);
    });
  });

  group('TerminalView — keyboard helpers', () {
    testWidgets('requestKeyboard / closeKeyboard are safe no-ops when no edit state is mounted', (tester) async {
      final t = _OutputRecorder().build();
      // hardwareKeyboardOnly skips CustomTextEdit, so the helpers operate
      // on a null currentState — must not throw.
      await tester.pumpWidget(_host(TerminalView(t, hardwareKeyboardOnly: true)));
      final state = tester.state<TerminalViewState>(find.byType(TerminalView));
      state.requestKeyboard();
      state.closeKeyboard();
    });

    testWidgets('hasInputConnection is false before any input connection is opened', (tester) async {
      final t = _OutputRecorder().build();
      await tester.pumpWidget(_host(TerminalView(t)));
      final state = tester.state<TerminalViewState>(find.byType(TerminalView));
      expect(state.hasInputConnection, isFalse);
    });
  });

  group('TerminalView — onKeyEvent override', () {
    testWidgets('explicit onKeyEvent returning handled short-circuits the default handler', (tester) async {
      final r = _OutputRecorder();
      final t = r.build();
      var overrideCalls = 0;
      await tester.pumpWidget(
        _host(
          TerminalView(
            t,
            autofocus: true,
            onKeyEvent: (focusNode, event) {
              overrideCalls++;
              return KeyEventResult.handled;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(overrideCalls, isPositive);
      expect(r.outputs, isEmpty, reason: 'override returned handled — Terminal.keyInput must not run');
    });

    testWidgets('onKeyEvent returning ignored falls through to the default handler', (tester) async {
      final r = _OutputRecorder();
      final t = r.build();
      await tester.pumpWidget(_host(TerminalView(t, autofocus: true, onKeyEvent: (_, _) => KeyEventResult.ignored)));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(r.outputs, isNotEmpty);
    });
  });

  group('TerminalView — IME / text input', () {
    testWidgets('virtual-keyboard text emits via terminal.textInput when no key match', (tester) async {
      final r = _OutputRecorder();
      final t = r.build();
      await tester.pumpWidget(_host(TerminalView(t, autofocus: true)));
      await tester.pump();
      // Open an input connection by tapping; pump past the gesture
      // detector's 300 ms double-tap timer.
      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(seconds: 1));
      // testTextInput.enterText feeds the editing-value to the connection,
      // which CustomTextEdit translates into onInsert. A multi-char string
      // can't map to a TerminalKey, so it falls through to textInput.
      tester.testTextInput.enterText('hello');
      await tester.pump();
      expect(r.outputs.any((o) => o.contains('hello')), isTrue);
    });

    testWidgets('TextInputAction.done routes to TerminalKey.enter', (tester) async {
      final r = _OutputRecorder();
      final t = r.build();
      await tester.pumpWidget(_host(TerminalView(t, autofocus: true)));
      await tester.pump();
      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(seconds: 1));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      // Enter on the default keytab produces a non-empty escape.
      expect(r.outputs, isNotEmpty);
    });
  });

  group('TerminalView — taps (T-93)', () {
    testWidgets('primary tap fires onTapUp with the resolved cell offset', (tester) async {
      final r = _OutputRecorder();
      final t = r.build();
      var tappedAt = 0;
      await tester.pumpWidget(_host(TerminalView(t, onTapUp: (_, _) => tappedAt++)));
      await tester.tapAt(tester.getCenter(find.byType(TerminalView)));
      // The gesture detector arms a 300 ms double-tap timer after the tap;
      // explicit duration flushes it (pumpAndSettle waits on animations,
      // not arbitrary timers).
      await tester.pump(const Duration(seconds: 1));
      expect(tappedAt, isPositive);
    });

    testWidgets('primary tap with active selection clears it', (tester) async {
      final t = _OutputRecorder().build();
      final controller = TerminalController();
      addTearDown(controller.dispose);
      controller.setSelection(t.buffer.createAnchor(0, 0), t.buffer.createAnchor(2, 0));
      expect(controller.selection, isNotNull);
      await tester.pumpWidget(_host(TerminalView(t, controller: controller)));
      await tester.tapAt(tester.getCenter(find.byType(TerminalView)));
      await tester.pump(const Duration(seconds: 1));
      expect(controller.selection, isNull);
    });

    testWidgets('secondary tap routes through onSecondaryTapDown / onSecondaryTapUp', (tester) async {
      final r = _OutputRecorder();
      final t = r.build();
      var downCalls = 0;
      var upCalls = 0;
      await tester.pumpWidget(_host(TerminalView(t, onSecondaryTapDown: (_, _) => downCalls++, onSecondaryTapUp: (_, _) => upCalls++)));
      final pos = tester.getCenter(find.byType(TerminalView));
      final gesture = await tester.startGesture(pos, buttons: kSecondaryButton);
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
      expect(downCalls, isPositive);
      expect(upCalls, isPositive);
    });
  });

  group('TerminalView — selection gestures', () {
    // Cover the gesture_handler.dart selection paths and the gesture_detector
    // double-tap detection branch. Each test sets up a TerminalView with a
    // controller it can inspect; the gestures are wired into the
    // RenderTerminal which mutates `controller.selection`.
    // Empty cells (codepoint 0) and ASCII space are word separators in
    // `defaultWordSeparators`, so taps must land on a non-separator cell for
    // selectWord to return non-null. Write a wide stripe of 'a's at row 0
    // and tap near the top-left so the gesture lands on actual content.
    Offset contentPosition(WidgetTester tester) {
      final tl = tester.getTopLeft(find.byType(TerminalView));
      return tl + const Offset(20, 5);
    }

    testWidgets('double-tap sets a word selection on the controller', (tester) async {
      final t = _OutputRecorder().build();
      t.write('a' * 30);
      final controller = TerminalController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(TerminalView(t, controller: controller)));
      await tester.pump();
      final pos = contentPosition(tester);
      // Two tap-up cycles within kDoubleTapTimeout (~300 ms). The second
      // tap-down hits the within-tolerance branch in gesture_detector and
      // fires onDoubleTapDown, which in turn calls renderTerminal.selectWord.
      await tester.tapAt(pos);
      await tester.tapAt(pos);
      await tester.pump(const Duration(seconds: 1));
      expect(controller.selection, isNotNull);
    });

    testWidgets('long-press (touch) selects a word', (tester) async {
      final t = _OutputRecorder().build();
      t.write('a' * 30);
      final controller = TerminalController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(TerminalView(t, controller: controller)));
      await tester.pump();
      final pos = contentPosition(tester);
      final gesture = await tester.startGesture(pos, kind: PointerDeviceKind.touch);
      // LongPressGestureRecognizer's threshold is kLongPressTimeout (~500 ms);
      // pump past it to win the gesture.
      await tester.pump(const Duration(milliseconds: 600));
      // onLongPressStart → renderTerminal.selectWord → controller.selection set.
      expect(controller.selection, isNotNull);
      // Move during long-press → onLongPressMoveUpdate, second branch of
      // selectWord with two offsets.
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(controller.selection, isNotNull);
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('mouse drag selects characters (selectCharacters branch)', (tester) async {
      final t = _OutputRecorder().build();
      t.write('a' * 30);
      final controller = TerminalController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(TerminalView(t, controller: controller)));
      await tester.pump();
      final pos = contentPosition(tester);
      final gesture = await tester.startGesture(pos, kind: PointerDeviceKind.mouse);
      // PanGestureRecognizer needs movement beyond kPanSlop to win — push
      // past it before reading the selection.
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      // onDragStart fired with mouse kind → selectCharacters(from); subsequent
      // onDragUpdate → selectCharacters(from, to). Either way, controller has
      // a selection.
      expect(controller.selection, isNotNull);
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      expect(controller.selection, isNotNull);
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('TerminalView — keyboard / IME tail paths', () {
    // These cover the last few lines in terminal_view.dart that the existing
    // tests didn't quite touch: the onDelete callback wired into
    // CustomTextEdit, the hardwareKeyboardOnly tap branch that requests
    // focus directly, and the _onInsert path where the inserted character
    // maps to a TerminalKey (key != null).

    testWidgets('backspace via deleteDetection runs onDelete (scroll + keyInput)', (tester) async {
      final r = _OutputRecorder();
      final t = r.build();
      await tester.pumpWidget(_host(TerminalView(t, autofocus: true, deleteDetection: true)));
      await tester.pump();
      // deleteDetection seeds the editing value with two spaces; shrinking
      // it below that length triggers CustomTextEdit.onDelete, which fires
      // _scrollToBottom + Terminal.keyInput(backspace) in TerminalView.
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0)));
      await tester.pump();
      // Backspace produces a non-empty escape sequence (^?).
      expect(r.outputs, isNotEmpty);
    });

    testWidgets('tap on hardwareKeyboardOnly view requests focus on the focus node', (tester) async {
      final t = _OutputRecorder().build();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(_host(TerminalView(t, hardwareKeyboardOnly: true, focusNode: focus)));
      // Tap with no selection-clear short-circuit — the else-branch of
      // _onTapUp routes through _focusNode.requestFocus when
      // hardwareKeyboardOnly is set (no CustomTextEdit to delegate to).
      await tester.tapAt(tester.getCenter(find.byType(TerminalView)));
      await tester.pump(const Duration(seconds: 1));
      expect(focus.hasFocus, isTrue);
    });

    testWidgets('single-char IME insert routes through keyInput when the char maps to a TerminalKey', (tester) async {
      final r = _OutputRecorder();
      final t = r.build();
      await tester.pumpWidget(_host(TerminalView(t, autofocus: true)));
      await tester.pump();
      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(seconds: 1));
      // 'a' is a single char that maps to TerminalKey.a — _onInsert hits
      // the key != null branch and calls terminal.keyInput first.
      tester.testTextInput.enterText('a');
      await tester.pump();
      expect(r.outputs, isNotEmpty);
    });
  });
}
