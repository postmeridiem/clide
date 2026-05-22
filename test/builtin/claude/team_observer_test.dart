/// Tests for the tmux team observer (T-139). Pure Dart (no Flutter):
/// config parsing/discovery, the config-driven born/died lifecycle, and
/// the best-effort subagent-transcript join — all exercised against
/// on-disk fixtures, mirroring how the T-134 spike validated CC's
/// undocumented team artifacts.
library;

import 'dart:convert';
import 'dart:io';

import 'package:clide/builtin/claude/src/team_observer.dart';
import 'package:clide/kernel/src/events/bus.dart';
import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:clide/kernel/src/events/types.dart';
import 'package:test/test.dart';

const _ws = '/work/space';

String _configJson({
  String team = 'myteam',
  int createdAt = 1000,
  String leadSessionId = 'sid-1',
  String cwd = _ws,
  List<Map<String, dynamic>> teammates = const [],
}) {
  return jsonEncode({
    'name': team,
    'createdAt': createdAt,
    'leadSessionId': leadSessionId,
    'members': [
      {'agentId': 'team-lead@$team', 'name': 'team-lead', 'agentType': 'team-lead', 'tmuxPaneId': '', 'cwd': cwd, 'joinedAt': 1},
      ...teammates,
    ],
  });
}

Map<String, dynamic> _member(String name, String pane, {String? type, int joinedAt = 2, String cwd = _ws}) => {
      'agentId': '$name@myteam',
      'name': name,
      'agentType': type ?? name,
      'tmuxPaneId': pane,
      'model': 'sonnet',
      'color': 'blue',
      'cwd': cwd,
      'joinedAt': joinedAt,
    };

Future<Directory> _writeTeam(Directory teamsBase, String team, String json) async {
  final dir = Directory('${teamsBase.path}/$team');
  await dir.create(recursive: true);
  await File('${dir.path}/config.json').writeAsString(json);
  return dir;
}

void main() {
  group('team events', () {
    test('TeamMemberBorn payload carries identity + optional fields', () {
      const e = TeamMemberBorn(
        team: 'myteam',
        agentId: 'alice@myteam',
        name: 'alice',
        agentType: 'researcher',
        paneId: '%5',
        model: 'sonnet',
        color: 'blue',
        cwd: '/work/space',
        transcriptPath: '/t/agent-a.jsonl',
      );
      expect(e.subsystem, 'team');
      expect(e.kind, 'member-born');
      expect(e.payload(), {
        'team': 'myteam',
        'agentId': 'alice@myteam',
        'name': 'alice',
        'agentType': 'researcher',
        'paneId': '%5',
        'model': 'sonnet',
        'color': 'blue',
        'cwd': '/work/space',
        'transcriptPath': '/t/agent-a.jsonl',
      });
    });

    test('TeamMemberBorn omits null optional fields', () {
      const e = TeamMemberBorn(team: 't', agentId: 'a@t', name: 'a', agentType: 'a', paneId: '%1');
      expect(e.payload().keys, ['team', 'agentId', 'name', 'agentType', 'paneId']);
    });

    test('TeamMemberDied payload', () {
      const e = TeamMemberDied(team: 't', agentId: 'a@t', paneId: '%1');
      expect(e.subsystem, 'team');
      expect(e.kind, 'member-died');
      expect(e.payload(), {'team': 't', 'agentId': 'a@t', 'paneId': '%1'});
    });
  });

  group('TeamConfig.parse', () {
    test('parses members and detects the lead', () {
      final cfg = TeamConfig.parse('myteam', _configJson(teammates: [_member('alice', '%5')]))!;
      expect(cfg.team, 'myteam');
      expect(cfg.leadSessionId, 'sid-1');
      expect(cfg.members, hasLength(2));
      expect(cfg.teammates.map((m) => m.name), ['alice']);
      final lead = cfg.members.firstWhere((m) => m.isLead);
      expect(lead.name, 'team-lead');
      final alice = cfg.teammates.single;
      expect(alice.tmuxPaneId, '%5');
      expect(alice.model, 'sonnet');
      expect(alice.isLead, isFalse);
    });

    test('returns null on malformed JSON', () {
      expect(TeamConfig.parse('x', 'not json'), isNull);
    });
  });

  group('discoverTeam', () {
    late Directory teamsBase;
    setUp(() async => teamsBase = await Directory.systemTemp.createTemp('teams_'));
    tearDown(() async => teamsBase.delete(recursive: true));

    test('finds the team whose member cwd matches the workspace', () async {
      await _writeTeam(teamsBase, 'other', _configJson(team: 'other', cwd: '/elsewhere', teammates: [_member('bob', '%9', cwd: '/elsewhere')]));
      await _writeTeam(teamsBase, 'mine', _configJson(team: 'mine', teammates: [_member('alice', '%5')]));
      final cfg = await discoverTeam(_ws, teamsBase: teamsBase.path);
      expect(cfg, isNotNull);
      expect(cfg!.team, 'mine');
    });

    test('prefers the newest createdAt when several match', () async {
      await _writeTeam(teamsBase, 'old', _configJson(team: 'old', createdAt: 100, teammates: [_member('a', '%1')]));
      await _writeTeam(teamsBase, 'new', _configJson(team: 'new', createdAt: 999, teammates: [_member('b', '%2')]));
      final cfg = await discoverTeam(_ws, teamsBase: teamsBase.path);
      expect(cfg!.team, 'new');
    });

    test('returns null when nothing matches', () async {
      await _writeTeam(teamsBase, 'other', _configJson(team: 'other', cwd: '/elsewhere', teammates: [_member('bob', '%9', cwd: '/elsewhere')]));
      expect(await discoverTeam(_ws, teamsBase: teamsBase.path), isNull);
    });
  });

  group('TeamObserver lifecycle', () {
    late Directory teamsBase;
    late Directory projectsBase;
    late DaemonBus events;
    late MessageBus messages;
    late List<TeamMemberBorn> born;
    late List<TeamMemberDied> died;

    setUp(() async {
      teamsBase = await Directory.systemTemp.createTemp('teams_');
      projectsBase = await Directory.systemTemp.createTemp('projects_');
      events = DaemonBus();
      messages = MessageBus();
      born = [];
      died = [];
      events.on<TeamMemberBorn>().listen(born.add);
      events.on<TeamMemberDied>().listen(died.add);
    });

    tearDown(() async {
      await teamsBase.delete(recursive: true);
      await projectsBase.delete(recursive: true);
      await events.dispose();
      messages.dispose();
    });

    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

    test('emits born when a teammate pane is live, died when it goes', () async {
      await _writeTeam(teamsBase, 'myteam', _configJson(teammates: [_member('alice', '%5')]));
      var panes = {'%5'};
      final obs = TeamObserver(
        workspacePath: _ws,
        events: events,
        messages: messages,
        teamsBase: teamsBase.path,
        projectsBase: projectsBase.path,
        paneLister: () async => panes,
      );
      addTearDown(obs.dispose);

      await obs.tick();
      await settle();
      expect(born.map((b) => b.name), ['alice']);
      expect(born.single.paneId, '%5');
      expect(born.single.agentId, 'alice@myteam');
      expect(died, isEmpty);

      // Same pane still live -> no duplicate born.
      await obs.tick();
      await settle();
      expect(born, hasLength(1));

      // Pane gone -> died.
      panes = {};
      await obs.tick();
      await settle();
      expect(died.map((d) => d.agentId), ['alice@myteam']);
    });

    test('start() polls on a timer and dispose() stops it', () async {
      await _writeTeam(teamsBase, 'myteam', _configJson(teammates: [_member('alice', '%5')]));
      final obs = TeamObserver(
        workspacePath: _ws,
        events: events,
        messages: messages,
        teamsBase: teamsBase.path,
        projectsBase: projectsBase.path,
        paneLister: () async => {'%5'},
        pollInterval: const Duration(milliseconds: 20),
      );
      obs.start();
      // Poll until the timer-driven tick emits born (or time out).
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (born.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(born.map((b) => b.name), ['alice']);
      await obs.dispose();
      // dispose emits died for the tracked member.
      await settle();
      expect(died.map((d) => d.agentId), ['alice@myteam']);
    });

    test('constructs with default base dirs / pane lister', () {
      // Exercises the default resolvers; not started, so nothing shells out.
      final obs = TeamObserver(workspacePath: _ws, events: events, messages: messages);
      expect(obs.workspacePath, _ws);
    });

    test('no team config -> no events', () async {
      final obs = TeamObserver(
        workspacePath: _ws,
        events: events,
        messages: messages,
        teamsBase: teamsBase.path,
        projectsBase: projectsBase.path,
        paneLister: () async => {'%5'},
      );
      addTearDown(obs.dispose);
      await obs.tick();
      await settle();
      expect(born, isEmpty);
      expect(died, isEmpty);
    });

    test('joins the teammate transcript via a matching .meta.json', () async {
      await _writeTeam(teamsBase, 'myteam', _configJson(teammates: [_member('alice', '%5', type: 'researcher')]));
      // <projectsBase>/<munged cwd>/<leadSessionId>/subagents/agent-*.jsonl
      final sub = Directory('${projectsBase.path}/${_ws.replaceAll('/', '-')}/sid-1/subagents');
      await sub.create(recursive: true);
      await File('${sub.path}/agent-aaa111.jsonl').writeAsString('');
      await File('${sub.path}/agent-aaa111.meta.json').writeAsString(jsonEncode({'agentType': 'researcher'}));

      final obs = TeamObserver(
        workspacePath: _ws,
        events: events,
        messages: messages,
        teamsBase: teamsBase.path,
        projectsBase: projectsBase.path,
        paneLister: () async => {'%5'},
      );
      addTearDown(obs.dispose);

      await obs.tick();
      await settle();
      expect(born.single.transcriptPath, endsWith('agent-aaa111.jsonl'));
    });

    test('falls back to joinedAt<->mtime order when no .meta.json', () async {
      await _writeTeam(
        teamsBase,
        'myteam',
        _configJson(teammates: [
          _member('first', '%5', joinedAt: 10),
          _member('second', '%6', joinedAt: 20),
        ]),
      );
      final sub = Directory('${projectsBase.path}/${_ws.replaceAll('/', '-')}/sid-1/subagents');
      await sub.create(recursive: true);
      // Older file first (earlier mtime) -> maps to the earlier-joined member.
      final older = File('${sub.path}/agent-older.jsonl');
      await older.writeAsString('');
      await older.setLastModified(DateTime(2026, 1, 1));
      final newer = File('${sub.path}/agent-newer.jsonl');
      await newer.writeAsString('');
      await newer.setLastModified(DateTime(2026, 2, 1));

      final obs = TeamObserver(
        workspacePath: _ws,
        events: events,
        messages: messages,
        teamsBase: teamsBase.path,
        projectsBase: projectsBase.path,
        paneLister: () async => {'%5', '%6'},
      );
      addTearDown(obs.dispose);

      await obs.tick();
      await settle();
      final byName = {for (final b in born) b.name: b.transcriptPath};
      expect(byName['first'], endsWith('agent-older.jsonl'));
      expect(byName['second'], endsWith('agent-newer.jsonl'));
    });
  });
}
