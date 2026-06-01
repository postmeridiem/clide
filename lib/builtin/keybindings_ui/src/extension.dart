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

  /// Presets that ship today. VS Code / JetBrains (T-64/T-66) join here
  /// once their YAMLs land.
  static const _presets = <String, String>{
    'default': 'Keymap: Default',
    'vim': 'Keymap: Vim',
  };

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
      ];
}
