import 'package:clide/builtin/vim/src/vim_mode_indicator.dart';
import 'package:clide/builtin/vim/src/vim_mode_service.dart';
import 'package:clide/clide.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';

/// Vim layer (T-65 epic). Owns the [VimModeService], registers the
/// mode-transition commands the `vim.yaml` preset binds to, and shows the
/// current mode in the status bar.
///
/// The layer is inert unless the active preset is `vim`: [activate] ties
/// [VimModeService.enabled] to the `app.keymap.preset` setting and
/// re-checks it whenever the keymap reloads (preset switches go through
/// `KeymapService.load`, which notifies). That keeps `i` / `v` / `Esc`
/// from hijacking input under the default / VS Code / JetBrains presets.
///
/// Mode commands carry NO `defaultBinding` — binding them globally would
/// fire under every preset. Only `vim.yaml` (guarded by `when: vim.*`)
/// binds keys to them.
class VimExtension extends ClideExtension {
  @override
  String get id => 'builtin.vim';
  @override
  String get title => 'Vim';
  @override
  String get version => '0.1.0';
  @override
  List<String> get dependsOn => const [];

  VimModeService? _mode;
  KeymapService? _keymap;
  SettingsStore? _settings;

  /// Exposed for tests/host wiring; null before [activate].
  VimModeService? get modeService => _mode;

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    final mode = VimModeService(ctx.keymap);
    _mode = mode;
    _keymap = ctx.keymap;
    _settings = ctx.settings;
    _syncEnabled();
    ctx.keymap.addListener(_syncEnabled);
  }

  /// Enable the Vim layer iff the active preset is `vim`.
  void _syncEnabled() {
    final preset = _settings?.get<String>(kKeymapPresetSetting) ?? 'default';
    _mode?.enabled = preset == 'vim';
  }

  @override
  Future<void> deactivate() async {
    _keymap?.removeListener(_syncEnabled);
    _mode?.enabled = false;
    _mode?.dispose();
    _mode = null;
  }

  @override
  List<ContributionPoint> get contributions => [
    _modeCommand('vim.mode.normal', 'Vim: Normal mode', () => _mode?.enterNormal()),
    _modeCommand('vim.mode.insert', 'Vim: Insert mode', () => _mode?.enterInsert()),
    _modeCommand('vim.mode.visual', 'Vim: Visual mode', () => _mode?.enterVisual()),
    StatusItemContribution(
      id: 'vim.mode',
      priority: -50, // left group, near the other editor status items
      listenable: _mode,
      build: (_) {
        final m = _mode;
        return m == null ? const SizedBox.shrink() : VimModeIndicator(service: m);
      },
    ),
  ];

  CommandContribution _modeCommand(String id, String title, void Function() apply) {
    return CommandContribution(
      id: id,
      command: id,
      title: title,
      titleKey: 'command.$id',
      i18nNamespace: this.id,
      run: (_) async {
        apply();
        return IpcResponse.ok(id: '', data: {'mode': _mode?.mode.name ?? 'disabled'});
      },
    );
  }
}
