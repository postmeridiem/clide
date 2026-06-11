import 'package:clide/builtin/ipc_status/ipc_status.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('IpcStatusExtension', () {
    late KernelFixture f;

    setUp(() async {
      f = await KernelFixture.create();
    });

    tearDown(() async => f.dispose());

    test('contributes a statusbar item', () async {
      f.services.extensions.register(IpcStatusExtension());
      await f.services.extensions.activateAll();
      final items = f.services.panels.contributionsFor(Slots.statusbar).whereType<StatusItemContribution>().toList();
      expect(items, hasLength(1));
      expect(items.first.priority, 100);
    });

    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(harness(f, const ToolStatusItem()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('unresolved toolchain renders an empty shrink', (tester) async {
      // Default fixture leaves toolchain unresolved → SizedBox.shrink branch.
      await tester.pumpWidget(harness(f, const ToolStatusItem()));
      await tester.pumpAndSettle();
      expect(find.text('application ok'), findsNothing);
    });

    testWidgets('all-tools-resolved shows a single "application ok" chip', (tester) async {
      f.services.toolchain.applyResolved(const ResolvedPaths(git: '/usr/bin/git', pql: '/usr/bin/pql', tmux: '/usr/bin/tmux', shell: '/bin/bash'));
      await tester.pumpWidget(harness(f, const ToolStatusItem()));
      await tester.pumpAndSettle();
      expect(find.text('application ok'), findsOneWidget);
    });

    testWidgets('missing tools render a warning chip per missing tool', (tester) async {
      // git + tmux missing, pql resolved.
      f.services.toolchain.applyResolved(const ResolvedPaths(pql: '/usr/bin/pql', shell: '/bin/bash'));
      await tester.pumpWidget(harness(f, const ToolStatusItem()));
      await tester.pumpAndSettle();
      expect(find.text('git not found'), findsOneWidget);
      expect(find.text('tmux not found'), findsOneWidget);
      expect(find.text('pql not found'), findsNothing);
    });

    testWidgets('StatusItemContribution.build returns a ToolStatusItem', (tester) async {
      f.services.extensions.register(IpcStatusExtension());
      await f.services.extensions.activateAll();
      final item = f.services.panels.contributionsFor(Slots.statusbar).whereType<StatusItemContribution>().first;
      // Pump a Builder so we have a real BuildContext to hand to .build.
      late Widget produced;
      await tester.pumpWidget(
        harness(
          f,
          Builder(
            builder: (ctx) {
              produced = item.build(ctx);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(produced, isA<ToolStatusItem>());
    });
  });
}
