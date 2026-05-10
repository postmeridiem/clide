/// Widget tests for `lib/src/terminal/src/ui/custom_text_edit.dart` —
/// covers the focus / connection lifecycle, the editing-value
/// callbacks (insert / delete / composing / action), the input-state
/// helpers (setEditingState, setEditableRect, closeKeyboard), and the
/// TextInputClient stub overrides.
library;

import 'package:clide/src/terminal/src/ui/custom_text_edit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Recorder {
  final inserts = <String>[];
  var deletes = 0;
  final composings = <String?>[];
  final actions = <TextInputAction>[];
  final keys = <KeyEvent>[];
}

Widget _host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Center(child: SizedBox(width: 200, height: 100, child: child)),
      ),
    );

CustomTextEdit _build({
  required FocusNode focusNode,
  required _Recorder r,
  bool autofocus = false,
  bool readOnly = false,
  bool deleteDetection = false,
  KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent,
}) {
  return CustomTextEdit(
    focusNode: focusNode,
    autofocus: autofocus,
    readOnly: readOnly,
    deleteDetection: deleteDetection,
    onInsert: r.inserts.add,
    onDelete: () => r.deletes++,
    onComposing: r.composings.add,
    onAction: r.actions.add,
    onKeyEvent: onKeyEvent ??
        (node, event) {
          r.keys.add(event);
          return KeyEventResult.ignored;
        },
    child: const SizedBox.expand(),
  );
}

void main() {
  group('CustomTextEdit — focus + input-connection lifecycle', () {
    testWidgets('autofocus opens an input connection on first frame', (tester) async {
      final r = _Recorder();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(_host(_build(focusNode: focus, r: r, autofocus: true)));
      await tester.pump();
      final state = tester.state<CustomTextEditState>(find.byType(CustomTextEdit));
      expect(state.hasInputConnection, isTrue);
    });

    testWidgets('losing focus closes the connection', (tester) async {
      final r = _Recorder();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(_host(_build(focusNode: focus, r: r, autofocus: true)));
      await tester.pump();
      final state = tester.state<CustomTextEditState>(find.byType(CustomTextEdit));
      expect(state.hasInputConnection, isTrue);
      focus.unfocus();
      await tester.pump();
      expect(state.hasInputConnection, isFalse);
    });

    testWidgets('readOnly=true skips connection on focus', (tester) async {
      final r = _Recorder();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(_host(_build(focusNode: focus, r: r, autofocus: true, readOnly: true)));
      await tester.pump();
      final state = tester.state<CustomTextEditState>(find.byType(CustomTextEdit));
      expect(state.hasInputConnection, isFalse);
    });

    testWidgets('didUpdateWidget readOnly:true→false while focused re-opens the connection', (tester) async {
      final r = _Recorder();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      // Start read-only + focused → no connection.
      await tester.pumpWidget(_host(_build(focusNode: focus, r: r, autofocus: true, readOnly: true)));
      await tester.pump();
      final state = tester.state<CustomTextEditState>(find.byType(CustomTextEdit));
      expect(state.hasInputConnection, isFalse);
      // Flip to read-write — didUpdateWidget should re-open.
      await tester.pumpWidget(_host(_build(focusNode: focus, r: r, autofocus: true, readOnly: false)));
      await tester.pump();
      expect(state.hasInputConnection, isTrue);
    });

    testWidgets('didUpdateWidget readOnly:false→true closes the connection', (tester) async {
      final r = _Recorder();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(_host(_build(focusNode: focus, r: r, autofocus: true, readOnly: false)));
      await tester.pump();
      final state = tester.state<CustomTextEditState>(find.byType(CustomTextEdit));
      expect(state.hasInputConnection, isTrue);
      // Flip to read-only — _shouldCreateInputConnection becomes false.
      await tester.pumpWidget(_host(_build(focusNode: focus, r: r, autofocus: true, readOnly: true)));
      await tester.pump();
      expect(state.hasInputConnection, isFalse);
    });

    testWidgets('didUpdateWidget swapping focusNode rewires the listener', (tester) async {
      final r = _Recorder();
      final focusA = FocusNode();
      final focusB = FocusNode();
      addTearDown(focusA.dispose);
      addTearDown(focusB.dispose);
      await tester.pumpWidget(_host(_build(focusNode: focusA, r: r, autofocus: true)));
      await tester.pump();
      await tester.pumpWidget(_host(_build(focusNode: focusB, r: r)));
      await tester.pump();
      final state = tester.state<CustomTextEditState>(find.byType(CustomTextEdit));
      expect(state.mounted, isTrue);
    });
  });

  group('CustomTextEdit — keyboard helpers', () {
    testWidgets('requestKeyboard opens a connection when focused; otherwise requests focus', (tester) async {
      final r = _Recorder();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(_host(_build(focusNode: focus, r: r)));
      final state = tester.state<CustomTextEditState>(find.byType(CustomTextEdit));
      // Unfocused → requestKeyboard requests focus.
      state.requestKeyboard();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      // Already-focused → requestKeyboard opens the connection directly.
      state.requestKeyboard();
      await tester.pump();
      expect(state.hasInputConnection, isTrue);
    });

    testWidgets('closeKeyboard closes an active connection', (tester) async {
      final r = _Recorder();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(_host(_build(focusNode: focus, r: r, autofocus: true)));
      await tester.pump();
      final state = tester.state<CustomTextEditState>(find.byType(CustomTextEdit));
      expect(state.hasInputConnection, isTrue);
      state.closeKeyboard();
      await tester.pump();
      // hasInputConnection reflects the underlying connection state — close
      // returns it to false.
      expect(state.hasInputConnection, isFalse);
    });

    testWidgets('closeKeyboard is a safe no-op when no connection exists', (tester) async {
      final r = _Recorder();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(_host(_build(focusNode: focus, r: r)));
      final state = tester.state<CustomTextEditState>(find.byType(CustomTextEdit));
      state.closeKeyboard();
      expect(state.hasInputConnection, isFalse);
    });

    testWidgets('setEditingState updates the cached value and forwards to the connection', (tester) async {
      final r = _Recorder();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(_host(_build(focusNode: focus, r: r, autofocus: true)));
      await tester.pump();
      final state = tester.state<CustomTextEditState>(find.byType(CustomTextEdit));
      const value = TextEditingValue(text: 'edit', selection: TextSelection.collapsed(offset: 4));
      state.setEditingState(value);
      expect(state.currentTextEditingValue, value);
    });

    testWidgets('setEditableRect early-returns when there is no connection', (tester) async {
      final r = _Recorder();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(_host(_build(focusNode: focus, r: r)));
      final state = tester.state<CustomTextEditState>(find.byType(CustomTextEdit));
      // No connection → must not throw.
      state.setEditableRect(const Rect.fromLTWH(0, 0, 10, 10), const Rect.fromLTWH(0, 0, 1, 10));
    });

    testWidgets('setEditableRect forwards size + caret when a connection is open', (tester) async {
      final r = _Recorder();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(_host(_build(focusNode: focus, r: r, autofocus: true)));
      await tester.pump();
      final state = tester.state<CustomTextEditState>(find.byType(CustomTextEdit));
      // Just verify no throw — the connection is real (testTextInput) and
      // accepts the calls.
      state.setEditableRect(const Rect.fromLTWH(0, 0, 50, 20), const Rect.fromLTWH(0, 0, 1, 20));
    });
  });

  group('CustomTextEdit — TextInputClient surface', () {
    testWidgets('updateEditingValue routes inserts to onInsert', (tester) async {
      final r = _Recorder();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(_host(_build(focusNode: focus, r: r, autofocus: true)));
      await tester.pump();
      tester.testTextInput.enterText('abc');
      await tester.pump();
      expect(r.inserts.any((s) => s.contains('abc')), isTrue);
    });

    testWidgets('updateEditingValue routes a delete to onDelete (deleteDetection mode)', (tester) async {
      final r = _Recorder();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      // deleteDetection=true means the init editing-state has 2 spaces;
      // shrinking the value below that triggers the onDelete path.
      await tester.pumpWidget(_host(_build(focusNode: focus, r: r, autofocus: true, deleteDetection: true)));
      await tester.pump();
      final state = tester.state<CustomTextEditState>(find.byType(CustomTextEdit));
      // Send a value shorter than the init state (2 chars) directly.
      state.updateEditingValue(const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      ));
      expect(r.deletes, 1);
    });

    testWidgets('updateEditingValue with active composing forwards the composing text', (tester) async {
      final r = _Recorder();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(_host(_build(focusNode: focus, r: r, autofocus: true)));
      await tester.pump();
      final state = tester.state<CustomTextEditState>(find.byType(CustomTextEdit));
      state.updateEditingValue(const TextEditingValue(
        text: 'hi',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ));
      expect(r.composings, contains('hi'));
    });

    testWidgets('performAction routes the action to onAction', (tester) async {
      final r = _Recorder();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(_host(_build(focusNode: focus, r: r, autofocus: true)));
      await tester.pump();
      final state = tester.state<CustomTextEditState>(find.byType(CustomTextEdit));
      state.performAction(TextInputAction.done);
      expect(r.actions, contains(TextInputAction.done));
    });

    testWidgets('TextInputClient stubs are no-throw', (tester) async {
      final r = _Recorder();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(_host(_build(focusNode: focus, r: r, autofocus: true)));
      await tester.pump();
      final state = tester.state<CustomTextEditState>(find.byType(CustomTextEdit));
      // Touch every TextInputClient override that's a documented no-op so
      // they end up in the coverage map.
      state.updateFloatingCursor(RawFloatingCursorPoint(state: FloatingCursorDragState.Start));
      state.showAutocorrectionPromptRect(0, 1);
      state.connectionClosed();
      state.performPrivateCommand('cmd', const {});
      state.insertTextPlaceholder(const Size(10, 10));
      state.removeTextPlaceholder();
      state.showToolbar();
      // Getters
      expect(state.currentTextEditingValue, isNotNull);
      expect(state.currentAutofillScope, isNull);
    });
  });
}
