import 'package:clide/builtin/ipc_status/src/status_item.dart';
import 'package:clide/extension/extension.dart';

class IpcStatusExtension extends ClideExtension {
  @override
  String get id => 'builtin.ipc-status';
  @override
  String get title => 'Tool status';
  @override
  String get version => '0.2.0';

  @override
  List<ContributionPoint> get contributions => [
        StatusItemContribution(
          id: 'ipc-status.indicator',
          priority: 100,
          build: (_) => const ToolStatusItem(),
        ),
      ];
}
