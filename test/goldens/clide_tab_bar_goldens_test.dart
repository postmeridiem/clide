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

  goldenTest(
    'ClideTabBar active / inactive',
    fileName: 'clide_tab_bar',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'first tab active',
          child: SizedBox(
            width: 320,
            child: harness(
              f,
              ClideTabBar(
                items: const [
                  ClideTabItem(id: 'files', title: 'Files'),
                  ClideTabItem(id: 'git', title: 'Git'),
                  ClideTabItem(id: 'tree', title: 'Tree'),
                ],
                activeId: 'files',
                onSelect: (_) {},
              ),
            ),
          ),
        ),
        GoldenTestScenario(
          name: 'middle tab active',
          child: SizedBox(
            width: 320,
            child: harness(
              f,
              ClideTabBar(
                items: const [
                  ClideTabItem(id: 'files', title: 'Files'),
                  ClideTabItem(id: 'git', title: 'Git'),
                  ClideTabItem(id: 'tree', title: 'Tree'),
                ],
                activeId: 'git',
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
