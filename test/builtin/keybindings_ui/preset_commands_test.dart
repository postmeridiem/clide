/// T-65: the keybindings UI contributes palette commands that switch the
/// active keymap preset.
library;

import 'package:clide/builtin/keybindings_ui/keybindings_ui.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  late KernelFixture f;
  setUp(() async {
    f = await KernelFixture.create();
    f.services.extensions.register(KeybindingsUiExtension());
    await f.services.extensions.activate('builtin.keybindings-ui');
  });
  tearDown(() => f.dispose());

  test('identifies itself', () {
    final ext = KeybindingsUiExtension();
    expect(ext.id, 'builtin.keybindings-ui');
    expect(ext.title, 'Keybindings UI');
    expect(ext.version, '0.1.0');
  });

  test('deactivate drops the keymap reference', () async {
    await f.services.extensions.deactivate('builtin.keybindings-ui');
    // Re-activating is clean (no retained state).
    await f.services.extensions.activate('builtin.keybindings-ui');
    expect(f.services.commands.get('keymap.preset.vim'), isNotNull);
  });

  test('contributes a switch command per shipped preset', () {
    expect(f.services.commands.get('keymap.preset.vim'), isNotNull);
    expect(f.services.commands.get('keymap.preset.default'), isNotNull);
  });

  test('running the vim command switches the active preset', () async {
    await f.services.commands.execute('keymap.preset.vim');
    expect(f.services.settings.get<String>(kKeymapPresetSetting), 'vim');
  });

  test('switching back to default works', () async {
    await f.services.commands.execute('keymap.preset.vim');
    await f.services.commands.execute('keymap.preset.default');
    expect(f.services.settings.get<String>(kKeymapPresetSetting), 'default');
  });

  test('contributes a Keymap settings category routed through the preset commands (T-451)', () {
    final category = KeybindingsUiExtension().contributions.whereType<SettingsCategoryContribution>().firstWhere((c) => c.id == 'keymap').category;
    expect(category.title, 'Keymap');
    final field = category.sections.expand((s) => s.fields).firstWhere((f) => f.key == kKeymapPresetSetting);
    expect(field.kind, SettingsFieldKind.select);
    expect(field.applyCommandPrefix, 'keymap.preset.');
    expect(field.options.map((o) => o.value), containsAll(['default', 'vim', 'vscode', 'jetbrains']));
  });
}
