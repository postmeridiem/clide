/// Tests for ClaudeConfig (T-151, D-76): layered global+local config load,
/// version-keyed init-probe cache, static fallback, watcher-driven refresh,
/// and graceful degradation on parse misses / a missing claude.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/builtin/claude/src/claude_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  late Directory globalDir; // stands in for ~/.claude
  late Directory projectDir; // repo root; local config under .claude
  late Directory localDir; // <projectDir>/.claude
  late Directory cacheDir; // clide's own global dir for the version cache

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('claude_config_test');
    globalDir = Directory('${tmp.path}/global')..createSync();
    projectDir = Directory('${tmp.path}/project')..createSync();
    localDir = Directory('${projectDir.path}/.claude')..createSync();
    cacheDir = Directory('${tmp.path}/clide-cache')..createSync();
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<void> writeSkill(Directory scope, String dirName, {String? name, String? description}) async {
    final d = Directory('${scope.path}/skills/$dirName')..createSync(recursive: true);
    final fm = StringBuffer('---\n');
    if (name != null) fm.writeln('name: $name');
    if (description != null) fm.writeln('description: $description');
    fm
      ..writeln('---')
      ..writeln('skill body');
    await File('${d.path}/SKILL.md').writeAsString(fm.toString());
  }

  Future<void> writeCommand(Directory scope, String fileName) async {
    final d = Directory('${scope.path}/commands')..createSync(recursive: true);
    await File('${d.path}/$fileName').writeAsString('# command');
  }

  Future<void> writeSettings(Directory scope, Map<String, Object?> json) async {
    await File('${scope.path}/settings.json').writeAsString(jsonEncode(json));
  }

  String initLine({
    String version = '2.1.150',
    List<String> slash = const ['clear', 'pql'],
    List<String> skills = const ['pql'],
  }) =>
      '${jsonEncode({
            'type': 'system',
            'subtype': 'init',
            'claude_code_version': version,
            'slash_commands': slash,
            'skills': skills,
            'model': 'claude-opus-4-7',
            'permissionMode': 'default',
          })}\n';

  ClaudeConfig build({
    ClaudeVersionRunner? versionRunner,
    ClaudeInitProbe? initProbe,
    ClaudeConfigWatch? watch,
    Duration debounce = Duration.zero,
  }) =>
      ClaudeConfig(
        globalDir: globalDir,
        cacheDir: cacheDir,
        projectDir: projectDir,
        versionRunner: versionRunner ?? () async => '2.1.150 (Claude Code)\n',
        initProbe: initProbe ?? () async => initLine(),
        // Default: never start a real FileWatcher in tests.
        watch: watch ?? (_) => const Stream<void>.empty(),
        debounce: debounce,
      );

  test('parses the version out of the --version banner', () async {
    final c = build();
    await c.load();
    expect(c.version, '2.1.150');
    expect(c.ready, isTrue);
    c.dispose();
  });

  test('a missing claude leaves version null, not ready, and falls back', () async {
    final c = build(versionRunner: () async => null);
    await c.load();
    expect(c.version, isNull);
    expect(c.ready, isFalse);
    expect(c.probe, isNull);
    expect(c.slashCommands, kFallbackSlashCommands);
    c.dispose();
  });

  test('layers skills/commands/settings/permissions local-over-global', () async {
    await writeSkill(globalDir, 'shared', name: 'shared', description: 'from-global');
    await writeSkill(globalDir, 'only-global', name: 'only-global');
    await writeSkill(localDir, 'shared', name: 'shared', description: 'from-local');
    await writeSkill(localDir, 'only-local', name: 'only-local');
    await writeCommand(globalDir, 'gcmd.md');
    await writeCommand(localDir, 'lcmd.md');
    await writeSettings(globalDir, {
      'model': 'opus',
      'keep': 1,
      'permissions': {
        'allow': ['Bash'],
        'deny': ['Write']
      },
    });
    await writeSettings(localDir, {
      'model': 'sonnet',
      'permissions': {
        'allow': ['Edit'],
        'ask': ['Read']
      },
    });

    final c = build();
    await c.load();

    expect(c.skills.map((s) => s.name), ['only-global', 'only-local', 'shared']);
    final shared = c.skills.firstWhere((s) => s.name == 'shared');
    expect(shared.scope, ConfigScope.local, reason: 'local wins on a name collision');
    expect(shared.description, 'from-local');

    expect(c.commands.map((x) => x.name), ['gcmd', 'lcmd']);

    expect(c.settings['model'], 'sonnet'); // local overrides
    expect(c.settings['keep'], 1); // global-only key survives
    expect(c.permissions.allow, ['Bash', 'Edit']); // union across scopes
    expect(c.permissions.deny, ['Write']);
    expect(c.permissions.ask, ['Read']);
    c.dispose();
  });

  test('a skill with no frontmatter falls back to its directory name', () async {
    final d = Directory('${globalDir.path}/skills/bare')..createSync(recursive: true);
    await File('${d.path}/SKILL.md').writeAsString('no frontmatter here');
    final c = build();
    await c.load();
    final bare = c.skills.firstWhere((s) => s.name == 'bare');
    expect(bare.description, isNull);
    c.dispose();
  });

  test('load stays on the fallback until ensureProbe runs (no eager turn)', () async {
    var probeCalls = 0;
    final c = build(initProbe: () async {
      probeCalls++;
      return initLine(slash: ['clear', 'pql', 'whats-next']);
    });
    await c.load();
    expect(probeCalls, 0, reason: 'load must never pay for a model turn');
    expect(c.slashCommands, kFallbackSlashCommands);

    await c.ensureProbe();
    expect(probeCalls, 1);
    expect(c.slashCommands, contains('whats-next'));
    c.dispose();
  });

  test('ensureProbe writes the version-keyed cache, which load then reuses', () async {
    var probeCalls = 0;
    Future<String?> probe() async {
      probeCalls++;
      return initLine(slash: ['clear', 'pql', 'whats-next']);
    }

    final c1 = build(initProbe: probe);
    await c1.load();
    await c1.ensureProbe();
    expect(probeCalls, 1);
    expect(File('${cacheDir.path}/init-2.1.150.json').existsSync(), isTrue);
    c1.dispose();

    // A fresh instance, same version → load reads the cache, no probe needed.
    final c2 = build(initProbe: probe);
    await c2.load();
    expect(c2.probe, isNotNull, reason: 'cache hit at load time');
    expect(c2.slashCommands, contains('whats-next'));
    await c2.ensureProbe();
    expect(probeCalls, 1, reason: 'already have probe data → no re-probe');
    c2.dispose();
  });

  test('a different claude version misses the cache and re-probes', () async {
    var probeCalls = 0;
    final c1 = build(initProbe: () async {
      probeCalls++;
      return initLine();
    });
    await c1.load();
    await c1.ensureProbe();
    expect(probeCalls, 1);
    c1.dispose();

    final c2 = build(
      versionRunner: () async => '2.2.0 (Claude Code)\n',
      initProbe: () async {
        probeCalls++;
        return initLine(version: '2.2.0', slash: ['clear', 'new-cmd']);
      },
    );
    await c2.load();
    expect(c2.probe, isNull, reason: 'no cache for 2.2.0 yet');
    await c2.ensureProbe();
    expect(probeCalls, 2);
    expect(c2.slashCommands, contains('new-cmd'));
    expect(File('${cacheDir.path}/init-2.2.0.json').existsSync(), isTrue);
    c2.dispose();
  });

  test('a failed/garbage probe falls back to the static list and does not cache', () async {
    final c = build(initProbe: () async => 'not json at all\n{"type":"system"}\n');
    await c.load();
    await c.ensureProbe();
    expect(c.probe, isNull);
    expect(c.slashCommands, kFallbackSlashCommands);
    expect(File('${cacheDir.path}/init-2.1.150.json').existsSync(), isFalse);
    c.dispose();
  });

  test('skips non-init json lines when parsing the probe stream', () async {
    final stream = StringBuffer()
      ..write('{"type":"system","subtype":"hook_started"}\n')
      ..write(initLine(slash: ['clear', 'compact']))
      ..write('{"type":"assistant"}\n');
    final c = build(initProbe: () async => stream.toString());
    await c.load();
    await c.ensureProbe();
    expect(c.slashCommands, ['clear', 'compact']);
    c.dispose();
  });

  test('malformed settings.json does not sink the load', () async {
    await File('${globalDir.path}/settings.json').writeAsString('{ this is not json');
    await writeSkill(globalDir, 'ok', name: 'ok');
    final c = build();
    await c.load();
    expect(c.settings, isEmpty);
    expect(c.skills.map((s) => s.name), ['ok']);
    c.dispose();
  });

  test('a watcher event refreshes the on-disk view', () async {
    final ctrl = StreamController<void>.broadcast();
    addTearDown(ctrl.close);
    final c = build(watch: (_) => ctrl.stream);
    await c.load();
    expect(c.skills, isEmpty);

    await writeSkill(globalDir, 'late', name: 'late');
    ctrl.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(c.skills.map((s) => s.name), ['late']);
    c.dispose();
  });

  test('setProjectDir swaps the local scope and keeps the global one', () async {
    await writeSkill(globalDir, 'g1', name: 'g1');
    await writeSkill(localDir, 'p1', name: 'p1');
    final c = build();
    await c.load();
    expect(c.skills.map((s) => s.name), ['g1', 'p1']);

    final proj2 = Directory('${tmp.path}/project2')..createSync();
    await writeSkill(Directory('${proj2.path}/.claude'), 'p2', name: 'p2');
    await c.setProjectDir(proj2);

    expect(c.skills.map((s) => s.name), ['g1', 'p2'], reason: 'local scope follows the workspace');
    c.dispose();
  });

  test('explicit refresh re-reads disk without re-resolving the version', () async {
    var versionCalls = 0;
    final c = build(versionRunner: () async {
      versionCalls++;
      return '2.1.150 (Claude Code)\n';
    });
    await c.load();
    expect(versionCalls, 1);

    await writeCommand(globalDir, 'fresh.md');
    await c.refresh();
    expect(c.commands.map((x) => x.name), ['fresh']);
    expect(versionCalls, 1, reason: 'refresh is disk-only');
    c.dispose();
  });

  // T-183: path fields, agents, hooks, MCP servers ------------------------------

  Future<void> writeAgent(Directory scope, String fileName) async {
    final d = Directory('${scope.path}/agents')..createSync(recursive: true);
    await File('${d.path}/$fileName').writeAsString('# agent');
  }

  test('skill and command entries carry their absolute file path (T-183)', () async {
    await writeSkill(globalDir, 'my-skill', name: 'my-skill');
    await writeCommand(globalDir, 'deploy.md');
    final c = build();
    await c.load();

    final skill = c.skills.first;
    expect(skill.path, isNotNull);
    expect(skill.path, endsWith('my-skill/SKILL.md'));

    final cmd = c.commands.first;
    expect(cmd.path, isNotNull);
    expect(cmd.path, endsWith('deploy.md'));
    c.dispose();
  });

  test('agents scanned from <scope>/agents/*.md (T-183)', () async {
    await writeAgent(globalDir, 'planner.md');
    await writeAgent(localDir, 'coder.md');
    final c = build();
    await c.load();

    expect(c.agents.map((a) => a.name), containsAll(['planner', 'coder']));
    final planner = c.agents.firstWhere((a) => a.name == 'planner');
    expect(planner.scope, ConfigScope.global);
    expect(planner.path, isNotNull);
    expect(planner.path, endsWith('planner.md'));
    c.dispose();
  });

  test('agents deduplicated local-over-global same as skills (T-183)', () async {
    await writeAgent(globalDir, 'shared.md');
    await writeAgent(localDir, 'shared.md');
    final c = build();
    await c.load();
    expect(c.agents.where((a) => a.name == 'shared'), hasLength(1));
    final shared = c.agents.firstWhere((a) => a.name == 'shared');
    expect(shared.scope, ConfigScope.local, reason: 'local wins on collision');
    c.dispose();
  });

  test('hooks parsed from settings.json hooks key (T-183)', () async {
    await writeSettings(globalDir, {
      'hooks': {
        'PreToolUse': [
          {
            'hooks': [
              {'command': 'echo pre-tool'},
            ],
          },
        ],
      },
    });
    final c = build();
    await c.load();
    expect(c.hooks, hasLength(1));
    expect(c.hooks.first.event, 'PreToolUse');
    expect(c.hooks.first.commands, ['echo pre-tool']);
    c.dispose();
  });

  test('mcpServers parsed from settings.json mcpServers key (T-183)', () async {
    await writeSettings(globalDir, {
      'mcpServers': {'brave': {}, 'clide': {}},
    });
    final c = build();
    await c.load();
    expect(c.mcpServers.map((s) => s.name), containsAll(['brave', 'clide']));
    c.dispose();
  });

  test('empty settings produce empty hooks and mcpServers (T-183)', () async {
    final c = build();
    await c.load();
    expect(c.agents, isEmpty);
    expect(c.hooks, isEmpty);
    expect(c.mcpServers, isEmpty);
    c.dispose();
  });
}
