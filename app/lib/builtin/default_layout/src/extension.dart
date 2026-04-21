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
      ];

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _ctx = ctx;
    _preset = classicPreset();
    // Register the preset's slots into the panel registry and apply
    // the arrangement so every SlotHost has something to render.
    ctx.arrangement.registerSlotsInto(ctx.panels, _preset!);
    ctx.arrangement.applyPreset(_preset!);
  }

  Future<IpcResponse> _reset(List<String> args) async {
    final preset = _preset;
    final ctx = _ctx;
    if (preset == null || ctx == null) {
      return IpcResponse.err(
        id: '',
        error: IpcError(
          code: IpcExitCode.toolError,
          kind: IpcErrorKind.toolError,
          message: 'default-layout not activated',
        ),
      );
    }
    ctx.arrangement.applyPreset(preset);
    return IpcResponse.ok(id: '', data: {'preset': preset.id});
  }
}
