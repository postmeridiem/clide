/// T-54: OutputExtension wires the dock tab, the status toggle, and the
/// dock.toggle command (D-87).
library;

import 'package:clide/builtin/default_layout/default_layout.dart';
import 'package:clide/builtin/output/output.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  late KernelFixture f;

  setUp(() async {
    f = await KernelFixture.create();
    f.services.extensions
      ..register(DefaultLayoutExtension())
      ..register(OutputExtension());
    await f.services.extensions.activate('builtin.default-layout');
    await f.services.extensions.activate('builtin.output');
  });
  tearDown(() => f.dispose());

  test('contributes the Output dock tab, a status item, and dock.toggle', () {
    final ext = OutputExtension();
    final tabs = ext.contributions.whereType<TabContribution>();
    expect(tabs.any((t) => t.id == 'output.panel' && t.slot == Slots.dock), isTrue);
    expect(ext.contributions.whereType<StatusItemContribution>(), isNotEmpty);
    expect(f.services.commands.get('dock.toggle'), isNotNull);
  });

  test('dock.toggle opens the dock + activates Output, then closes it', () async {
    expect(f.services.arrangement.isVisible(Slots.dock), isFalse);
    await f.services.commands.execute('dock.toggle');
    expect(f.services.arrangement.isVisible(Slots.dock), isTrue);
    expect(f.services.panels.activeTabIn(Slots.dock), 'output.panel');
    await f.services.commands.execute('dock.toggle');
    expect(f.services.arrangement.isVisible(Slots.dock), isFalse);
  });
}
