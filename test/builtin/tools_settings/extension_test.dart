/// T-495: ToolsSettingsExtension contributes the Tools settings category and
/// the tools.detect command, and keeps the live resolver in sync with edits.
library;

import 'package:clide/builtin/tools_settings/tools_settings.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/src/env/supporter_binaries.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  late KernelFixture f;
  SupporterBinaries? saved;

  setUp(() async {
    saved = activeSupporterBinaries;
    f = await KernelFixture.create();
    f.services.extensions.register(ToolsSettingsExtension());
    await f.services.extensions.activate('builtin.tools-settings');
  });
  tearDown(() {
    activeSupporterBinaries = saved; // un-pollute the process-wide resolver
    f.dispose();
  });

  test('contributes the Tools settings category and the tools.detect command', () {
    final ext = ToolsSettingsExtension();
    final cats = ext.contributions.whereType<SettingsCategoryContribution>();
    expect(cats.any((c) => c.category.id == 'tools'), isTrue);
    expect(f.services.commands.get('tools.detect'), isNotNull);
  });

  test('editing a tool path in settings rebuilds the live resolver', () async {
    await f.services.settings.set<String>(supporterToolKey('d2'), '/custom/d2');
    // The listener rebuilt activeSupporterBinaries from the keys; /custom/d2
    // isn't a real file, so it reads as a stale pin — proving the edit took.
    expect(activeSupporterBinaries?.isStalePin('d2'), isTrue);
  });

  test('tools.detect runs, marks first-run done, and refreshes the resolver', () async {
    final r = await f.services.commands.execute('tools.detect');
    expect(r.ok, isTrue);
    expect(f.services.settings.get<bool>('app.tools.detected'), isTrue);
    expect(activeSupporterBinaries, isNotNull);
  });
}
