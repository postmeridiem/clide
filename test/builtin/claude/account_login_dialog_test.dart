/// T-485: the account login dialog hosts `claude login` in a terminal pane with
/// the account's CLAUDE_CONFIG_DIR, and its close affordance dismisses. The CLI
/// owns the OAuth flow; this verifies the host wiring (title, env, close).
library;

import 'package:clide/builtin/claude/src/account_login_dialog.dart';
import 'package:clide/builtin/terminal/src/terminal_pane.dart';
import 'package:clide/clide.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture fixture;
  setUp(() async => fixture = await KernelFixture.create());
  tearDown(() async => fixture.dispose());

  testWidgets('renders the account title, spawns claude login with the config dir, and closes', (tester) async {
    var closed = false;
    Map<String, Object?>? spawnArgs;
    fixture.ipc.setConnected(true);
    fixture.ipc.stub('pane.spawn', (args) async {
      spawnArgs = args;
      return IpcResponse.ok(id: 'r1', data: {'id': 'p1', 'pid': 1});
    });
    fixture.ipc.stub('pane.close', (args) async => IpcResponse.ok(id: 'r2'));

    await tester.pumpWidget(harness(fixture, ClaudeLoginDialog(name: 'work', dir: '/home/u/.claude-work', onClose: () => closed = true)));
    await pumpAsync(tester);

    expect(find.text('Sign in: work'), findsOneWidget);
    final pane = tester.widget<TerminalPane>(find.byType(TerminalPane));
    expect(pane.argv, ['claude', 'login']);
    expect(pane.env, {'CLAUDE_CONFIG_DIR': '/home/u/.claude-work'});
    expect(spawnArgs?['env'], {'CLAUDE_CONFIG_DIR': '/home/u/.claude-work'});

    await tester.tap(find.byKey(const Key('account-login-close')));
    await tester.pump();
    expect(closed, isTrue);
  });

  testWidgets('escape closes the dialog', (tester) async {
    var closed = false;
    fixture.ipc.setConnected(true);
    fixture.ipc.stub('pane.spawn', (args) async => IpcResponse.ok(id: 'r1', data: {'id': 'p1', 'pid': 1}));
    fixture.ipc.stub('pane.close', (args) async => IpcResponse.ok(id: 'r2'));

    await tester.pumpWidget(harness(fixture, ClaudeLoginDialog(name: 'work', dir: '/home/u/.claude-work', onClose: () => closed = true)));
    await pumpAsync(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(closed, isTrue);
  });
}
