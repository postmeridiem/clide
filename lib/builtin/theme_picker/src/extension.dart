import 'package:clide/clide.dart';
import 'package:clide/builtin/theme_picker/src/appearance_control.dart';
import 'package:clide/builtin/theme_picker/src/settings_view.dart';
import 'package:clide/builtin/theme_picker/src/theme_status_item.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart' show kMonoFontSettingKey, kUiFontSettingKey;

class ThemePickerExtension extends ClideExtension {
  @override
  String get id => 'builtin.theme-picker';
  @override
  String get title => 'Theme picker';
  @override
  String get version => '0.1.0';

  ClideExtensionContext? _ctx;

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _ctx = ctx;
  }

  @override
  List<ContributionPoint> get contributions => [
    // Opens the theme picker modal (T-238). Command id kept as `theme.pick`
    // (the welcome theme-link and other callers reference it). Titled
    // "Theme…" to disambiguate from the schema-driven Settings panel's
    // `settings.open` (T-444); the theme picker folds into that panel's
    // Appearance category in T-452.
    CommandContribution(id: 'theme.pick', command: 'theme.pick', title: 'Theme…', defaultBinding: 'ctrl+k', run: _pick),
    // Always-visible switcher in the far-right status bar (T-234).
    // priority >= 100 places it in the right group; registered after
    // ipc-status so it sits to its right.
    StatusItemContribution(id: 'theme-picker.switcher', priority: 110, build: (_) => const ThemeSwitcherStatusItem()),
    // Appearance settings category (T-452) — the theme picker as the schema
    // engine's one custom control, registered against the control registry.
    SettingsControlContribution(id: 'theme-picker.appearance-control', customId: 'theme.picker', builder: (_) => const AppearanceThemeControl()),
    const SettingsCategoryContribution(
      id: 'appearance',
      category: SettingsCategory(
        id: 'appearance',
        title: 'Appearance',
        iconName: 'palette',
        priority: 10,
        sections: [
          SettingsSection(
            label: 'Theme',
            fields: [
              SettingsField(
                key: 'app.theme',
                kind: SettingsFieldKind.custom,
                label: 'Theme',
                help: 'Color theme; high contrast switches to the accessible variant.',
                customId: 'theme.picker',
              ),
            ],
          ),
          SettingsSection(
            label: 'Typography',
            fields: [
              SettingsField(
                key: kUiFontSettingKey,
                kind: SettingsFieldKind.select,
                label: 'UI font',
                help: 'Typeface for the app interface; applies live.',
                defaultValue: 'Inter',
                options: [
                  SettingsOption(value: 'Inter', label: 'Inter'),
                  SettingsOption(value: 'JosefinSans', label: 'Josefin Sans'),
                ],
              ),
              SettingsField(
                key: kMonoFontSettingKey,
                kind: SettingsFieldKind.select,
                label: 'Monospace font',
                help: 'Terminal, diffs, code, and IDs; applies live.',
                defaultValue: 'JetBrainsMono',
                options: [
                  SettingsOption(value: 'JetBrainsMono', label: 'JetBrains Mono'),
                  SettingsOption(value: 'FiraMono', label: 'Fira Mono'),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  ];

  Future<IpcResponse> _pick(List<String> args) async {
    final ctx = _ctx;
    if (ctx == null) {
      return IpcResponse.err(
        id: '',
        error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'theme-picker not activated'),
      );
    }
    final selected = await ctx.dialog.show<String>((context, dismiss) => SettingsView(controller: ctx.theme, onDismiss: dismiss));
    return IpcResponse.ok(id: '', data: {'selected': selected ?? ctx.theme.currentName});
  }
}
