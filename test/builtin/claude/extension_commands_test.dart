/// T-391: the claude builtin's command handlers must honor the D-6
/// exit-code contract — a failure is an ERROR envelope (non-zero CLI
/// exit), never `ok` with an `error` field a script can't detect.
/// `clide claude.agent.set-permission-mode bogus` exited 0 before this.
/// Plus the activation lifecycle + command success paths.
library;

import 'package:clide/builtin/claude/src/activity_cluster.dart' show kActivityFoldLevelKey;
import 'package:clide/builtin/claude/src/session_defaults.dart' show kDefaultEffortKey, kDefaultModelKey, kDefaultPermissionModeKey;
import 'package:clide/builtin/claude/src/claude_config.dart' show activeClaudeConfig;
import 'package:clide/builtin/claude/src/extension.dart';
import 'package:clide/builtin/claude/src/session_orchestrator.dart' show activeSessionOrchestrator;
import 'package:clide/clide.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/daemon/image_commands.dart' show imageShowChannel;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // GlobalKey lookups in handlers
  final ext = ClaudeExtension();
  CommandContribution cmd(String id) => ext.contributions.whereType<CommandContribution>().firstWhere((c) => c.id == id);

  group('failure paths return error envelopes (T-391, D-6)', () {
    // (command id, args, expected error kind)
    final cases = <(String, List<String>, String)>[
      ('claude.agent.show', [], IpcErrorKind.userError),
      ('claude.agent.hide', [], IpcErrorKind.userError),
      ('claude.agent.close', [], IpcErrorKind.userError),
      ('claude.agent.mute', [], IpcErrorKind.userError),
      ('claude.agent.unmute', [], IpcErrorKind.userError),
      ('claude.agent.inject-message', [], IpcErrorKind.userError),
      ('claude.agent.inject-message', ['some-id'], IpcErrorKind.userError),
      ('claude.agent.set-permission-mode', [], IpcErrorKind.userError),
      ('claude.agent.set-permission-mode', ['some-id'], IpcErrorKind.userError),
      ('claude.agent.set-permission-mode', ['some-id', 'bogus'], IpcErrorKind.userError),
      ('claude.mode.cycle', [], IpcErrorKind.notFound),
      ('claude.task.reassign', [], IpcErrorKind.userError),
      ('claude.team-chat.post', [], IpcErrorKind.userError),
      ('claude.agent.fork', [], IpcErrorKind.userError),
      // No orchestrator is wired in this test (extension not activated),
      // so a fork with a source id fails as unavailable tooling.
      ('claude.agent.fork', ['some-id'], IpcErrorKind.toolError),
    ];

    for (final (id, args, kind) in cases) {
      test('$id ${args.isEmpty ? '(no args)' : args.join(' ')} → $kind', () async {
        final r = await cmd(id).run(args);
        expect(r.ok, isFalse, reason: 'a failure must not report ok');
        expect(r.error!.kind, kind);
        expect(r.error!.code, isNot(0), reason: 'the CLI must exit non-zero');
      });
    }
  });

  group('activated lifecycle + success paths', () {
    late KernelFixture f;

    setUp(() async {
      f = await KernelFixture.create();
      f.services.extensions.register(ClaudeExtension());
      await f.services.extensions.activate('builtin.claude');
      expect(f.services.extensions.isActivated('builtin.claude'), isTrue, reason: f.services.extensions.failedExtensions.toString());
    });

    tearDown(() async {
      await f.services.extensions.deactivate('builtin.claude');
      await f.dispose();
    });

    Future<IpcResponse> run(String command, [List<String> args = const []]) {
      final c = f.services.commands.get(command);
      expect(c, isNotNull, reason: '$command should be registered after activation');
      return c!.run(args);
    }

    test('roster verbs succeed once the orchestrator is wired (no-op on unknown ids)', () async {
      for (final verb in ['claude.agent.show', 'claude.agent.hide', 'claude.agent.close', 'claude.agent.mute', 'claude.agent.unmute']) {
        final r = await run(verb, ['no-such-session']);
        expect(r.ok, isTrue, reason: '$verb is idempotent on unknown ids');
      }
      final inject = await run('claude.agent.inject-message', ['no-such-session', 'hello']);
      expect(inject.ok, isTrue);
      final mode = await run('claude.agent.set-permission-mode', ['no-such-session', 'plan']);
      expect(mode.ok, isTrue);
      expect(mode.data['mode'], 'plan');
    });

    test('claude.new-secondary and kill-all-sessions succeed with no live panes', () async {
      expect((await run('claude.new-secondary')).ok, isTrue);
      final killed = await run('claude.kill-all-sessions');
      expect(killed.ok, isTrue);
      expect(killed.data['status'], 'killed');
    });

    test('claude.activity.fold-level cycles and persists the setting (T-235)', () async {
      final r1 = await run('claude.activity.fold-level');
      expect(r1.ok, isTrue);
      final first = r1.data['foldLevel'] as String;
      expect(f.services.settings.get<String>(kActivityFoldLevelKey), first);
      final r2 = await run('claude.activity.fold-level');
      expect(r2.data['foldLevel'], isNot(first), reason: 'the level advances each call');
    });

    test('claude.team-chat.open and .post succeed', () async {
      expect((await run('claude.team-chat.open')).ok, isTrue);
      final broadcast = await run('claude.team-chat.post', ['hello', 'team']);
      expect(broadcast.ok, isTrue);
      final directed = await run('claude.team-chat.post', ['@tyre', 'hello', 'you']);
      expect(directed.ok, isTrue);
      expect(directed.data['to'], 'tyre');
    });

    test('claude.session-storage degrades cleanly when files.root is unavailable', () async {
      // The fixture IPC has no files.root stub → the handler bails out ok
      // without opening the dialog.
      final r = await run('claude.session-storage');
      expect(r.ok, isTrue);
    });

    test('an image-show message with no live session is dropped silently (T-249)', () async {
      f.services.messages.publish('test', imageShowChannel, {'path': '/tmp/x.png'});
      f.services.messages.publish('test', imageShowChannel, {'path': ''});
      await pumpEventQueue();
      // Nothing to assert beyond "no throw" — there is no conversation to
      // receive the card and the CLI already acked at publish time.
    });

    test('a project switch closes sessions that belong to the old root (T-269)', () async {
      f.services.events.emit(const ProjectOpened(path: '/repo-one'));
      await pumpEventQueue();
      f.services.events.emit(const ProjectOpened(path: '/repo-one'));
      await pumpEventQueue();
      f.services.events.emit(const ProjectOpened(path: '/repo-two'));
      await pumpEventQueue();
      // No live sessions in this fixture — the sweep runs over an empty set.
      expect(activeSessionOrchestrator!.sessions, isEmpty);
    });

    test('deactivate clears the builtin-owned singletons', () async {
      expect(activeSessionOrchestrator, isNotNull);
      await f.services.extensions.deactivate('builtin.claude');
      expect(activeSessionOrchestrator, isNull);
      expect(activeClaudeConfig, isNull);
    });
  });

  group('Activity settings category (T-453)', () {
    final category = ext.contributions.whereType<SettingsCategoryContribution>().firstWhere((c) => c.id == 'activity').category;

    test('contributes an Activity category with the fold-level field', () {
      expect(category.title, 'Activity');
      final field = category.sections.expand((s) => s.fields).firstWhere((f) => f.key == kActivityFoldLevelKey);
      expect(field.kind, SettingsFieldKind.select);
      expect(field.defaultValue, 'tools');
      expect(field.options.map((o) => o.value), containsAll(['none', 'tools', 'thinking', 'everything']));
    });
  });

  group('Claude settings category (T-457)', () {
    final category = ext.contributions.whereType<SettingsCategoryContribution>().firstWhere((c) => c.id == 'claude').category;

    test('contributes new-session default fields for model, effort, permission', () {
      expect(category.title, 'Claude');
      final keys = category.sections.expand((s) => s.fields).map((f) => f.key).toSet();
      expect(keys, containsAll([kDefaultModelKey, kDefaultEffortKey, kDefaultPermissionModeKey]));
      for (final f in category.sections.expand((s) => s.fields)) {
        expect(f.kind, SettingsFieldKind.select);
        expect(f.options, isNotEmpty);
      }
    });
  });
}
