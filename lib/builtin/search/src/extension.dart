import 'package:clide/builtin/search/src/search_panel_view.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';

/// Find-in-files panel. Contributes a sidebar tab that runs workspace
/// content searches through the daemon's `search.*` subsystem (the
/// pure-Dart isolate-pool grep, D-79) and lists matches grouped by
/// file, click-to-open at the line.
class SearchExtension extends ClideExtension {
  @override
  String get id => 'builtin.search';
  @override
  String get title => 'Search';
  @override
  String get version => '0.1.0';
  @override
  List<String> get dependsOn => const [];

  @override
  List<ContributionPoint> get contributions => [
        TabContribution(
          id: 'search.findInFiles',
          slot: Slots.sidebar,
          title: 'Search',
          icon: PhosphorIcons.byName('magnifying-glass'),
          priority: -90,
          build: (_) => const SearchPanelView(),
        ),
      ];
}
