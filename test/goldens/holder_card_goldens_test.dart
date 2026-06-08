import 'package:alchemist/alchemist.dart';
import 'package:clide/builtin/claude/src/conversation_card.dart';
import 'package:clide/builtin/claude/src/holder_card.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/kernel_fixture.dart';
import '../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;

  setUp(() async => f = await KernelFixture.create());
  tearDown(() async => f.dispose());

  goldenTest(
    'ClideHolderCard (T-266): collapsed ticker + expanded container of sub-cards',
    fileName: 'holder_card',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'collapsed (ticker + step count)',
          child: _wrap(
            f,
            const ClideHolderCard(
              collapsedSummary: 'Bash  ls -la',
              stepLabel: '3 steps',
              children: [],
            ),
          ),
        ),
        GoldenTestScenario(
          name: 'expanded (framed container wrapping sub-cards)',
          child: _wrap(
            f,
            const ClideHolderCard(
              collapsedSummary: 'Bash  ls -la',
              stepLabel: '3 steps',
              initiallyExpanded: true,
              children: [
                ConversationCard(
                  variant: ConversationCardVariant.bordered,
                  accent: Color(0xFF4C9AFF),
                  label: 'Bash',
                  body: Text('ls -la', textDirection: TextDirection.ltr),
                ),
                ConversationCard(
                  variant: ConversationCardVariant.bordered,
                  accent: Color(0xFF4C9AFF),
                  label: 'Read',
                  body: Text('/lib/main.dart', textDirection: TextDirection.ltr),
                ),
              ],
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
