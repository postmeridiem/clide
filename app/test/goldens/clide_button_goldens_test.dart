import 'package:alchemist/alchemist.dart';
import 'package:clide_app/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/kernel_fixture.dart';
import '../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;

  setUp(() async => f = await KernelFixture.create());
  tearDown(() async => f.dispose());

  goldenTest(
    'ClideButton variants + states',
    fileName: 'clide_button',
    pumpBeforeTest: (tester) async {
      // wait for hover/press state to settle
      await tester.pump(const Duration(milliseconds: 50));
    },
    builder: () => GoldenTestGroup(
      columns: 3,
      children: [
        GoldenTestScenario(
          name: 'normal / enabled',
          child: _wrap(f, ClideButton(label: 'Save', onPressed: () {})),
        ),
        GoldenTestScenario(
          name: 'normal / disabled',
          child: _wrap(f, const ClideButton(label: 'Save', onPressed: null)),
        ),
        GoldenTestScenario(
          name: 'primary / enabled',
          child: _wrap(
            f,
            ClideButton(
              label: 'Commit',
              onPressed: () {},
              variant: ClideButtonVariant.primary,
            ),
          ),
        ),
        GoldenTestScenario(
          name: 'primary / disabled',
          child: _wrap(
            f,
            const ClideButton(
              label: 'Commit',
              onPressed: null,
              variant: ClideButtonVariant.primary,
            ),
          ),
        ),
        GoldenTestScenario(
          name: 'subtle / enabled',
          child: _wrap(
            f,
            ClideButton(
              label: 'Open',
              onPressed: () {},
              variant: ClideButtonVariant.subtle,
            ),
          ),
        ),
        GoldenTestScenario(
          name: 'subtle / disabled',
          child: _wrap(
            f,
            const ClideButton(
              label: 'Open',
              onPressed: null,
              variant: ClideButtonVariant.subtle,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _wrap(KernelFixture f, Widget child) => SizedBox(
      width: 140,
      child: harness(f, child),
    );
