/// Status-bar collapse toggles (T-294): a fixed cell bookends each end of the
/// status bar, flips a caret-line chevron per arrangement.isCollapsed, and fires
/// the existing sidebar.collapse / context.collapse commands.
library;

import 'package:clide/app.dart';
import 'package:clide/builtin/default_layout/default_layout.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/kernel_fixture.dart';

Finder _icon(PhosphorIconPainter p) => find.byWidgetPredicate((w) => w is ClideIcon && w.painter == p);

Widget _bar(KernelFixture f) => Directionality(
      textDirection: TextDirection.ltr,
      child: ClideKernel(
        services: f.services,
        child: ClideTheme(
          controller: f.services.theme,
          child: const MediaQuery(
            data: MediaQueryData(size: Size(800, 200)),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 800, height: 26, child: StatusbarHost()),
            ),
          ),
        ),
      ),
    );

void main() {
  late KernelFixture f;

  setUp(() async {
    f = await KernelFixture.create();
    f.services.arrangement.applyPreset(const LayoutPresetContribution(
      id: 'test',
      displayName: 'test',
      slots: [
        LayoutSlot(slot: Slots.sidebar, position: SlotPosition.left, visible: true),
        LayoutSlot(slot: Slots.contextPanel, position: SlotPosition.right, visible: true),
      ],
    ));
    f.services.extensions.register(DefaultLayoutExtension());
    await f.services.extensions.activate('builtin.default-layout');
  });
  tearDown(() => f.dispose());

  testWidgets('both toggles show, chevrons point inward when panes are open', (tester) async {
    await tester.pumpWidget(_bar(f));
    await tester.pump();
    // Sidebar (left end) collapses leftward → caret-line-left; context (right
    // end) collapses rightward → caret-line-right.
    expect(_icon(PhosphorIcons.caretLineLeft), findsOneWidget);
    expect(_icon(PhosphorIcons.caretLineRight), findsOneWidget);
  });

  testWidgets('a collapsed pane flips its chevron outward (expand affordance)', (tester) async {
    f.services.arrangement.setCollapsed(Slots.sidebar, true);
    await tester.pumpWidget(_bar(f));
    await tester.pump();
    // Sidebar now collapsed → its chevron points right (expand); context still
    // open → right. So two right-pointing, none left.
    expect(_icon(PhosphorIcons.caretLineRight), findsNWidgets(2));
    expect(_icon(PhosphorIcons.caretLineLeft), findsNothing);
  });

  testWidgets('tapping the sidebar toggle fires sidebar.collapse', (tester) async {
    await tester.pumpWidget(_bar(f));
    await tester.pump();
    expect(f.services.arrangement.isCollapsed(Slots.sidebar), isFalse);

    await tester.tap(_icon(PhosphorIcons.caretLineLeft)); // the open-sidebar toggle
    await tester.pump();

    expect(f.services.arrangement.isCollapsed(Slots.sidebar), isTrue);
  });

  testWidgets('a hidden pane reserves the cell but shows no toggle', (tester) async {
    f.services.arrangement.setVisible(Slots.contextPanel, false);
    await tester.pumpWidget(_bar(f));
    await tester.pump();
    // Sidebar toggle present (open → left); context hidden → no right chevron.
    expect(_icon(PhosphorIcons.caretLineLeft), findsOneWidget);
    expect(_icon(PhosphorIcons.caretLineRight), findsNothing);
  });
}
