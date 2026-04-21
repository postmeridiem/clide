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
    'ClideIcon painter set',
    fileName: 'clide_icon',
    builder: () => GoldenTestGroup(
      columns: 4,
      children: [
        for (final pair in const [
          ('folder', FolderIcon()),
          ('gear', GearIcon()),
          ('close', CloseIcon()),
          ('chevron-right', ChevronRightIcon()),
          ('chevron-down', ChevronDownIcon()),
          ('dot', DotIcon()),
          ('check', CheckIcon()),
          ('plug', PlugIcon()),
        ])
          GoldenTestScenario(
            name: pair.$1,
            child: harness(
              f,
              SizedBox(
                width: 24,
                height: 24,
                child: ClideIcon(pair.$2, size: 24),
              ),
            ),
          ),
      ],
    ),
  );
}
