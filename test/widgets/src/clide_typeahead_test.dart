/// Tests for ClideTypeahead (D-88): suggestion-driven anchored list that keeps
/// focus on the field, selects on tap, and hides when suggestions go empty.
library;

import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart' show Alignment, SizedBox, StateSetter, StatefulBuilder;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('ClideTypeahead', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    testWidgets('shows suggestions, selecting fires onSelect, empty hides', (tester) async {
      var picked = '';
      List<String> sugg = ['alice', 'bob'];
      late StateSetter setOuter;
      await tester.pumpWidget(anchoredHarness(
        f,
        StatefulBuilder(
          builder: (ctx, setState) {
            setOuter = setState;
            return ClideTypeahead(
              suggestions: sugg,
              onSelect: (v) => picked = v,
              formatLabel: (n) => '@$n',
              child: const SizedBox(width: 200, height: 24, child: ClideText('field')),
            );
          },
        ),
        alignment: Alignment.topLeft,
      ));
      await tester.pumpAndSettle();
      expect(find.text('@alice'), findsOneWidget);
      expect(find.text('@bob'), findsOneWidget);

      await tester.tap(find.text('@bob'));
      await tester.pumpAndSettle();
      expect(picked, 'bob');

      // Host clears suggestions → popover hides.
      setOuter(() => sugg = const []);
      await tester.pumpAndSettle();
      expect(find.text('@alice'), findsNothing);
    });
  });
}
