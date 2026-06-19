import 'package:clide/builtin/extensions_ui/src/extensions_notice.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';

/// Extensions settings tab (T-456). Built-in extensions are always on and there
/// is no third-party install path yet, so the tab is a "watch this space"
/// notice pointing at the records that track extension management (D-16 / T-8)
/// rather than a toggle list. The real enable/install UI lands with third-party
/// (Lua) extensions.
class ExtensionsUiExtension extends ClideExtension {
  @override
  String get id => 'builtin.extensions-ui';
  @override
  String get title => 'Extensions UI';
  @override
  String get version => '0.1.0';
  @override
  List<String> get dependsOn => const [];

  @override
  List<ContributionPoint> get contributions => [
    SettingsControlContribution(id: 'extensions-ui.notice-control', customId: 'extensions.notice', builder: (_) => const ExtensionsNotice()),
    SettingsCategoryContribution(
      id: 'extensions',
      category: SettingsCategory(
        id: 'extensions',
        title: 'Extensions',
        titleKey: 'settings.extensions.title',
        i18nNamespace: id,
        iconName: 'puzzle-piece',
        priority: 80,
        sections: [
          SettingsSection(
            label: '',
            labelKey: 'settings.extensions.section.notice',
            fields: [
              SettingsField(
                key: 'app.extensions._notice',
                kind: SettingsFieldKind.custom,
                label: '',
                labelKey: 'settings.extensions.field.notice.label',
                customId: 'extensions.notice',
              ),
            ],
          ),
        ],
      ),
    ),
  ];
}
