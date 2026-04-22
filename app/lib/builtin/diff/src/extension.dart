import 'package:clide_app/builtin/diff/src/diff_view.dart';
import 'package:clide_app/extension/extension.dart';
import 'package:clide_app/kernel/kernel.dart';

class DiffExtension extends ClideExtension {
  @override
  String get id => 'builtin.diff';
  @override
  String get title => 'Diff';
  @override
  String get version => '0.1.0';
  @override
  List<String> get dependsOn => const [];

  @override
  List<ContributionPoint> get contributions => [
        TabContribution(
          id: 'diff.view',
          slot: Slots.workspace,
          title: 'Diff',
          titleKey: 'tab.title',
          i18nNamespace: id,
          priority: -70,
          build: (_) => const DiffView(),
        ),
      ];
}
