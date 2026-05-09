/// Pure + widget tests for the small terminal helpers:
/// `lib/src/terminal/src/base/event.dart`,
/// `lib/src/terminal/src/ui/shortcut/shortcuts.dart`, and
/// `lib/src/terminal/src/ui/shortcut/actions.dart`.
library;

import 'package:clide/src/terminal/src/base/event.dart';
import 'package:clide/src/terminal/src/terminal.dart';
import 'package:clide/src/terminal/src/ui/controller.dart';
import 'package:clide/src/terminal/src/ui/shortcut/actions.dart';
import 'package:clide/src/terminal/src/ui/shortcut/shortcuts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Event / EventEmitter / EventSubscription', () {
    test('emit fans out to all listeners', () {
      final emitter = EventEmitter<int>();
      final received = <int>[];
      emitter((e) => received.add(e * 10));
      emitter((e) => received.add(e * 100));
      emitter.emit(2);
      expect(received, [20, 200]);
    });

    test('subscription.dispose removes the listener', () {
      final emitter = EventEmitter<String>();
      final received = <String>[];
      final sub = emitter(received.add);
      emitter.emit('a');
      sub.dispose();
      emitter.emit('b');
      expect(received, ['a']);
    });

    test('Event wrapper invokes the underlying emitter on call', () {
      final emitter = EventEmitter<int>();
      final event = emitter.event;
      final received = <int>[];
      event(received.add);
      emitter.emit(7);
      expect(received, [7]);
    });
  });

  group('defaultTerminalShortcuts', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('Linux/Windows/Android/Fuchsia use Ctrl-modified bindings', () {
      for (final p in [
        TargetPlatform.linux,
        TargetPlatform.windows,
        TargetPlatform.android,
        TargetPlatform.fuchsia,
      ]) {
        debugDefaultTargetPlatformOverride = p;
        final map = defaultTerminalShortcuts;
        // Three entries: copy / paste / select-all.
        expect(map.length, 3);
        // Spot-check the paste binding — Ctrl-V on these platforms.
        final pasteEntry = map.entries.firstWhere((e) => e.value is PasteTextIntent);
        final activator = pasteEntry.key as SingleActivator;
        expect(activator.trigger, LogicalKeyboardKey.keyV);
        expect(activator.control, isTrue);
        expect(activator.meta, isFalse);
      }
    });

    test('macOS/iOS use Meta-modified bindings', () {
      for (final p in [TargetPlatform.macOS, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = p;
        final map = defaultTerminalShortcuts;
        expect(map.length, 3);
        final pasteEntry = map.entries.firstWhere((e) => e.value is PasteTextIntent);
        final activator = pasteEntry.key as SingleActivator;
        expect(activator.trigger, LogicalKeyboardKey.keyV);
        expect(activator.meta, isTrue);
        expect(activator.control, isFalse);
      }
    });
  });

  group('TerminalActions', () {
    Widget host(Widget child) => Directionality(
          textDirection: TextDirection.ltr,
          child: child,
        );

    testWidgets('CopySelectionTextIntent writes selection text to the clipboard', (tester) async {
      final outputs = <String>[];
      final terminal = Terminal(maxLines: 100, onOutput: outputs.add);
      terminal.write('hello');
      final controller = TerminalController();
      addTearDown(controller.dispose);
      // Set a selection covering 'hello'.
      controller.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(5, 0),
      );

      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map;
            clipboardText = args['text'] as String?;
          }
          return null;
        },
      );

      late BuildContext capturedContext;
      await tester.pumpWidget(host(TerminalActions(
        terminal: terminal,
        controller: controller,
        child: Builder(builder: (context) {
          capturedContext = context;
          return const SizedBox();
        }),
      )));

      Actions.invoke(capturedContext, CopySelectionTextIntent.copy);
      await tester.pump();
      expect(clipboardText, contains('hello'));
    });

    testWidgets('CopySelectionTextIntent is a no-op when nothing is selected', (tester) async {
      final terminal = Terminal(maxLines: 100, onOutput: (_) {});
      final controller = TerminalController();
      addTearDown(controller.dispose);
      var setDataCalls = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') setDataCalls++;
          return null;
        },
      );

      late BuildContext ctx;
      await tester.pumpWidget(host(TerminalActions(
        terminal: terminal,
        controller: controller,
        child: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      )));

      Actions.invoke(ctx, CopySelectionTextIntent.copy);
      await tester.pump();
      expect(setDataCalls, 0);
    });

    testWidgets('PasteTextIntent pastes clipboard text into terminal and clears selection', (tester) async {
      final outputs = <String>[];
      final terminal = Terminal(maxLines: 100, onOutput: outputs.add);
      final controller = TerminalController();
      addTearDown(controller.dispose);
      controller.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(2, 0),
      );
      expect(controller.selection, isNotNull);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': 'pasted-payload'};
          }
          return null;
        },
      );

      late BuildContext ctx;
      await tester.pumpWidget(host(TerminalActions(
        terminal: terminal,
        controller: controller,
        child: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      )));

      Actions.invoke(ctx, const PasteTextIntent(SelectionChangedCause.keyboard));
      await tester.pumpAndSettle();

      // terminal.paste emits via onOutput; selection is cleared.
      expect(outputs.any((o) => o.contains('pasted-payload')), isTrue);
      expect(controller.selection, isNull);
    });

    testWidgets('SelectAllTextIntent sets a selection across the visible buffer', (tester) async {
      final terminal = Terminal(maxLines: 100, onOutput: (_) {});
      final controller = TerminalController();
      addTearDown(controller.dispose);
      expect(controller.selection, isNull);

      late BuildContext ctx;
      await tester.pumpWidget(host(TerminalActions(
        terminal: terminal,
        controller: controller,
        child: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      )));

      Actions.invoke(ctx, const SelectAllTextIntent(SelectionChangedCause.keyboard));
      await tester.pump();
      expect(controller.selection, isNotNull);
    });
  });
}
