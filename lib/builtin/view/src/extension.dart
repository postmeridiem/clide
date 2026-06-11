import 'package:clide/clide.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';

/// Surfaces view-level commands (currently the three text-zoom verbs)
/// in the command palette so they're discoverable. The keybindings
/// themselves are owned by the default keymap; commands here exist so
/// users browsing `Ctrl+Shift+P` see the same actions.
class ViewExtension extends ClideExtension {
  ViewExtension({required this.textZoom});

  final TextZoom textZoom;

  @override
  String get id => 'builtin.view';
  @override
  String get title => 'View';
  @override
  String get version => '0.1.0';

  @override
  Future<void> activate(ClideExtensionContext ctx) async {}

  @override
  List<ContributionPoint> get contributions => [
    // Keybindings live in `assets/keymaps/default.yaml` against the
    // text.scale* intents — registering a `defaultBinding` here too
    // would shadow them. Palette discovery is the only goal.
    CommandContribution(
      id: 'view.zoomIn',
      command: 'view.zoomIn',
      title: 'View: Zoom In',
      run: (_) async {
        textZoom.increase();
        return IpcResponse.ok(id: '', data: {'scale': textZoom.scale});
      },
    ),
    CommandContribution(
      id: 'view.zoomOut',
      command: 'view.zoomOut',
      title: 'View: Zoom Out',
      run: (_) async {
        textZoom.decrease();
        return IpcResponse.ok(id: '', data: {'scale': textZoom.scale});
      },
    ),
    CommandContribution(
      id: 'view.zoomReset',
      command: 'view.zoomReset',
      title: 'View: Reset Zoom',
      run: (_) async {
        textZoom.reset();
        return IpcResponse.ok(id: '', data: {'scale': textZoom.scale});
      },
    ),
  ];
}
