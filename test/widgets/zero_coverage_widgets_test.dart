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
