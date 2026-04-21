import 'package:clide_app/extension/extension.dart';

/// Tier-0 stub. Real implementation lands in a later tier; the extension
/// is registered so the extensions-ui surface can list it as "installed,
/// not yet implemented" and its id is reserved.
class GraphExtension extends ClideExtension {
  @override
  String get id => 'builtin.graph';
  @override
  String get title => 'Graph';
  @override
  String get version => '0.0.0-stub';
  @override
  List<String> get dependsOn => const ['builtin.pql'];
  @override
  List<ContributionPoint> get contributions => const [];
}
