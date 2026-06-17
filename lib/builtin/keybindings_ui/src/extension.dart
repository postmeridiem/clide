import 'package:clide/clide.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';

/// Keymap preset switching. The full keybindings editor lands in a later
/// tier; today this contributes palette commands to switch the active
/// keymap preset (the user-facing "select it in settings" affordance for
/// the Vim / VS Code / JetBrains presets — T-64/65/66).
class KeybindingsUiExtension extends ClideExtension {
  @override
  String get id => 'builtin.keybindings-ui';
  @override
  String get title => 'Keybindings UI';
  @override
  String get version => '0.1.0';
  @override
  List<String> get dependsOn => const [];

  KeymapService? _keymap;

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _keymap = ctx.keymap;
  }

  @override
  Future<void> deactivate() async => _keymap = null;

  /// Presets that ship today, each exposed as a `keymap.preset.<name>`
  /// command that activates it.
  static const _presets = <String, String>{'default': 'Keymap: Default', 'vim': 'Keymap: Vim', 'vscode': 'Keymap: VS Code', 'jetbrains': 'Keymap: JetBrains'};

  @override
  List<ContributionPoint> get contributions => [
    for (final entry in _presets.entries)
      CommandContribution(
        id: 'keymap.preset.${entry.key}',
        command: 'keymap.preset.${entry.key}',
        title: entry.value,
        run: (_) async {
          await _keymap?.setPreset(entry.key);
          return IpcResponse.ok(id: '', data: {'preset': entry.key});
        },
      ),
    // Keymap settings category (T-451). The select reads the active preset
    // from kKeymapPresetSetting; picking one runs `keymap.preset.<value>`
    // (applyCommandPrefix), which calls KeymapService.setPreset — persisting
    // and reloading the layered keymap live.
    const SettingsCategoryContribution(
      id: 'keymap',
      category: SettingsCategory(
        id: 'keymap',
        title: 'Keymap',
        iconName: 'keyboard',
        priority: 20,
        sections: [
          SettingsSection(
            label: 'Preset',
            fields: [
              SettingsField(
                key: kKeymapPresetSetting,
                kind: SettingsFieldKind.select,
                label: 'Active preset',
                help: 'Keyboard layout for the whole app.',
                defaultValue: 'default',
                applyCommandPrefix: 'keymap.preset.',
                options: [
                  SettingsOption(value: 'default', label: 'Default'),
                  SettingsOption(value: 'vim', label: 'Vim'),
                  SettingsOption(value: 'vscode', label: 'VS Code'),
                  SettingsOption(value: 'jetbrains', label: 'JetBrains'),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  ];
}
