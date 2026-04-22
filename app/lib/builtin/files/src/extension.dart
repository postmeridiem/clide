import 'package:clide_app/builtin/files/src/file_tree_view.dart';
import 'package:clide_app/extension/extension.dart';
import 'package:clide_app/kernel/kernel.dart';

/// Workspace filesystem panel. Contributes a sidebar tab that renders
/// the workspace file tree rooted at the git root, powered by the
/// daemon's `files.*` subsystem (ls + watch with ignore-file
/// filtering).
class FilesExtension extends ClideExtension {
  @override
  String get id => 'builtin.files';
  @override
  String get title => 'Files';
  @override
  String get version => '0.1.0';
  @override
  List<String> get dependsOn => const [];

  @override
  List<ContributionPoint> get contributions => [
        TabContribution(
          id: 'files.tree',
          slot: Slots.sidebar,
          title: 'Files',
          titleKey: 'tab.title',
          i18nNamespace: id,
          priority: -100,
          build: (_) => const FileTreeView(),
        ),
      ];
}
