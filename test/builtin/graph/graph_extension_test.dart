/// GraphExtension (T-323) contributes the vault-graph tab into the context
/// panel — but only once its pql dependency is active (it reads link data
/// through pql).
library;

import 'package:clide/builtin/graph/graph.dart';
import 'package:clide/builtin/graph/src/graph_panel.dart';
import 'package:clide/builtin/pql/pql.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  test('declares one context-panel tab with the graph.view identity', () {
    final tabs = GraphExtension().contributions.whereType<TabContribution>().toList();
    expect(tabs, hasLength(1));
    final t = tabs.single;
    expect(t.id, 'graph.view');
    expect(t.slot, Slots.contextPanel);
    expect(t.title, 'Graph');
    expect(t.titleKey, 'tab.graph.title');
    expect(t.i18nNamespace, 'builtin.graph');
  });

  testWidgets('the tab builds a GraphPanel', (tester) async {
    final tab = GraphExtension().contributions.whereType<TabContribution>().single;
    late Widget built;
    await tester.pumpWidget(
      anchoredHarness(
        f,
        Builder(
          builder: (ctx) {
            built = tab.build(ctx); // capture without mounting — no load/ipc needed
            return const SizedBox();
          },
        ),
      ),
    );
    expect(built, isA<GraphPanel>());
  });

  test('registers into the context panel once activated (after its pql dep)', () async {
    f.services.extensions.register(PqlExtension());
    f.services.extensions.register(GraphExtension());
    await f.services.extensions.activate('builtin.pql');
    await f.services.extensions.activate('builtin.graph');
    expect(f.services.panels.tabsFor(Slots.contextPanel).any((t) => t.id == 'graph.view'), isTrue);
  });

  test('is skipped when its pql dependency is not active', () async {
    f.services.extensions.register(GraphExtension());
    await f.services.extensions.activate('builtin.graph'); // dep missing → skipped
    expect(f.services.panels.tabsFor(Slots.contextPanel).any((t) => t.id == 'graph.view'), isFalse);
  });
}
