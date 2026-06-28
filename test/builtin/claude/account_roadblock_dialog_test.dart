/// T-488: the new-project account roadblock dialog renders the project title,
/// hosts the per-workspace picker + the accounts list (both already tested on
/// their own), and dismisses on Continue / Escape.
library;

import 'package:clide/builtin/claude/src/account_registry.dart';
import 'package:clide/builtin/claude/src/account_roadblock_dialog.dart';
import 'package:clide/builtin/claude/src/account_settings_control.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() async => f.dispose());

  Future<void> pump(WidgetTester tester, {required VoidCallback onClose}) async {
    await tester.runAsync(() async {
      await f.services.settings.setProjectDir(f.tempDir);
      await AccountRegistry(f.services.settings).registerAccount('work', '/home/u/.claude-work');
    });
    await tester.pumpWidget(
      harness(
        f,
        Align(
          alignment: Alignment.center,
          child: ClaudeAccountRoadblockDialog(projectName: 'myapp', onClose: onClose),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the title + both account controls; Continue dismisses', (tester) async {
    var closed = false;
    await pump(tester, onClose: () => closed = true);
    expect(find.text('Claude account for myapp'), findsOneWidget);
    expect(find.byType(ClaudeWorkspaceAccountControl), findsOneWidget);
    expect(find.byType(ClaudeAccountsListControl), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(closed, isTrue);
  });

  testWidgets('Escape dismisses', (tester) async {
    var closed = false;
    await pump(tester, onClose: () => closed = true);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(closed, isTrue);
  });
}
