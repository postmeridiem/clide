import 'package:clide/clide.dart';
import 'package:clide/builtin/theme_picker/src/settings_view.dart';
import 'package:clide/builtin/theme_picker/src/theme_status_item.dart';
import 'package:clide/extension/extension.dart';

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
