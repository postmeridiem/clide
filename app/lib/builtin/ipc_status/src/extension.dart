import 'package:clide_app/builtin/ipc_status/src/status_item.dart';
import 'package:clide_app/extension/extension.dart';
import 'package:clide_app/kernel/kernel.dart';

class IpcStatusExtension extends ClideExtension {
  @override
  String get id => 'builtin.ipc-status';
  @override
  String get title => 'Daemon connection';
  @override
  String get version => '0.1.0';

  DaemonClient? _ipc;

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _ipc = ctx.ipc;
  }

  @override
  List<ContributionPoint> get contributions {
    final ipc = _ipc;
    if (ipc == null) return const [];
    return [
      StatusItemContribution(
        id: 'ipc-status.indicator',
        priority: 100, // right-side
        listenable: ipc,
        build: (_) => IpcStatusItem(ipc: ipc),
      ),
    ];
  }
}
