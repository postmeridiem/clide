import 'package:clide/extension/extension.dart';

class GraphExtension extends ClideExtension {
  @override
  String get id => 'builtin.graph';
  @override
  String get title => 'Graph';
  @override
  String get version => '0.1.0';
  @override
  List<String> get dependsOn => const ['builtin.pql'];

  @override
  List<ContributionPoint> get contributions => const [];
}
