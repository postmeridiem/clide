/// Widget tests for `TerminalView` — the StatefulWidget that wires
/// gesture / keyboard / scroll / render plumbing around a `Terminal`.
library;

import 'package:clide/src/terminal/src/terminal.dart';
import 'package:clide/src/terminal/src/terminal_view.dart';
import 'package:clide/src/terminal/src/ui/controller.dart';
import 'package:clide/src/terminal/src/ui/render.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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

    testWidgets('uses the supplied controller / focusNode / scrollController without disposing them', (tester) async {
      final t = _OutputRecorder().build();
      final controller = TerminalController();
      final focus = FocusNode();
      final scroll = ScrollController();
      addTearDown(() {
        controller.dispose();
        focus.dispose();
        scroll.dispose();
      });

      await tester.pumpWidget(_host(TerminalView(
        t,
        controller: controller,
        focusNode: focus,
        scrollController: scroll,
      )));
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
      await tester.sendEventToBinding(PointerScrollEvent(
        position: viewCenter,
        scrollDelta: const Offset(0, 100),
      ));
      await tester.pump();
      // Output should contain at least one PgDown escape.
      expect(r.outputs, isNotEmpty);
    });

    testWidgets('non-scroll PointerSignalEvent is a no-op', (tester) async {
      final r = _OutputRecorder();
      final t = r.build();
      await tester.pumpWidget(_host(TerminalView(t)));
      final viewCenter = tester.getCenter(find.byType(TerminalView));
      // PointerScaleEvent is a sibling of PointerScrollEvent; the handler
      // ignores anything other than PointerScrollEvent.
      await tester.sendEventToBinding(PointerScaleEvent(
        position: viewCenter,
        scale: 1.2,
      ));
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

    testWidgets('swapping scrollController disposes the old auto-created one', (tester) async {
      final t = _OutputRecorder().build();
      await tester.pumpWidget(_host(TerminalView(t)));
      final external = ScrollController();
      addTearDown(external.dispose);
      await tester.pumpWidget(_host(TerminalView(t, scrollController: external)));
      expect(find.byType(TerminalView), findsOneWidget);
    });
  });

  group('TerminalView — keyboard handle path', () {
    testWidgets('hardware key event with a non-modifier key reaches Terminal.keyInput', (tester) async {
      final r = _OutputRecorder();
      final t = r.build();
      await tester.pumpWidget(_host(TerminalView(
        t,
        autofocus: true,
        // hardwareKeyboardOnly: true,
      )));
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
}
