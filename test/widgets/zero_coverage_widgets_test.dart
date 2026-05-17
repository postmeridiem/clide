/// Smoke + branch tests for the previously-uncovered widgets under
/// `lib/widgets/src/`: ClidePalette, ClideFilterBox, ColumnHat,
/// ClideIconRail, ClideSpine, ClideResizeBorder.
library;

import 'package:clide/clide.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/widgets/src/clide_column_hat.dart';
import 'package:clide/widgets/src/clide_filter_box.dart';
import 'package:clide/widgets/src/clide_icon_rail.dart';
import 'package:clide/widgets/src/clide_palette.dart';
import 'package:clide/widgets/src/clide_resize_border.dart';
import 'package:clide/widgets/src/clide_spine.dart';
import 'package:clide/widgets/src/icons/phosphor.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/kernel_fixture.dart';
import '../helpers/widget_harness.dart';

void main() {
  group('ClidePalette', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    testWidgets('renders nothing when the palette is closed', (tester) async {
      await tester.pumpWidget(harness(f, Stack(children: const [ClidePalette()])));
      expect(find.byType(EditableText), findsNothing);
    });

    testWidgets('opens to show an input field + the registered commands', (tester) async {
      f.services.commands.register(CommandContribution(
        id: 'c1',
        command: 'cmd.one',
        title: 'Command One',
        defaultBinding: 'ctrl+1',
        run: (_) async => IpcResponse.ok(id: '', data: const {}),
      ));
      f.services.commands.register(CommandContribution(
        id: 'c2',
        command: 'cmd.two',
        title: 'Command Two',
        run: (_) async => IpcResponse.ok(id: '', data: const {}),
      ));
      f.services.palette.open();
      await tester.pumpWidget(harness(f, Stack(children: const [ClidePalette()])));
      await tester.pumpAndSettle();
      expect(find.byType(EditableText), findsOneWidget);
      expect(find.text('Command One'), findsOneWidget);
      expect(find.text('Command Two'), findsOneWidget);
    });

    testWidgets('tapping a row invokes the command + closes the palette', (tester) async {
      var invocations = 0;
      f.services.commands.register(CommandContribution(
        id: 'c1',
        command: 'tap.target',
        title: 'Tap Target',
        run: (_) async {
          invocations++;
          return IpcResponse.ok(id: '', data: const {});
        },
      ));
      f.services.palette.open();
      await tester.pumpWidget(harness(f, Stack(children: const [ClidePalette()])));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tap Target'));
      await tester.pumpAndSettle();
      expect(invocations, 1);
    });

    testWidgets('typing narrows the visible commands via palette.setFilter', (tester) async {
      f.services.commands.register(CommandContribution(
        id: 'c1',
        command: 'alpha.cmd',
        title: 'Alpha',
        run: (_) async => IpcResponse.ok(id: '', data: const {}),
      ));
      f.services.commands.register(CommandContribution(
        id: 'c2',
        command: 'beta.cmd',
        title: 'Beta',
        run: (_) async => IpcResponse.ok(id: '', data: const {}),
      ));
      f.services.palette.open();
      await tester.pumpWidget(harness(f, Stack(children: const [ClidePalette()])));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(EditableText), 'alpha');
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsNothing);
    });

    testWidgets('submitting the input invokes the first filtered command', (tester) async {
      var invocations = 0;
      f.services.commands.register(CommandContribution(
        id: 'c1',
        command: 'submit.target',
        title: 'Submit Target',
        run: (_) async {
          invocations++;
          return IpcResponse.ok(id: '', data: const {});
        },
      ));
      f.services.commands.register(CommandContribution(
        id: 'c2',
        command: 'other.cmd',
        title: 'Other',
        run: (_) async => IpcResponse.ok(id: '', data: const {}),
      ));
      f.services.palette.open();
      await tester.pumpWidget(harness(f, Stack(children: const [ClidePalette()])));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(EditableText), 'submit');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(invocations, 1);
    });

    testWidgets('hovering a palette row updates its hover state', (tester) async {
      f.services.commands.register(CommandContribution(
        id: 'c1',
        command: 'hover.cmd',
        title: 'Hoverable',
        run: (_) async => IpcResponse.ok(id: '', data: const {}),
      ));
      f.services.palette.open();
      await tester.pumpWidget(harness(f, Stack(children: const [ClidePalette()])));
      await tester.pumpAndSettle();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.text('Hoverable')));
      await tester.pumpAndSettle();
      // Exit again to also exercise the onExit branch.
      await gesture.moveTo(const Offset(2000, 2000));
      await tester.pumpAndSettle();
      expect(find.text('Hoverable'), findsOneWidget);
    });

    testWidgets('arrow keys move the highlighted command (T-100)', (tester) async {
      for (final id in ['a', 'b', 'c']) {
        f.services.commands.register(CommandContribution(
          id: id,
          command: 'cmd.$id',
          title: 'Item $id',
          run: (_) async => IpcResponse.ok(id: '', data: const {}),
        ));
      }
      f.services.palette.open();
      await tester.pumpWidget(harness(f, Stack(children: const [ClidePalette()])));
      await tester.pumpAndSettle();

      // selectedIndex starts at 0.
      expect(f.services.palette.selectedIndex, 0);

      // Dispatch palette intents directly against the palette's
      // focused context — what the keymap would do for ↓ / ↑.
      final ctx = f.services.palette.isOpen ? FocusManager.instance.primaryFocus?.context : null;
      Actions.invoke(ctx!, const PaletteSelectNextIntent());
      expect(f.services.palette.selectedIndex, 1);
      Actions.invoke(ctx, const PaletteSelectNextIntent());
      expect(f.services.palette.selectedIndex, 2);
      // Wraps at end.
      Actions.invoke(ctx, const PaletteSelectNextIntent());
      expect(f.services.palette.selectedIndex, 0);
      // Wraps backwards at start.
      Actions.invoke(ctx, const PaletteSelectPreviousIntent());
      expect(f.services.palette.selectedIndex, 2);
    });

    testWidgets('PaletteAcceptIntent invokes the highlighted command (T-100)', (tester) async {
      var which = '';
      for (final id in ['a', 'b', 'c']) {
        f.services.commands.register(CommandContribution(
          id: id,
          command: 'cmd.$id',
          title: 'Item $id',
          run: (_) async {
            which = id;
            return IpcResponse.ok(id: '', data: const {});
          },
        ));
      }
      f.services.palette.open();
      await tester.pumpWidget(harness(f, Stack(children: const [ClidePalette()])));
      await tester.pumpAndSettle();

      final ctx = FocusManager.instance.primaryFocus!.context!;
      Actions.invoke(ctx, const PaletteSelectNextIntent());
      Actions.invoke(ctx, const PaletteAcceptIntent());
      await tester.pumpAndSettle();
      expect(which, 'b');
      expect(f.services.palette.isOpen, isFalse, reason: 'acceptSelected closes the palette');
    });

    testWidgets('DismissIntent closes the palette (T-100)', (tester) async {
      f.services.commands.register(CommandContribution(
        id: 'c1',
        command: 'thing',
        title: 'Thing',
        run: (_) async => IpcResponse.ok(id: '', data: const {}),
      ));
      f.services.palette.open();
      await tester.pumpWidget(harness(f, Stack(children: const [ClidePalette()])));
      await tester.pumpAndSettle();

      final ctx = FocusManager.instance.primaryFocus!.context!;
      Actions.invoke(ctx, const DismissIntent());
      await tester.pumpAndSettle();
      expect(f.services.palette.isOpen, isFalse);
    });

    testWidgets('opening the palette publishes palette.open scope flag (T-100)', (tester) async {
      await tester.pumpWidget(harness(f, Stack(children: const [ClidePalette()])));
      await tester.pumpAndSettle();
      expect(f.services.keymap.scope['palette.open'] ?? false, isFalse);
      f.services.palette.open();
      await tester.pumpAndSettle();
      expect(f.services.keymap.scope['palette.open'], isTrue);
      f.services.palette.close();
      await tester.pumpAndSettle();
      expect(f.services.keymap.scope['palette.open'], isFalse);
    });
  });

  group('ClideFilterBox', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    testWidgets('debounces onChanged calls to the configured duration', (tester) async {
      final values = <String>[];
      await tester.pumpWidget(harness(
        f,
        ClideFilterBox(
          onChanged: values.add,
          debounce: const Duration(milliseconds: 50),
        ),
      ));
      // Type into the editable text field.
      await tester.enterText(find.byType(EditableText), 'abc');
      // Before the debounce elapses no call.
      await tester.pump(const Duration(milliseconds: 10));
      expect(values, isEmpty);
      // After it fires we get exactly one call with the final value.
      await tester.pump(const Duration(milliseconds: 100));
      expect(values, ['abc']);
    });

    testWidgets('clear button appears once the field has text and resets onChanged when tapped', (tester) async {
      final values = <String>[];
      await tester.pumpWidget(harness(
        f,
        ClideFilterBox(
          onChanged: values.add,
          debounce: const Duration(milliseconds: 10),
        ),
      ));
      // No clear icon when the field is empty.
      expect(find.byType(GestureDetector), findsNothing);
      await tester.enterText(find.byType(EditableText), 'foo');
      await tester.pump(const Duration(milliseconds: 50));
      // The clear button is the only GestureDetector wrapped around the
      // trailing icon when there's text.
      expect(find.byType(GestureDetector), findsOneWidget);
      await tester.tap(find.byType(GestureDetector));
      await tester.pumpAndSettle();
      expect(values.last, isEmpty);
    });

    testWidgets('onSubmitted fires when the field is submitted', (tester) async {
      String? submitted;
      await tester.pumpWidget(harness(
        f,
        ClideFilterBox(
          onChanged: (_) {},
          onSubmitted: (v) => submitted = v,
        ),
      ));
      await tester.enterText(find.byType(EditableText), 'submit-me');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(submitted, 'submit-me');
    });
  });

  group('ColumnHat', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    testWidgets('left / center / right factories render', (tester) async {
      final wc = WindowControls();
      addTearDown(wc.dispose);
      await tester.pumpWidget(harness(
        f,
        Column(children: [
          SizedBox(width: 200, child: ColumnHat.left(windowControls: wc)),
          SizedBox(width: 200, child: ColumnHat.center(windowControls: wc, project: 'clide', branch: 'main')),
          SizedBox(width: 200, child: ColumnHat.right(windowControls: wc)),
        ]),
      ));
      // Center hat renders the joined label.
      expect(find.text('clide > main'), findsOneWidget);
    });

    testWidgets('center hat falls back to "clide" with no project/branch', (tester) async {
      final wc = WindowControls();
      addTearDown(wc.dispose);
      await tester.pumpWidget(harness(
        f,
        SizedBox(width: 200, child: ColumnHat.center(windowControls: wc)),
      ));
      expect(find.text('clide'), findsOneWidget);
    });
  });

  group('ClideIconRail', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    testWidgets('renders one button per item, marks the active one, fires onSelect', (tester) async {
      String? selected;
      await tester.pumpWidget(harness(
        f,
        ClideIconRail(
          items: const [
            ClideIconRailItem(id: 'a', icon: PhosphorIcons.folder, tooltip: 'A'),
            ClideIconRailItem(id: 'b', icon: PhosphorIcons.gitBranch, tooltip: 'B'),
          ],
          activeId: 'a',
          onSelect: (id) => selected = id,
        ),
      ));
      await tester.pumpAndSettle();
      // Each item exposes a tooltip-labeled semantics button.
      expect(find.bySemanticsLabel('A'), findsOneWidget);
      expect(find.bySemanticsLabel('B'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('B'));
      expect(selected, 'b');
    });
  });

  group('ClideSpine', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    testWidgets('renders the rotated label + a badge dot when badgeCount > 0', (tester) async {
      var taps = 0;
      await tester.pumpWidget(harness(
        f,
        SizedBox(
            height: 200,
            width: ClideSpine.width,
            child: ClideSpine(
              label: 'SIDEBAR',
              badgeCount: 3,
              onExpand: () => taps++,
            )),
      ));
      await tester.pumpAndSettle();
      expect(find.text('SIDEBAR'), findsOneWidget);
      // Tap to expand.
      await tester.tap(find.byType(ClideSpine));
      expect(taps, 1);
    });

    testWidgets('renders the right-side variant without throwing', (tester) async {
      await tester.pumpWidget(harness(
        f,
        SizedBox(
            height: 200,
            width: ClideSpine.width,
            child: ClideSpine(
              label: 'CTX',
              side: SpineSide.right,
              onExpand: () {},
            )),
      ));
      await tester.pumpAndSettle();
      expect(find.text('CTX'), findsOneWidget);
    });
  });

  group('ClideResizeBorder', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    testWidgets('wraps a child and renders 8 resize zones', (tester) async {
      final wc = WindowControls();
      addTearDown(wc.dispose);
      await tester.pumpWidget(harness(
        f,
        ClideResizeBorder(
          windowControls: wc,
          child: const SizedBox.expand(child: ColoredBox(color: Color(0xFF000000))),
        ),
      ));
      await tester.pumpAndSettle();
      // 4 corners + 4 edges = 8 zones each with a MouseRegion.
      expect(find.byType(MouseRegion).evaluate().length, greaterThanOrEqualTo(8));
    });
  });
}
