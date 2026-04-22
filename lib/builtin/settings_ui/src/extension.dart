import 'package:clide/extension/extension.dart';

/// Tier-0 stub. Real implementation lands in a later tier; the extension
/// is registered so the extensions-ui surface can list it as "installed,
/// not yet implemented" and its id is reserved.
class SettingsUiExtension extends ClideExtension {
  @override
  String get id => 'builtin.settings-ui';
  @override
  String get title => 'Settings UI';
  @override
  String get version => '0.0.0-stub';
  @override
  List<String> get dependsOn => const [];
  @override
  List<ContributionPoint> get contributions => const [];
}
