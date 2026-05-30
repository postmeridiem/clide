/// Widget tests for the teammate tile grid (T-140): tiles appear on
/// TeamMemberJoined, disappear on TeamMemberLeft, and the lead shows
/// alone when there's no team. Events are emitted directly into the
/// fixture's event bus (team membership is orchestrator-driven since
/// D-77 / T-167 — the tmux observer was retired).
library;

import 'package:clide/builtin/claude/src/conversation_view.dart';
import 'package:clide/builtin/claude/src/team_panel_host.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

Widget _lead() => const Center(child: Text('LEAD', textDirection: TextDirection.ltr));

TeamMemberJoined _joined(String name, String pane, {String? color}) => TeamMemberJoined(
      team: 'myteam',
      agentId: '$name@myteam',
      name: name,
      agentType: 'researcher',
      paneId: pane,
      model: 'sonnet',
      color: color,
    );

void main() {
  late KernelFixture f;

  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  Future<void> pumpHost(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(harness(f, TeamPanelHost(lead: _lead())));
  }

  Future<void> emit(WidgetTester tester, ClideEvent e) async {
    f.services.events.emit(e);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('lead shows alone with no team', (tester) async {
    await pumpHost(tester);
    expect(find.text('LEAD'), findsOneWidget);
    expect(find.byType(ConversationView), findsNothing);
  });

  testWidgets('a teammate joining adds a tile; leaving removes it', (tester) async {
    await pumpHost(tester);

    await emit(tester, _joined('alice', '%5', color: 'blue'));
    expect(find.text('alice'), findsOneWidget);
    expect(find.byType(ConversationView), findsOneWidget);
    expect(find.text('LEAD'), findsOneWidget); // lead still present beside the grid

    await emit(tester, const TeamMemberLeft(team: 'myteam', agentId: 'alice@myteam', paneId: '%5'));
    expect(find.text('alice'), findsNothing);
    expect(find.byType(ConversationView), findsNothing);
    expect(find.text('LEAD'), findsOneWidget); // back to lead-only
  });

  testWidgets('duplicate join is ignored', (tester) async {
    await pumpHost(tester);
    await emit(tester, _joined('alice', '%5'));
    await emit(tester, _joined('alice', '%5'));
    expect(find.text('alice'), findsOneWidget);
  });

  testWidgets('renders a tile per member as the team grows', (tester) async {
    await pumpHost(tester);
    await emit(tester, _joined('alice', '%5'));
    await emit(tester, _joined('bob', '%6'));
    await emit(tester, _joined('carol', '%7'));
    await emit(tester, _joined('dave', '%8'));
    for (final name in ['alice', 'bob', 'carol', 'dave']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.byType(ConversationView), findsNWidgets(4));
  });

  group('teamColor', () {
    test('maps known names and falls back', () {
      const fallback = Color(0xFF000000);
      expect(teamColor('blue', fallback: fallback), const Color(0xFF61AFEF));
      expect(teamColor('orange', fallback: fallback), const Color(0xFFD97757));
      expect(teamColor('purple', fallback: fallback), teamColor('magenta', fallback: fallback));
      expect(teamColor(null, fallback: fallback), fallback);
      expect(teamColor('chartreuse', fallback: fallback), fallback);
    });
  });
}
