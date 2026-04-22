import 'package:clide_app/builtin/markdown/src/markdown_viewer.dart';
import 'package:clide_app/extension/extension.dart';
import 'package:clide_app/kernel/kernel.dart';

class MarkdownExtension extends ClideExtension {
  @override
  String get id => 'builtin.markdown';
  @override
  String get title => 'Markdown';
  @override
  String get version => '0.1.0';
  @override
  List<String> get dependsOn => const ['builtin.editor'];

  @override
  List<ContributionPoint> get contributions => [
        TabContribution(
          id: 'markdown.viewer',
          slot: Slots.contextPanel,
          title: 'Viewer',
          titleKey: 'tab.viewer',
          i18nNamespace: id,
          priority: -100,
          build: (_) => const MarkdownViewer(),
        ),
      ];
}
