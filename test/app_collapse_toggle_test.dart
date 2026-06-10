/// Status-bar collapse toggle (T-294): a fixed cell pinned to a screen edge of
/// the bar, flipping a caret-line chevron to reflect the direction of the
/// action and firing the existing collapse commands.
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

Widget _host(KernelFixture f, Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: ClideKernel(
        services: f.services,
        child: ClideTheme(
          controller: f.services.theme,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(800, 200)),
            child: Align(alignment: Alignment.topLeft, child: SizedBox(height: 26, child: child)),
          ),
        ),
      ),
    );

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  testWidgets('chevron points the direction of the action (collapse vs expand)', (tester) async {
    // Sidebar open → action is collapse (leftward) → caret-line-left.
    await tester.pumpWidget(_host(f, const StatusbarCollapseToggle(slot: Slots.sidebar, collapsed: false, visible: true)));
    await tester.pump();
    expect(_icon(PhosphorIcons.byName('caret-line-left')), findsOneWidget);

    // Sidebar collapsed → action is expand (rightward) → caret-line-right.
    await tester.pumpWidget(_host(f, const StatusbarCollapseToggle(slot: Slots.sidebar, collapsed: true, visible: true)));
    await tester.pump();
    expect(_icon(PhosphorIcons.byName('caret-line-right')), findsOneWidget);

    // The context toggle mirrors it: open → collapse rightward, collapsed → expand leftward.
    await tester.pumpWidget(_host(f, const StatusbarCollapseToggle(slot: Slots.contextPanel, collapsed: false, visible: true)));
    await tester.pump();
    expect(_icon(PhosphorIcons.byName('caret-line-right')), findsOneWidget);
  });

  testWidgets('the chevron flips live when the collapsed state changes', (tester) async {
    var collapsed = false;
    late StateSetter setOuter;
    await tester.pumpWidget(_host(
      f,
      StatefulBuilder(builder: (ctx, setState) {
        setOuter = setState;
        return StatusbarCollapseToggle(slot: Slots.sidebar, collapsed: collapsed, visible: true);
      }),
    ));
    await tester.pump();
    expect(_icon(PhosphorIcons.byName('caret-line-left')), findsOneWidget);

    setOuter(() => collapsed = true);
    await tester.pump();
    expect(_icon(PhosphorIcons.byName('caret-line-right')), findsOneWidget, reason: 'rebuilds and flips on state change');
    expect(_icon(PhosphorIcons.byName('caret-line-left')), findsNothing);
  });

  testWidgets('a hidden pane reserves the cell but shows no chevron', (tester) async {
    await tester.pumpWidget(_host(f, const StatusbarCollapseToggle(slot: Slots.sidebar, collapsed: false, visible: false)));
    await tester.pump();
    expect(_icon(PhosphorIcons.byName('caret-line-left')), findsNothing);
    expect(_icon(PhosphorIcons.byName('caret-line-right')), findsNothing);
  });

  testWidgets('tapping fires the matching collapse command', (tester) async {
    f.services.arrangement.applyPreset(const LayoutPresetContribution(
      id: 'test',
      displayName: 'test',
      slots: [LayoutSlot(slot: Slots.sidebar, position: SlotPosition.left, visible: true)],
    ));
    f.services.extensions.register(DefaultLayoutExtension());
    await f.services.extensions.activate('builtin.default-layout');

    await tester.pumpWidget(_host(f, const StatusbarCollapseToggle(slot: Slots.sidebar, collapsed: false, visible: true)));
    await tester.pump();
    expect(f.services.arrangement.isCollapsed(Slots.sidebar), isFalse);

    await tester.tap(_icon(PhosphorIcons.byName('caret-line-left')));
    await tester.pump();

    expect(f.services.arrangement.isCollapsed(Slots.sidebar), isTrue);
  });
}
