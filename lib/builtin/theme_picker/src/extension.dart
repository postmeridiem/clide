import 'package:clide/clide.dart';
import 'package:clide/builtin/theme_picker/src/picker_view.dart';
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
        CommandContribution(
          id: 'theme.pick',
          command: 'theme.pick',
          title: 'Theme: Pick…',
          defaultBinding: 'ctrl+k',
          run: _pick,
        ),
        // Always-visible switcher in the far-right status bar (T-234).
        // priority >= 100 places it in the right group; registered after
        // ipc-status so it sits to its right.
        StatusItemContribution(
          id: 'theme-picker.switcher',
          priority: 110,
          build: (_) => const ThemeSwitcherStatusItem(),
        ),
      ];

  Future<IpcResponse> _pick(List<String> args) async {
    final ctx = _ctx;
    if (ctx == null) {
      return IpcResponse.err(
        id: '',
        error: IpcError(
          code: IpcExitCode.toolError,
          kind: IpcErrorKind.toolError,
          message: 'theme-picker not activated',
        ),
      );
    }
    final selected = await ctx.dialog.show<String>(
      (context, dismiss) => ThemePickerView(
        controller: ctx.theme,
        onDismiss: dismiss,
      ),
    );
    return IpcResponse.ok(id: '', data: {
      'selected': selected ?? ctx.theme.currentName,
    });
  }
}
