import 'package:alchemist/alchemist.dart';
import 'package:clide/builtin/claude/src/conversation_card.dart';
import 'package:clide/builtin/claude/src/conversation_view.dart' show claudeAccent;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/kernel_fixture.dart';
import '../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;

  setUp(() async => f = await KernelFixture.create());
  tearDown(() async => f.dispose());

  goldenTest(
    'ConversationCard attribution (T-265): agent prose is muted, claude prose is coral',
    fileName: 'conversation_card_attribution',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'claude (main thread) — coral brand stripe',
          child: _wrap(
            f,
            const ConversationCard(
              accent: claudeAccent,
              label: 'claude',
              body: Text('Here is the main-thread answer.', textDirection: TextDirection.ltr),
            ),
          ),
        ),
        GoldenTestScenario(
          name: 'agent (sidechain) — muted stripe, not coral',
          child: _wrap(
            f,
            ConversationCard(
              accent: const Color(0xFF8B8B8B),
              label: 'agent',
              body: const Text('Here is the sub-agent answer.', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      ],
    ),
  );

  goldenTest(
    'ConversationCard merged tool card (T-262): status mark + folded result segment',
    fileName: 'conversation_card_merged',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'success / collapsed (check + summary)',
          child: _wrap(
            f,
            const ConversationCard(
              variant: ConversationCardVariant.bordered,
              accent: Color(0xFF4C9AFF),
              label: 'Read',
              status: ConversationCardStatus.success,
              collapsible: true,
              collapsedByDefault: true,
              collapsedSummary: '/lib/main.dart',
              body: Text('/lib/main.dart', textDirection: TextDirection.ltr),
              extraSegments: [CardSegment(label: 'result', child: Text('void main() {}', textDirection: TextDirection.ltr))],
            ),
          ),
        ),
        GoldenTestScenario(
          name: 'success / expanded (call → result segment)',
          child: _wrap(
            f,
            const ConversationCard(
              variant: ConversationCardVariant.bordered,
              accent: Color(0xFF4C9AFF),
              label: 'Read',
              status: ConversationCardStatus.success,
              collapsible: true,
              collapsedByDefault: false,
              body: Text('/lib/main.dart', textDirection: TextDirection.ltr),
              extraSegments: [CardSegment(label: 'result', child: Text('void main() {}', textDirection: TextDirection.ltr))],
            ),
          ),
        ),
        GoldenTestScenario(
          name: 'agent / expanded (call → prompt → result layering, T-263)',
          child: _wrap(
            f,
            const ConversationCard(
              variant: ConversationCardVariant.bordered,
              accent: Color(0xFF4C9AFF),
              label: 'Task',
              status: ConversationCardStatus.success,
              collapsible: true,
              collapsedByDefault: false,
              body: Text('{ "description": "explore the codebase" }', textDirection: TextDirection.ltr),
              extraSegments: [
                CardSegment(label: 'prompt', child: Text('find all the widgets and summarise', textDirection: TextDirection.ltr)),
                CardSegment(label: 'result', child: Text('found 42 widgets', textDirection: TextDirection.ltr)),
              ],
            ),
          ),
        ),
        GoldenTestScenario(
          name: 'error / header mark (call card stays separate from the red result card)',
          child: _wrap(
            f,
            const ConversationCard(
              variant: ConversationCardVariant.bordered,
              accent: Color(0xFF4C9AFF),
              label: 'Bash',
              status: ConversationCardStatus.error,
              collapsible: true,
              collapsedByDefault: true,
              collapsedSummary: 'cat nonexistent',
              body: Text('cat nonexistent', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      ],
    ),
  );

  goldenTest(
    'ConversationCard meta cards (T-306): context / thinking are framed + muted',
    fileName: 'conversation_card_meta',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'context — framed, muted, collapsed with first-line summary',
          child: _wrap(
            f,
            const ConversationCard(
              variant: ConversationCardVariant.bordered,
              accent: Color(0xFF6A7280),
              label: 'context',
              collapsible: true,
              collapsedByDefault: true,
              collapsedSummary: 'Base directory for this skill: /var/mnt/…',
              body: Text('Base directory for this skill: /var/mnt/data/projects/clide', textDirection: TextDirection.ltr),
            ),
          ),
        ),
        GoldenTestScenario(
          name: 'thinking — framed, muted, collapsed with first-line summary',
          child: _wrap(
            f,
            const ConversationCard(
              variant: ConversationCardVariant.bordered,
              accent: Color(0xFF6A7280),
              label: 'thinking',
              collapsible: true,
              collapsedByDefault: true,
              collapsedSummary: 'Let me check the layout chain first…',
              body: Text('Let me check the layout chain first…', textDirection: TextDirection.ltr),
            ),
          ),
        ),
        GoldenTestScenario(
          name: 'context — expanded body',
          child: _wrap(
            f,
            const ConversationCard(
              variant: ConversationCardVariant.bordered,
              accent: Color(0xFF6A7280),
              label: 'context',
              collapsible: true,
              collapsedByDefault: false,
              body: Text('Base directory for this skill: /var/mnt/data/projects/clide', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _wrap(KernelFixture f, Widget child) => SizedBox(
      width: 360,
      child: harness(f, child),
    );
