/// Tests for the composer permission-mode control (T-275, T-597): the menu
/// offers exactly the modes the session can enter — auto when available,
/// bypass only when allowed, as a plain row below a divider — selecting sets
/// the mode, and it coexists with the composer's Stop row while busy.
library;

import 'package:clide/builtin/claude/src/claude_composer.dart';
import 'package:clide/builtin/claude/src/permission_mode_control.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('PermissionModeControl', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    Future<void> pump(WidgetTester tester, String mode, ValueChanged<String> onSelect, {List<String> modes = const ['default', 'acceptEdits', 'plan']}) {
      return tester.pumpWidget(
        harness(
          f,
          Align(
            alignment: Alignment.center,
            child: PermissionModeControl(mode: mode, modes: modes, onSelect: onSelect),
          ),
        ),
      );
    }

    testWidgets('opens a menu of the offered modes, with the modern labels; selecting sets the mode', (tester) async {
      var picked = '';
      await pump(tester, 'default', (m) => picked = m);
      await tester.pump();
      expect(find.text('Accept edits'), findsNothing, reason: 'menu starts closed');

      await tester.tap(find.byType(PermissionModeControl));
      await tester.pump();
      expect(find.text('Manual'), findsOneWidget);
      expect(find.text('Accept edits'), findsOneWidget);
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('Auto'), findsNothing, reason: 'not offered here');
      expect(find.text('Bypass permissions'), findsNothing, reason: 'not allowed here');

      await tester.tap(find.text('Plan'));
      await tester.pump();
      expect(picked, 'plan');
      expect(find.text('Accept edits'), findsNothing, reason: 'menu closes on select');
    });

    testWidgets('auto, when available, is an ordinary row', (tester) async {
      var picked = '';
      await pump(tester, 'default', (m) => picked = m, modes: const ['default', 'acceptEdits', 'plan', 'auto']);
      await tester.pump();
      await tester.tap(find.byType(PermissionModeControl));
      await tester.pump();
      await tester.tap(find.text('Auto'));
      await tester.pump();
      expect(picked, 'auto');
    });

    testWidgets('bypass, when allowed, is a plain click — no shift gate any more', (tester) async {
      var picked = '';
      await pump(tester, 'default', (m) => picked = m, modes: const ['default', 'acceptEdits', 'plan', 'bypassPermissions', 'auto']);
      await tester.pump();
      await tester.tap(find.byType(PermissionModeControl));
      await tester.pump();
      await tester.tap(find.text('Bypass permissions'));
      await tester.pump();
      expect(picked, 'bypassPermissions');
      expect(find.text('Bypass permissions'), findsNothing, reason: 'menu closes on select');
    });

    testWidgets('per-mode helpers map colours and icons', (tester) async {
      final tokens = f.services.theme.current.surface;
      expect(permissionModeColor('acceptEdits', tokens), tokens.statusWarning);
      expect(permissionModeColor('plan', tokens), tokens.globalFocus);
      expect(permissionModeColor('auto', tokens), tokens.statusSuccess);
      expect(permissionModeColor('bypassPermissions', tokens), tokens.statusError);
      expect(permissionModeColor('default', tokens), tokens.globalTextMuted);
      expect(permissionModeIcon('default'), isNot(equals(permissionModeIcon('plan'))));
      expect(permissionModeIcon('auto'), isNot(equals(permissionModeIcon('default'))));
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
