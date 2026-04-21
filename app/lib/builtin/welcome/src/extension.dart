import 'package:clide/clide.dart';
import 'package:clide_app/builtin/welcome/src/welcome_view.dart';
import 'package:clide_app/extension/extension.dart';
import 'package:clide_app/kernel/kernel.dart';

class WelcomeExtension extends ClideExtension {
  @override
  String get id => 'builtin.welcome';
  @override
  String get title => 'Welcome';
  @override
  String get version => '0.1.0';

  @override
  List<ContributionPoint> get contributions => [
        TabContribution(
          id: 'welcome.view',
          slot: Slots.workspace,
          title: 'Welcome',
          titleKey: 'tab.title',
          i18nNamespace: id,
          priority: -100, // anchor at the far left of the workspace tabs
          build: (_) => const WelcomeView(),
        ),
        CommandContribution(
          id: 'workspace.open-project',
          command: 'workspace.open-project',
          title: 'Workspace: Open project…',
          run: (_) async => IpcResponse.ok(
            id: '',
            data: const {'note': 'project picker lands in a later tier'},
          ),
        ),
      ];
}
