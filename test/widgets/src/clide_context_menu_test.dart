/// Tests for [ClideContextMenu] — the pointer-anchored menu primitive
/// behind clide's right-click surfaces (D-109, T-579).
///
/// Covers the three things the primitive owns over plain [ClideMenu]:
/// positioning at a pointer, staying inside the viewport when that pointer is
/// near an edge, and dismissal (select, tap-away). Plus the shared mapper from
/// Flutter's computed [ContextMenuButtonItem]s onto localised rows.
library;

import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;

  setUp(() async => f = await KernelFixture.create());
  tearDown(() async => f.dispose());

  /// Mounts a sized tree and hands back a context under the Overlay, which is
  /// what [ClideContextMenu.show] needs to find one.
  Future<BuildContext> mount(WidgetTester tester) async {
    setSurfaceSize(tester, 800, height: 600);
    late BuildContext captured;
    await tester.pumpWidget(
      anchoredHarness(
        f,
        Builder(
          builder: (ctx) {
            captured = ctx;
            return const SizedBox(width: 800, height: 600);
          },
        ),
      ),
    );
    return captured;
  }

  group('ClideContextMenu', () {
    testWidgets('opens at the pointer and invokes the selected row', (tester) async {
      final ctx = await mount(tester);
      var copied = false;

      ClideContextMenu.show(
        ctx,
        globalPosition: const Offset(120, 90),
        entries: [ClideMenuItem(label: 'Copy', onSelect: () => copied = true)],
      );
      await tester.pump();

      expect(find.text('Copy'), findsOneWidget);
      // Top-left of the menu sits at the pointer, since there is room for it.
      final rect = tester.getRect(find.byType(ClideMenu));
      expect(rect.topLeft, const Offset(120, 90));

      await tester.tap(find.text('Copy'));
      await tester.pump();

      expect(copied, isTrue);
      expect(ClideContextMenu.isShown, isFalse, reason: 'selecting a row dismisses the menu');
    });

    testWidgets('flips off a bottom-right pointer to stay inside the viewport', (tester) async {
      final ctx = await mount(tester);

      ClideContextMenu.show(
        ctx,
        globalPosition: const Offset(795, 595),
        entries: [ClideMenuItem(label: 'Copy', onSelect: () {})],
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(ClideMenu));
      expect(rect.right, lessThanOrEqualTo(800), reason: 'menu must not run off the right edge');
      expect(rect.bottom, lessThanOrEqualTo(600), reason: 'menu must not run off the bottom edge');
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));

      ClideContextMenu.hide();
      await tester.pump();
    });

    testWidgets('tapping away dismisses without invoking anything', (tester) async {
      final ctx = await mount(tester);
      var copied = false;

      ClideContextMenu.show(
        ctx,
        globalPosition: const Offset(400, 300),
        entries: [ClideMenuItem(label: 'Copy', onSelect: () => copied = true)],
      );
      await tester.pump();
      expect(ClideContextMenu.isShown, isTrue);

      await tester.tapAt(const Offset(20, 20));
      await tester.pump();

      expect(ClideContextMenu.isShown, isFalse);
      expect(copied, isFalse);
    });

    testWidgets('Escape dismisses it', (tester) async {
      final ctx = await mount(tester);

      ClideContextMenu.show(
        ctx,
        globalPosition: const Offset(400, 300),
        entries: [ClideMenuItem(label: 'Copy', onSelect: () {})],
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(ClideContextMenu.isShown, isFalse);
    });

    testWidgets('arrow keys and Enter pick a row without the menu holding focus', (tester) async {
      // The menu deliberately never focuses itself, so this exercises the
      // HardwareKeyboard path that replaces focus-based navigation.
      final ctx = await mount(tester);
      final picked = <String>[];

      ClideContextMenu.show(
        ctx,
        globalPosition: const Offset(400, 300),
        entries: [
          ClideMenuItem(label: 'Cut', onSelect: () => picked.add('Cut')),
          ClideMenuItem(label: 'Copy', onSelect: () => picked.add('Copy')),
        ],
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(picked, ['Copy']);
      expect(ClideContextMenu.isShown, isFalse);
    });

    testWidgets('an empty entry list is a no-op', (tester) async {
      final ctx = await mount(tester);

      ClideContextMenu.show(ctx, globalPosition: const Offset(100, 100), entries: const []);
      await tester.pump();

      expect(ClideContextMenu.isShown, isFalse);
      expect(find.byType(ClideMenu), findsNothing);
    });
  });

  group('clideContextMenuEntries', () {
    testWidgets('labels the clipboard verbs and hints their shortcut', (tester) async {
      final ctx = await mount(tester);

      final entries = clideContextMenuEntries(ctx, [
        ContextMenuButtonItem(type: ContextMenuButtonType.copy, onPressed: () {}),
        ContextMenuButtonItem(type: ContextMenuButtonType.selectAll, onPressed: () {}),
      ]).cast<ClideMenuItem>();

      expect(entries.map((e) => e.label), ['Copy', 'Select all']);
      // The hint is rendered as a trailing widget, not baked into the label.
      expect(entries.every((e) => e.trailing != null), isTrue);
    });

    testWidgets('disables an item Flutter offered without a handler', (tester) async {
      final ctx = await mount(tester);

      // A null onPressed is how EditableTextState reports "paste, but nothing
      // on the clipboard" — the row shows, greyed, rather than disappearing.
      final entries = clideContextMenuEntries(ctx, [const ContextMenuButtonItem(type: ContextMenuButtonType.paste, onPressed: null)]).cast<ClideMenuItem>();

      expect(entries.single.label, 'Paste');
      expect(entries.single.enabled, isFalse);
    });

    testWidgets('prefers an OS-supplied label for a custom action', (tester) async {
      final ctx = await mount(tester);

      final entries = clideContextMenuEntries(ctx, [
        ContextMenuButtonItem(type: ContextMenuButtonType.custom, label: 'Translate', onPressed: () {}),
      ]).cast<ClideMenuItem>();

      expect(entries.single.label, 'Translate');
      expect(entries.single.trailing, isNull, reason: 'no shortcut hint for actions clide does not bind');
    });
  });
}
