import 'package:clide_app/extension/extension.dart';

/// Tier-reserved stub. Will surface a sidebar tab (filter by domain /
/// status, backlinks from current file) + commands (`decisions.open`,
/// `decisions.claim`, `decisions.amend`). Data source: `pql decisions …`.
class DecisionsExtension extends ClideExtension {
  @override
  String get id => 'builtin.decisions';
  @override
  String get title => 'Decisions';
  @override
  String get version => '0.0.0-stub';
  @override
  List<String> get dependsOn => const [];
  @override
  List<ContributionPoint> get contributions => const [];
}
