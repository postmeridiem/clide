import 'package:alchemist/alchemist.dart';
import 'package:clide/builtin/claude/src/conversation_card.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/kernel_fixture.dart';
import '../helpers/widget_harness.dart';

/// Visualises the T-305 single-tool rendering: every tool use is a collapser
/// over a one-item list. Collapsed → ticker (label + echoed line + 1 step +
/// status). Expanded → the inner content card (body + folded result + its own
/// per-item mark; the collapser carries the aggregate).
void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() async => f.dispose());

  Widget bashContent() => const ConversationCard(
        variant: ConversationCardVariant.bordered,
        accent: Color(0xFF4C9AFF),
        label: 'Bash',
        status: ConversationCardStatus.success,
        body: Text('npm test', style: TextStyle(fontSize: 12, color: Color(0xFF9DA5B4)), textDirection: TextDirection.ltr),
        extraSegments: [
          CardSegment(
              label: 'result', child: Text('All 42 tests passed', style: TextStyle(fontSize: 12, color: Color(0xFF9DA5B4)), textDirection: TextDirection.ltr)),
        ],
      );

  goldenTest(
    'single tool collapser (T-305): collapsed ticker + expanded inner card',
    fileName: 'tool_collapser',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'collapsed — Bash, 1 step',
          child: SizedBox(
            width: 420,
            child: harness(
              f,
              ClideCollapserCard(
                label: 'Bash',
                color: const Color(0xFF4C9AFF),
                collapsedSummary: 'npm test',
                counter: '1 step',
                status: ClideRunStatus.success,
                children: [bashContent()],
              ),
            ),
          ),
        ),
        GoldenTestScenario(
          name: 'expanded — inner content card',
          child: SizedBox(
            width: 420,
            child: harness(
              f,
              ClideCollapserCard(
                label: 'Bash',
                color: const Color(0xFF4C9AFF),
                counter: '1 step',
                status: ClideRunStatus.success,
                initiallyExpanded: true,
                children: [bashContent()],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
