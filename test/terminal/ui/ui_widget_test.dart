/// Widget tests for `lib/src/terminal/src/ui/` widget-level helpers
/// (CustomKeyboardListener, KeyboardVisibilty, InfiniteScrollView,
/// TerminalScrollGestureHandler).
library;

import 'package:clide/src/terminal/src/core/buffer/cell_offset.dart';
import 'package:clide/src/terminal/src/core/mouse/mode.dart';
import 'package:clide/src/terminal/src/terminal.dart';
import 'package:clide/src/terminal/src/ui/infinite_scroll_view.dart';
import 'package:clide/src/terminal/src/ui/keyboard_listener.dart';
import 'package:clide/src/terminal/src/ui/keyboard_visibility.dart';
import 'package:clide/src/terminal/src/ui/scroll_handler.dart';
import 'package:flutter/gestures.dart';
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

      await tester.pumpWidget(_host(
        CustomKeyboardListener(
          focusNode: focus,
          autofocus: true,
          onInsert: inserts.add,
          onComposing: composings.add,
          onKeyEvent: (_, __) => KeyEventResult.ignored,
          child: const ColoredBox(color: Color(0xFF000000), child: SizedBox.expand()),
        ),
      ));
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

      await tester.pumpWidget(_host(
        CustomKeyboardListener(
          focusNode: focus,
          autofocus: true,
          onInsert: inserts.add,
          onComposing: (_) {},
          onKeyEvent: (_, __) => KeyEventResult.handled,
          child: const ColoredBox(color: Color(0xFF000000), child: SizedBox.expand()),
        ),
      ));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
      await tester.pump();
      expect(inserts, isEmpty);
    });

    testWidgets('does not call onInsert when the key event has no character', (tester) async {
      final inserts = <String>[];
      final focus = FocusNode();
      addTearDown(focus.dispose);

      await tester.pumpWidget(_host(
        CustomKeyboardListener(
          focusNode: focus,
          autofocus: true,
          onInsert: inserts.add,
          onComposing: (_) {},
          onKeyEvent: (_, __) => KeyEventResult.ignored,
          child: const ColoredBox(color: Color(0xFF000000), child: SizedBox.expand()),
        ),
      ));
      await tester.pump();
      // ArrowUp has no `character` — ignored result + no character means
      // _onKeyEvent returns ignored without firing onInsert.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(inserts, isEmpty);
    });
  });

  group('KeyboardVisibilty', () {
    testWidgets('fires onKeyboardShow when bottom inset goes positive, onKeyboardHide when it returns to 0', (tester) async {
      var shows = 0;
      var hides = 0;
      await tester.pumpWidget(_host(
        KeyboardVisibilty(
          onKeyboardShow: () => shows++,
          onKeyboardHide: () => hides++,
          child: const ColoredBox(color: Color(0xFF000000), child: SizedBox.expand()),
        ),
      ));
      await tester.pump();

      // Simulate keyboard appearance.
      tester.view.viewInsets = const FakeViewPadding(bottom: 200, left: 0, right: 0, top: 0);
      tester.binding.handleMetricsChanged();
      await tester.pump();
      expect(shows, 1);
      expect(hides, 0);

      // Simulate keyboard dismissal.
      tester.view.resetViewInsets();
      tester.binding.handleMetricsChanged();
      await tester.pump();
      expect(hides, 1);
    });

    testWidgets('repeated metrics events with the same bottom inset fire callbacks only when the inset changes', (tester) async {
      var shows = 0;
      await tester.pumpWidget(_host(
        KeyboardVisibilty(
          onKeyboardShow: () => shows++,
          child: const ColoredBox(color: Color(0xFF000000), child: SizedBox.expand()),
        ),
      ));
      await tester.pump();

      tester.view.viewInsets = const FakeViewPadding(bottom: 200, left: 0, right: 0, top: 0);
      tester.binding.handleMetricsChanged();
      await tester.pump();
      // Fire metrics again with the same inset — should not trigger again.
      tester.binding.handleMetricsChanged();
      await tester.pump();
      expect(shows, 1);
      addTearDown(tester.view.resetViewInsets);
    });
  });

  group('InfiniteScrollView', () {
    testWidgets('reports a scroll offset to onScroll when the viewport position moves', (tester) async {
      final offsets = <double>[];
      await tester.pumpWidget(_host(
        InfiniteScrollView(
          onScroll: offsets.add,
          child: const SizedBox(width: 400, height: 1000),
        ),
      ));
      await tester.pump();

      // Drive the underlying ViewportOffset by sending a scroll event into
      // the Scrollable.
      final scrollable = find.byType(Scrollable);
      await tester.drag(scrollable, const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(offsets, isNotEmpty);
    });

    testWidgets('updates render object when onScroll callback identity changes', (tester) async {
      var firstCalls = 0;
      var secondCalls = 0;
      Widget build(void Function(double) cb) => _host(
            InfiniteScrollView(
              onScroll: cb,
              child: const SizedBox(width: 400, height: 1000),
            ),
          );

      await tester.pumpWidget(build((_) => firstCalls++));
      await tester.pump();
      await tester.drag(find.byType(Scrollable), const Offset(0, -50));
      await tester.pumpAndSettle();
      final firstCount = firstCalls;
      expect(firstCount, isPositive);

      // Swap callback identity — render object's onScroll setter must update.
      await tester.pumpWidget(build((_) => secondCalls++));
      await tester.pump();
      await tester.drag(find.byType(Scrollable), const Offset(0, -50));
      await tester.pumpAndSettle();
      expect(secondCalls, isPositive);
      expect(firstCalls, firstCount); // first stops firing after swap
    });
  });

  group('TerminalScrollGestureHandler', () {
    testWidgets('main-buffer mode passes through without intercepting scroll', (tester) async {
      final terminal = Terminal(maxLines: 100);
      final handlerCalls = <Offset>[];

      await tester.pumpWidget(_host(
        TerminalScrollGestureHandler(
          terminal: terminal,
          getCellOffset: (offset) {
            handlerCalls.add(offset);
            return const CellOffset(0, 0);
          },
          getLineHeight: () => 14.0,
          child: const ColoredBox(color: Color(0xFF000000), child: SizedBox.expand()),
        ),
      ));
      await tester.pump();
      // Main-buffer mode → the handler returns the child directly, no
      // Listener around it. Sending a scroll event reaches nothing.
      final pos = tester.getCenter(find.byType(TerminalScrollGestureHandler));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: pos);
      await tester.sendEventToBinding(PointerScrollEvent(
        position: pos,
        scrollDelta: const Offset(0, 100),
      ));
      await tester.pump();
      expect(handlerCalls, isEmpty);
    });

    testWidgets('alt-buffer mode intercepts scroll; falls back to keyInput when terminal does not handle the mouse event', (tester) async {
      final outputs = <String>[];
      final terminal = Terminal(maxLines: 100, onOutput: outputs.add);
      terminal.useAltBuffer();
      // No mouse mode set on the terminal — mouseInput will return false,
      // so the simulateScroll fallback kicks in (sends arrow keys).

      await tester.pumpWidget(_host(
        TerminalScrollGestureHandler(
          terminal: terminal,
          getCellOffset: (_) => const CellOffset(0, 0),
          getLineHeight: () => 14.0,
          child: const ColoredBox(color: Color(0xFF000000), child: SizedBox.expand()),
        ),
      ));
      await tester.pump();
      // Confirm the Listener is in the tree (isAltBuffer recognised on
      // initial build).
      expect(find.byType(Listener), findsOneWidget);

      final pos = tester.getCenter(find.byType(TerminalScrollGestureHandler));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: pos);
      await tester.sendEventToBinding(PointerScrollEvent(
        position: pos,
        scrollDelta: const Offset(0, 100),
      ));
      await tester.pump();
      // Falls back to TerminalKey.arrowDown via simulateScroll path → emits
      // an escape via the default keytab.
      expect(outputs, isNotEmpty);
    });

    testWidgets('alt-buffer mode + active mouse mode forwards as a real mouse event (no key fallback)', (tester) async {
      final outputs = <String>[];
      final terminal = Terminal(maxLines: 100, onOutput: outputs.add);
      terminal.useAltBuffer();
      // Activate a mouse mode so terminal.mouseInput consumes wheel events.
      terminal.setMouseMode(MouseMode.upDownScroll);

      await tester.pumpWidget(_host(
        TerminalScrollGestureHandler(
          terminal: terminal,
          getCellOffset: (_) => const CellOffset(0, 0),
          getLineHeight: () => 14.0,
          child: const ColoredBox(color: Color(0xFF000000), child: SizedBox.expand()),
        ),
      ));
      await tester.pump();
      final pos = tester.getCenter(find.byType(TerminalScrollGestureHandler));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: pos);
      await tester.sendEventToBinding(PointerScrollEvent(
        position: pos,
        scrollDelta: const Offset(0, 100),
      ));
      await tester.pump();
      // Mouse-mode active → mouseInput consumes; output is the mouse-report
      // escape, not a PgDown / arrow.
      expect(outputs, isNotEmpty);
    });

    testWidgets('alt-buffer mode with simulateScroll=false drops scrolls when the terminal does not consume them', (tester) async {
      final outputs = <String>[];
      final terminal = Terminal(maxLines: 100, onOutput: outputs.add);
      terminal.useAltBuffer();

      await tester.pumpWidget(_host(
        TerminalScrollGestureHandler(
          terminal: terminal,
          getCellOffset: (_) => const CellOffset(0, 0),
          getLineHeight: () => 14.0,
          simulateScroll: false,
          child: const ColoredBox(color: Color(0xFF000000), child: SizedBox.expand()),
        ),
      ));
      await tester.pump();
      final pos = tester.getCenter(find.byType(TerminalScrollGestureHandler));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: pos);
      await tester.sendEventToBinding(PointerScrollEvent(
        position: pos,
        scrollDelta: const Offset(0, 100),
      ));
      await tester.pump();
      // Terminal didn't consume + simulateScroll false → no output at all.
      expect(outputs, isEmpty);
    });

    testWidgets('switching the terminal into alt buffer flips the handler from passthrough to intercepting', (tester) async {
      final terminal = Terminal(maxLines: 100);
      await tester.pumpWidget(_host(
        TerminalScrollGestureHandler(
          terminal: terminal,
          getCellOffset: (_) => const CellOffset(0, 0),
          getLineHeight: () => 14.0,
          child: const ColoredBox(color: Color(0xFF000000), child: SizedBox.expand()),
        ),
      ));
      await tester.pump();
      // Initially main-buffer → no Listener wrapping.
      expect(find.byType(Listener), findsNothing);

      terminal.useAltBuffer();
      terminal.write(''); // notifyListeners via parser.write
      await tester.pump();
      // Alt-buffer → Listener wraps the child.
      expect(find.byType(Listener), findsOneWidget);
    });

    testWidgets('alt-buffer Listener tracks pointer-down location for scroll-event positioning', (tester) async {
      // Covers the onPointerDown handler that captures _lastPointerPosition
      // for use by the next scroll event.
      final outputs = <String>[];
      final terminal = Terminal(maxLines: 100, onOutput: outputs.add)..useAltBuffer();
      final cellOffsets = <Offset>[];
      await tester.pumpWidget(_host(
        TerminalScrollGestureHandler(
          terminal: terminal,
          getCellOffset: (offset) {
            cellOffsets.add(offset);
            return const CellOffset(0, 0);
          },
          getLineHeight: () => 14.0,
          child: const ColoredBox(
            color: Color(0xFF000000),
            child: SizedBox.expand(),
          ),
        ),
      ));
      await tester.pump();
      final pos = tester.getCenter(find.byType(TerminalScrollGestureHandler));
      // Press first — that triggers onPointerDown which records the
      // position into _lastPointerPosition.
      final mouse = await tester.startGesture(pos, kind: PointerDeviceKind.mouse);
      // Now scroll — getCellOffset is called with _lastPointerPosition.
      await tester.sendEventToBinding(PointerScrollEvent(
        position: pos,
        scrollDelta: const Offset(0, 100),
      ));
      await tester.pump();
      await mouse.up();
      await tester.pumpAndSettle();
      expect(cellOffsets, isNotEmpty);
    });

    testWidgets('didUpdateWidget rebinds listeners when the terminal instance changes', (tester) async {
      final t1 = Terminal(maxLines: 100);
      final t2 = Terminal(maxLines: 100)..useAltBuffer();
      Widget build(Terminal t) => _host(
            TerminalScrollGestureHandler(
              terminal: t,
              getCellOffset: (_) => const CellOffset(0, 0),
              getLineHeight: () => 14.0,
              child: const ColoredBox(color: Color(0xFF000000), child: SizedBox.expand()),
            ),
          );
      await tester.pumpWidget(build(t1));
      await tester.pump();
      await tester.pumpWidget(build(t2));
      await tester.pump();
      // The Listener should now be present because t2 is in alt-buffer.
      expect(find.byType(Listener), findsOneWidget);
    });
  });
}
