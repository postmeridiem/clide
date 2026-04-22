import 'package:clide/clide.dart';
import 'package:clide_app/extension/extension.dart';
import 'package:clide_app/kernel/kernel.dart';

class DefaultLayoutExtension extends ClideExtension {
  @override
  String get id => 'builtin.default-layout';
  @override
  String get title => 'Default layout';
  @override
  String get version => '0.1.0';

  LayoutPresetContribution? _preset;
  ClideExtensionContext? _ctx;

  @override
  List<ContributionPoint> get contributions => [
        _preset ?? classicPreset(),
        CommandContribution(
          id: 'layout.reset',
          command: 'layout.reset',
          title: 'Layout: Reset to Classic',
          run: _reset,
        ),
        CommandContribution(
          id: 'palette.toggle',
          command: 'palette.toggle',
          title: 'Command Palette',
          defaultBinding: 'ctrl+shift+p',
          run: _togglePalette,
        ),
        CommandContribution(
          id: 'sidebar.toggle',
          command: 'sidebar.toggle',
          title: 'Toggle Sidebar',
          defaultBinding: 'ctrl+b',
          run: _toggleSidebar,
        ),
        CommandContribution(
          id: 'context.toggle',
          command: 'context.toggle',
          title: 'Toggle Context Panel',
          defaultBinding: 'ctrl+j',
          run: _toggleContext,
        ),
      ];

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _ctx = ctx;
    _preset = classicPreset();
    ctx.arrangement.registerSlotsInto(ctx.panels, _preset!);
    ctx.arrangement.applyPreset(_preset!);
  }

  Future<IpcResponse> _reset(List<String> args) async {
    final preset = _preset;
    final ctx = _ctx;
    if (preset == null || ctx == null) {
      return _notActivated();
    }
    ctx.arrangement.applyPreset(preset);
    return IpcResponse.ok(id: '', data: {'preset': preset.id});
  }

  Future<IpcResponse> _togglePalette(List<String> args) async {
    final ctx = _ctx;
    if (ctx == null) return _notActivated();
    ctx.palette.toggle();
    return IpcResponse.ok(id: '', data: {'open': ctx.palette.isOpen});
  }

  Future<IpcResponse> _toggleSidebar(List<String> args) async {
    final ctx = _ctx;
    if (ctx == null) return _notActivated();
    final visible = ctx.arrangement.isVisible(Slots.sidebar);
    ctx.arrangement.setVisible(Slots.sidebar, !visible);
    return IpcResponse.ok(id: '', data: {'visible': !visible});
  }

  Future<IpcResponse> _toggleContext(List<String> args) async {
    final ctx = _ctx;
    if (ctx == null) return _notActivated();
    final visible = ctx.arrangement.isVisible(Slots.contextPanel);
    ctx.arrangement.setVisible(Slots.contextPanel, !visible);
    return IpcResponse.ok(id: '', data: {'visible': !visible});
  }

  static IpcResponse _notActivated() => IpcResponse.err(
        id: '',
        error: IpcError(
          code: IpcExitCode.toolError,
          kind: IpcErrorKind.toolError,
          message: 'not activated',
        ),
      );
}
