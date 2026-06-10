import 'package:alchemist/alchemist.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/kernel_fixture.dart';
import '../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;

  setUp(() async => f = await KernelFixture.create());
  tearDown(() async => f.dispose());

  // A stand-in inner item card: content + its own per-item status mark (the
  // collapser carries the aggregate; items keep their own — T-305).
  Widget item(String label, ClideRunStatus status) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF393E48)),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6A7280)), textDirection: TextDirection.ltr)),
                ClideStatusIndicator(status: status, size: 12),
              ],
            ),
          ),
        ),
      );

  goldenTest(
    'ClideCollapserCard (T-305): collapsed color variants + expanded inner canvas',
    fileName: 'collapser_card',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'collapsed — default (muted)',
          child: _wrap(
              f,
              const ClideCollapserCard(
                  label: 'Activity',
                  collapsedSummary: 'Read  conversation_view.dart',
                  counter: '3 steps',
                  status: ClideRunStatus.success,
                  children: [SizedBox.shrink()])),
        ),
        GoldenTestScenario(
          name: 'collapsed — edits (teal color)',
          child: _wrap(
              f,
              const ClideCollapserCard(
                  label: 'Edits',
                  color: Color(0xFF00AB9A),
                  collapsedSummary: 'clide_markdown.dart',
                  counter: '7 edits',
                  status: ClideRunStatus.success,
                  children: [SizedBox.shrink()])),
        ),
        GoldenTestScenario(
          name: 'collapsed — error (red color)',
          child: _wrap(
              f,
              const ClideCollapserCard(
                  label: 'Bash',
                  color: Color(0xFFF06C6F),
                  collapsedSummary: 'npm test',
                  counter: '1 step',
                  status: ClideRunStatus.error,
                  children: [SizedBox.shrink()])),
        ),
        GoldenTestScenario(
          name: 'expanded — inner canvas of item cards',
          child: _wrap(
            f,
            ClideCollapserCard(
              label: 'Edits',
              color: const Color(0xFF00AB9A),
              counter: '3 edits',
              status: ClideRunStatus.success,
              initiallyExpanded: true,
              children: [
                item('clide_markdown.dart · _urlLinkSpan', ClideRunStatus.success),
                item('clide_markdown.dart · _isHttpUrl', ClideRunStatus.success),
                item('clide_markdown.dart · build()', ClideRunStatus.success),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _wrap(KernelFixture f, Widget child) => SizedBox(width: 380, child: harness(f, child));
