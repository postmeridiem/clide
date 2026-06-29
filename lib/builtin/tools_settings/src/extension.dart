import 'package:clide/clide.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/env/supporter_binaries.dart';

/// Settings surface for the external supporter binaries clide shells out to —
/// claude, d2, … (D-104 / T-495). A path field per tool (`app.tools.<name>`),
/// auto-detected on first run, plus a Re-detect action. Editing a path rebuilds
/// the live resolver so the change takes effect without a restart.
class ToolsSettingsExtension extends ClideExtension {
  @override
  String get id => 'builtin.tools-settings';
  @override
  String get title => 'Tool paths';
  @override
  String get version => '0.1.0';

  ClideExtensionContext? _ctx;

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _ctx = ctx;
    ctx.settings.addListener(_sync);
  }

  @override
  Future<void> deactivate() async {
    _ctx?.settings.removeListener(_sync);
  }

  /// Rebuild the process-wide resolver from the current override keys so a path
  /// edited in the settings panel applies live. Cheap — reads a couple of keys.
  void _sync() {
    final ctx = _ctx;
    if (ctx == null) return;
    activeSupporterBinaries = supporterBinariesFrom((k) => ctx.settings.get<Object>(k));
  }

  @override
  List<ContributionPoint> get contributions => [
    CommandContribution(
      id: 'tools.detect',
      command: 'tools.detect',
      title: 'Re-detect tool paths',
      titleKey: 'command.detect',
      i18nNamespace: id,
      run: _redetect,
    ),
    SettingsCategoryContribution(
      id: 'tools',
      category: SettingsCategory(
        id: 'tools',
        title: 'Tools',
        titleKey: 'settings.title',
        i18nNamespace: id,
        iconName: 'wrench',
        priority: 60,
        sections: [
          SettingsSection(
            label: 'Supporter binaries',
            labelKey: 'settings.section.binaries',
            fields: [
              SettingsField(
                key: supporterToolKey('claude'),
                kind: SettingsFieldKind.text,
                label: 'Claude CLI',
                labelKey: 'settings.field.claude.label',
                help: 'Absolute path to the claude binary; blank to auto-resolve.',
                helpKey: 'settings.field.claude.help',
              ),
              SettingsField(
                key: supporterToolKey('d2'),
                kind: SettingsFieldKind.text,
                label: 'd2',
                labelKey: 'settings.field.d2.label',
                help: 'Absolute path to the d2 diagram compiler; blank to auto-resolve.',
                helpKey: 'settings.field.d2.help',
              ),
              SettingsField(
                key: 'app.tools.redetect',
                kind: SettingsFieldKind.file,
                label: 'Re-detect',
                labelKey: 'settings.field.detect.label',
                help: 'Re-scan PATH and the common install dirs, overwriting the paths above.',
                helpKey: 'settings.field.detect.help',
                fileCommand: 'tools.detect',
              ),
            ],
          ),
        ],
      ),
    ),
  ];

  Future<IpcResponse> _redetect(List<String> args) async {
    final ctx = _ctx;
    if (ctx == null) {
      return IpcResponse.err(
        id: '',
        error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'tools-settings not activated'),
      );
    }
    final resolver = await redetectSupporterBinaries(write: (k, v) => ctx.settings.set<Object?>(k, v));
    activeSupporterBinaries = resolver;
    return IpcResponse.ok(
      id: '',
      data: {
        'detected': {for (final t in knownSupporterTools) t: resolver.resolve(t)},
      },
    );
  }
}
