import 'package:alchemist/alchemist.dart';
import 'package:clide/builtin/claude/src/conversation_card.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/kernel_fixture.dart';
import '../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;

  setUp(() async => f = await KernelFixture.create());
  tearDown(() async => f.dispose());

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
}

Widget _wrap(KernelFixture f, Widget child) => SizedBox(
      width: 360,
      child: harness(f, child),
    );
