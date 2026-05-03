import 'package:clide/builtin/ipc_status/ipc_status.dart';
import 'package:clide/builtin/ipc_status/src/status_item.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
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
  });
}
