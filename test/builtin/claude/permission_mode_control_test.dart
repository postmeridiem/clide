/// Tests for the composer permission-mode control (T-275): opens a menu of the
/// safe trio + a shift-click-gated bypass row (T-510), selecting sets the
/// mode, and it coexists with the composer's Stop row while busy.
library;

import 'package:clide/builtin/claude/src/claude_composer.dart';
import 'package:clide/builtin/claude/src/permission_mode_control.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('PermissionModeControl', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    Future<void> pump(WidgetTester tester, String mode, ValueChanged<String> onSelect) {
      return tester.pumpWidget(
        harness(
          f,
          Align(
            alignment: Alignment.center,
            child: PermissionModeControl(mode: mode, onSelect: onSelect),
          ),
        ),
      );
    }

    testWidgets('opens a menu of the safe trio + a bypass row; selecting sets the mode', (tester) async {
      var picked = '';
      await pump(tester, 'default', (m) => picked = m);
      await tester.pump();
      expect(find.text('accept-edits'), findsNothing, reason: 'menu starts closed');

      await tester.tap(find.byType(PermissionModeControl));
      await tester.pump();
      expect(find.text('default'), findsOneWidget);
      expect(find.text('accept-edits'), findsOneWidget);
      expect(find.text('plan'), findsOneWidget);
      expect(find.text('bypass'), findsOneWidget);

      await tester.tap(find.text('plan'));
      await tester.pump();
      expect(picked, 'plan');
      expect(find.text('accept-edits'), findsNothing, reason: 'menu closes on select');
    });

    testWidgets('a plain click on the bypass row does nothing and keeps the menu open', (tester) async {
      var picked = '';
      await pump(tester, 'default', (m) => picked = m);
      await tester.pump();
      await tester.tap(find.byType(PermissionModeControl));
      await tester.pump();
      await tester.tap(find.text('bypass'));
      await tester.pump();
      expect(picked, '', reason: 'bypass is never a plain click away (T-510)');
      expect(find.text('bypass'), findsOneWidget, reason: 'menu stays open for a retry with shift');
    });

    testWidgets('shift-click on the bypass row selects it and closes the menu (T-510)', (tester) async {
      var picked = '';
      await pump(tester, 'default', (m) => picked = m);
      await tester.pump();
      await tester.tap(find.byType(PermissionModeControl));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.text('bypass'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(picked, 'bypassPermissions');
      expect(find.text('bypass'), findsNothing, reason: 'menu closes after the shift-select');
    });

    testWidgets('per-mode helpers map labels/colours/icons', (tester) async {
      final tokens = f.services.theme.current.surface;
      expect(permissionModeColor('acceptEdits', tokens), tokens.statusWarning);
      expect(permissionModeColor('plan', tokens), tokens.globalFocus);
      expect(permissionModeColor('bypassPermissions', tokens), tokens.statusError);
      expect(permissionModeColor('default', tokens), tokens.globalTextMuted);
      expect(permissionModeIcon('default'), isNot(equals(permissionModeIcon('plan'))));
    });
  });

  group('ClaudeComposer + mode control', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    testWidgets('the mode control and the Stop row coexist while busy', (tester) async {
      await tester.pumpWidget(
        harness(f, ClaudeComposer(onSubmit: (_) {}, busy: true, onInterrupt: () {}, permissionMode: 'default', onSetPermissionMode: (_) {})),
      );
      await tester.pump();
      // Stop affordance (busy row) and the trailing mode control are both present.
      expect(find.textContaining('Stop'), findsOneWidget);
      expect(find.byType(PermissionModeControl), findsOneWidget);
    });

    testWidgets('no mode control when permissionMode is null', (tester) async {
      await tester.pumpWidget(harness(f, ClaudeComposer(onSubmit: (_) {})));
      await tester.pump();
      expect(find.byType(PermissionModeControl), findsNothing);
    });
  });
}
