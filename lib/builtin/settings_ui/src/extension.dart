import 'package:clide/builtin/settings_ui/src/settings_modal.dart';
import 'package:clide/clide.dart';
import 'package:clide/extension/extension.dart';

/// Schema-driven Settings UI (epic T-444). T-445 lands the foundation: the
/// `settings.open` command and the modal shell it opens. The category rail
/// (T-447), schema field renderer (T-448), scope tags (T-449), search
/// (T-450) and the per-subsystem categories fill the shell in later tickets.
class SettingsUiExtension extends ClideExtension {
  @override
  String get id => 'builtin.settings-ui';
  @override
  String get title => 'Settings UI';
  @override
  String get version => '0.1.0';
  @override
  List<String> get dependsOn => const [];

  ClideExtensionContext? _ctx;

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _ctx = ctx;
  }

  @override
  List<ContributionPoint> get contributions => [
    // Opens the Settings panel. Palette + File-menu entry come for free off
    // the title; ctrl+, is the conventional settings shortcut.
    CommandContribution(
      id: 'settings.open',
      command: 'settings.open',
      title: 'Settings…',
      titleKey: 'command.open',
      i18nNamespace: id,
      defaultBinding: 'ctrl+,',
      run: _open,
    ),
  ];

  Future<IpcResponse> _open(List<String> args) async {
    final ctx = _ctx;
    if (ctx == null) {
      return IpcResponse.err(
        id: '',
        error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'settings-ui not activated'),
      );
    }
    await ctx.dialog.show<Object>((context, dismiss) => SettingsModal(onDismiss: () => dismiss()));
    return IpcResponse.ok(id: '', data: const {});
  }
}
