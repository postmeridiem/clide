/// T-158: the Team tab carries the shared account budget — a single ACCOUNT
/// card from the forwarded `/usage`, NOT a per-member split (usage is
/// per-account: every team session shares one ~/.claude login).
library;

import 'package:clide/builtin/claude/src/claude_status.dart' show ClaudeUsage;
import 'package:clide/builtin/claude/src/meta_sidebar/team_tab.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  late TextEditingController inject;

  setUp(() async {
    f = await KernelFixture.create();
    inject = TextEditingController();
  });
  tearDown(() {
    inject.dispose();
    f.dispose();
  });

  // No team members + no catalog seeded, so labels fall back to their English
  // placeholders ('ACCOUNT' is the uppercased section header).
  TeamTabView view({ClaudeUsage? usage}) => TeamTabView(
    members: const [],
    memberStatus: const {},
    orchestrator: null,
    tasks: const [],
    injectingAgentId: null,
    injectController: inject,
    onToggleInject: (_) {},
    onInjectSubmit: (_, _) {},
    onClose: (_) {},
    onSetPermissionMode: (_, _) {},
    onFork: (_) {},
    onOpenChatPane: () {},
    usage: usage,
  );

  testWidgets('renders the shared ACCOUNT budget card when usage is present', (tester) async {
    await tester.pumpWidget(harness(f, view(usage: const ClaudeUsage(session: '15% used', week: '53% used', weekSonnet: '0% used'))));
    await tester.pump();

    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('15% used'), findsOneWidget);
    expect(find.text('53% used'), findsOneWidget);
    expect(find.text('0% used'), findsOneWidget);
    // Labelled shared, not per-member.
    expect(find.text('Shared across the team'), findsOneWidget);
    // Solo (no members) still shows the budget above the empty-team notice.
    expect(find.text('No team active.'), findsOneWidget);
  });

  testWidgets('omits the ACCOUNT card when no usage has been fetched', (tester) async {
    await tester.pumpWidget(harness(f, view()));
    await tester.pump();

    expect(find.text('ACCOUNT'), findsNothing);
    expect(find.text('Shared across the team'), findsNothing);
    expect(find.text('No team active.'), findsOneWidget);
  });

  testWidgets('omits the ACCOUNT card when the usage result is empty', (tester) async {
    await tester.pumpWidget(harness(f, view(usage: const ClaudeUsage())));
    await tester.pump();

    expect(find.text('ACCOUNT'), findsNothing);
  });
}
