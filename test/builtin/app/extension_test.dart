/// `builtin.app` (T-590, D-110): the General settings category, the tray
/// policy it pushes to native, the log level it applies live, and the
/// hide / quit / quit-all commands.
library;

import 'package:clide/builtin/app/app.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart' show kLocaleSettingKey;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('clide/tray');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late KernelFixture f;
  late List<MethodCall> calls;
  var hideAllowed = true;

  List<Object?> argsOf(String method) => [for (final c in calls.where((c) => c.method == method)) c.arguments];

  setUp(() async {
    calls = [];
    hideAllowed = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'hide' ? hideAllowed : true;
    });
    f = await KernelFixture.create(
      i18nCatalogs: {
        'builtin.app': {
          const Locale('en', 'US'): {
            'tray.tooltip': {'translation': 'clide'},
            'tray.showAll': {'translation': 'Show all windows'},
            'tray.hideAll': {'translation': 'Hide all windows'},
            // Distinct from the inline placeholder, so the assertion below
            // proves the catalog was loaded before the labels were pushed.
            'tray.quitAll': {'translation': 'Quit clide (catalog)'},
            'tray.noWorkspace': {'translation': 'clide (no project)'},
          },
        },
      },
    );
    f.services.extensions.register(AppExtension());
    await f.services.extensions.activate('builtin.app');
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await f.dispose();
  });

  group('General settings category', () {
    SettingsCategory general() => f.services.settingsRegistry.categories.firstWhere((c) => c.id == 'general');

    test('comes first, with Window, Language and Diagnostics sections', () {
      expect(f.services.settingsRegistry.categories.first.id, 'general');
      expect(general().sections.map((s) => s.label), ['Window', 'Language', 'Diagnostics']);
    });

    test('carries close-to-tray, the locale and the log level', () {
      final byKey = {for (final fld in general().sections.expand((s) => s.fields)) fld.key: fld};
      expect(byKey[kCloseToTrayKey]!.kind, SettingsFieldKind.toggle);
      expect(byKey[kCloseToTrayKey]!.defaultValue, isTrue);
      expect(byKey[kLocaleSettingKey]!.options.map((o) => o.value), containsAll(['en_US', 'nl_NL']));
      expect(byKey[kLogLevelKey]!.options.map((o) => o.value), LogLevel.values.map((l) => l.name));
    });
  });

  group('tray policy pushed to native', () {
    test('activation attaches, sends the default close-to-tray and the labels', () {
      expect(argsOf('isAvailable'), hasLength(1));
      expect(argsOf('setCloseToTray'), [true]);
      final labels = argsOf('setLabels').single! as Map;
      expect(labels.keys, containsAll(['tooltip', 'showAll', 'hideAll', 'quitAll', 'noWorkspace']));
      expect(labels['quitAll'], 'Quit clide (catalog)', reason: 'resolved from the catalog, loaded before the push');
    });

    test('turning the setting off tells native; an unrelated write does not repeat it', () async {
      await f.services.settings.set<bool>(kCloseToTrayKey, false);
      await f.services.settings.set<String>('app.something.else', 'x');
      expect(argsOf('setCloseToTray'), [true, false]);
    });

    test('opening a project names the window in the tray menu', () async {
      f.services.events.emit(const ProjectOpened(path: '/work/repo-a'));
      await pumpEventQueue();
      expect(argsOf('setWorkspace'), contains('/work/repo-a'));
    });
  });

  test('a log level picked in settings applies to the logger live', () async {
    await f.services.settings.set<String>(kLogLevelKey, 'error');
    expect(f.services.log.minLevel, LogLevel.error);
    await f.services.settings.set<String>(kLogLevelKey, 'nonsense');
    expect(f.services.log.minLevel, LogLevel.error, reason: 'an unknown name changes nothing');
  });

  group('commands', () {
    test('hide, quit and quit-all reach native', () async {
      expect((await f.services.commands.execute('window.hideToTray')).ok, isTrue);
      expect((await f.services.commands.execute('window.quit')).ok, isTrue);
      expect((await f.services.commands.execute('window.quitAll')).ok, isTrue);
      expect(calls.map((c) => c.method), containsAllInOrder(['hide', 'quit', 'quitAll']));
    });

    test('hide with no tray host is an error, not a vanished window', () async {
      hideAllowed = false;
      final r = await f.services.commands.execute('window.hideToTray');
      expect(r.ok, isFalse);
      expect(r.error!.message, contains('no tray host'));
    });
  });

  test('deactivate stops following settings', () async {
    await f.services.extensions.deactivate('builtin.app');
    calls.clear();
    await f.services.settings.set<bool>(kCloseToTrayKey, false);
    expect(argsOf('setCloseToTray'), isEmpty);
  });
}
