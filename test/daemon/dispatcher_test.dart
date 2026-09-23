/// Unit tests for the daemon's command dispatcher.
library;

import 'dart:async';

import 'package:clide/clide.dart';
import 'package:clide/src/cli/argv_dispatch.dart';
import 'package:clide/src/daemon/escalation.dart';
import 'package:clide/src/ipc/command_schema.dart';
import 'package:test/test.dart';

IpcRequest _req(String cmd, {String id = '1', Map<String, Object?> args = const {}}) {
  return IpcRequest(id: id, cmd: cmd, args: args);
}

void main() {
  group('DaemonDispatcher', () {
    test('ping is registered by default and returns pong + version', () async {
      final d = DaemonDispatcher();
      final r = await d.dispatch(_req('ping'));
      expect(r.ok, isTrue);
      expect(r.data['pong'], isTrue);
      expect(r.data['version'], isNotNull);
      expect(r.data['ts'], isA<String>());
    });

    test('version returns the bundled version string', () async {
      final d = DaemonDispatcher();
      final r = await d.dispatch(_req('version'));
      expect(r.ok, isTrue);
      expect(r.data['version'], clideVersion);
    });

    test('dispatching an unknown command produces a not-found error', () async {
      final d = DaemonDispatcher();
      final r = await d.dispatch(_req('nonsense'));
      expect(r.ok, isFalse);
      expect(r.error?.kind, IpcErrorKind.notFound);
      expect(r.error?.message, contains('unknown command'));
    });

    test('register routes a new handler', () async {
      final d = DaemonDispatcher();
      d.register('echo', risk: const CommandRisk(RiskTier.observe), (req) async {
        return IpcResponse.ok(id: req.id, data: {'echo': req.args['text']});
      });
      final r = await d.dispatch(_req('echo', args: {'text': 'hi'}));
      expect(r.ok, isTrue);
      expect(r.data['echo'], 'hi');
    });

    test('isEmpty is true for a fresh dispatcher (ping + version only)', () {
      final d = DaemonDispatcher();
      expect(d.isEmpty, isTrue);
      d.register(
        'something',
        risk: const CommandRisk(RiskTier.observe),
        (req) async => IpcResponse.ok(id: req.id, data: const {}),
      );
      expect(d.isEmpty, isFalse);
    });

    test('capabilities reflects the live registry with schemas (T-248)', () async {
      final d = DaemonDispatcher();
      d.register(
        'echo',
        risk: const CommandRisk(RiskTier.observe),
        (req) async => IpcResponse.ok(id: req.id, data: const {}),
      );
      d.register(
        'pane.resize',
        (req) async => IpcResponse.ok(id: req.id, data: const {}),
        schema: const CommandSchema(
          positional: ['id', 'cols'],
          args: {
            'id': ArgSpec(required: true),
            'cols': ArgSpec(type: ArgType.number, min: 1),
          },
        ),
      );

      final r = await d.dispatch(_req('capabilities'));
      expect(r.ok, isTrue);
      final commands = r.data['commands'] as Map<String, Object?>;
      // Built-ins + the two just registered are all discoverable.
      expect(commands.keys, containsAll(['ping', 'version', 'capabilities', 'echo', 'pane.resize']));

      // Subsystem/verb split.
      final resize = commands['pane.resize'] as Map<String, Object?>;
      expect(resize['subsystem'], 'pane');
      expect(resize['verb'], 'resize');
      expect(resize['positional'], ['id', 'cols']);
      final args = resize['args'] as Map<String, Object?>;
      expect((args['id'] as Map)['required'], true);
      expect((args['cols'] as Map)['type'], 'number');
      expect((args['cols'] as Map)['min'], 1);

      // A schema-less command carries no positional/args keys.
      final echo = commands['echo'] as Map<String, Object?>;
      expect(echo['subsystem'], '');
      expect(echo.containsKey('args'), isFalse);
    });

    test('mcpTools generates the tool surface from the registry (T-225)', () async {
      final d = DaemonDispatcher();
      d.register(
        'echo',
        risk: const CommandRisk(RiskTier.observe),
        (req) async => IpcResponse.ok(id: req.id, data: const {}),
      );
      d.register(
        'pane.resize',
        (req) async => IpcResponse.ok(id: req.id, data: const {}),
        schema: const CommandSchema(
          positional: ['id', 'cols'],
          args: {
            'id': ArgSpec(required: true),
            'cols': ArgSpec(type: ArgType.number, min: 1),
          },
        ),
      );
      d.register('pane.tail', (req) async => IpcResponse.ok(id: req.id, data: const {}), mcpExpose: false);
      d.register(
        'files.read',
        (req) async => IpcResponse.ok(id: req.id, data: const {}),
        schema: const CommandSchema(
          positional: ['path'],
          args: {
            'path': ArgSpec(pattern: null, allowed: {'a', 'b'}),
            'recursive': ArgSpec(type: ArgType.boolean),
            'globs': ArgSpec(type: ArgType.stringList, maxItems: 5),
          },
        ),
      );

      // Non-const so a RegExp pattern can be supplied (covers the string
      // `pattern` mapping).
      d.register(
        'git.log',
        (req) async => IpcResponse.ok(id: req.id, data: const {}),
        schema: CommandSchema(
          positional: const ['ref'],
          args: {'ref': ArgSpec(pattern: RegExp(r'^\w+$'))},
        ),
      );

      final tools = d.mcpTools();
      final byName = {for (final t in tools) t['name'] as String: t};

      // Tools are prefixed; built-ins + registered commands are present.
      expect(byName.keys, containsAll(['mcp__clide__ping', 'mcp__clide__echo', 'mcp__clide__pane.resize']));
      // The opt-out command is withheld.
      expect(byName.containsKey('mcp__clide__pane.tail'), isFalse);

      // Schema → JSON-Schema inputSchema.
      final resize = byName['mcp__clide__pane.resize']!;
      expect(resize['description'], 'pane: resize');
      final input = resize['inputSchema'] as Map<String, Object?>;
      expect(input['type'], 'object');
      final props = input['properties'] as Map<String, Object?>;
      expect((props['cols'] as Map)['type'], 'number');
      expect((props['cols'] as Map)['minimum'], 1);
      expect(input['required'], ['id']);

      // A schema-less command gets an empty object input with no required.
      final echo = byName['mcp__clide__echo']!;
      final echoInput = echo['inputSchema'] as Map<String, Object?>;
      expect(echoInput['properties'], isEmpty);
      expect(echoInput.containsKey('required'), isFalse);

      // Each ArgType maps to its JSON-Schema shape.
      final readProps = (byName['mcp__clide__files.read']!['inputSchema'] as Map)['properties'] as Map;
      expect((readProps['path'] as Map)['type'], 'string');
      expect((readProps['path'] as Map)['enum'], ['a', 'b']);
      expect((readProps['recursive'] as Map)['type'], 'boolean');
      expect((readProps['globs'] as Map)['type'], 'array');
      expect(((readProps['globs'] as Map)['items'] as Map)['type'], 'string');
      expect((readProps['globs'] as Map)['maxItems'], 5);

      final refProps = (byName['mcp__clide__git.log']!['inputSchema'] as Map)['properties'] as Map;
      expect((refProps['ref'] as Map)['pattern'], r'^\w+$');
    });

    test('mcpTools and mcpCallable leave out escalating verbs and transports (D-115)', () {
      Future<IpcResponse> noop(IpcRequest req) async => IpcResponse.ok(id: req.id, data: const {});
      final d = DaemonDispatcher()
        ..register('git.status', noop)
        ..register('git.push', noop)
        ..register('claude.account', noop)
        ..register('_argv', noop);
      final names = d.mcpTools().map((t) => t['name']).toSet();
      expect(names, contains('mcp__clide__git.status'));
      expect(names, isNot(contains('mcp__clide__git.push')));
      expect(names, isNot(contains('mcp__clide__claude.account')), reason: 'an escalating command stays off even with a read-only action');
      expect(names, isNot(contains('mcp__clide___argv')));
      expect(d.mcpCallable('git.push'), isFalse);
      expect(d.mcpCallable('_argv'), isFalse);
      expect(d.mcpCallable('git.status'), isTrue);
      expect(d.mcpCallable('no.such'), isTrue, reason: 'unknown commands fall through to the dispatcher\'s not-found error');
    });

    test('clear removes user handlers but keeps the built-ins', () async {
      final d = DaemonDispatcher();
      d.register(
        'extra',
        risk: const CommandRisk(RiskTier.observe),
        (req) async => IpcResponse.ok(id: req.id, data: const {}),
      );
      expect(d.isEmpty, isFalse);
      d.clear();
      expect(d.isEmpty, isTrue);
      // ping still works
      final r = await d.dispatch(_req('ping'));
      expect(r.ok, isTrue);
      // 'extra' is gone
      final r2 = await d.dispatch(_req('extra'));
      expect(r2.ok, isFalse);
    });
  });

  // D-115: every command carries a risk tier; none may ship unclassified.
  group('risk tiers (D-115)', () {
    Future<IpcResponse> noop(IpcRequest req) async => IpcResponse.ok(id: req.id, data: const {});

    test('a command with no tier, in the table or given, is refused at registration', () {
      final d = DaemonDispatcher();
      expect(() => d.register('made.up', noop), throwsA(isA<StateError>().having((e) => e.message, 'message', contains('made.up'))));
    });

    test('a tier comes from the table, or from an explicit risk:', () {
      final d = DaemonDispatcher()
        ..register('git.status', noop)
        ..register('made.up', noop, risk: const CommandRisk(RiskTier.display));
      expect(d.riskOf('git.status')!.tier, RiskTier.observe);
      expect(d.riskOf('made.up')!.tier, RiskTier.display);
      expect(d.riskOf('ping')!.tier, RiskTier.observe, reason: 'built-ins are tiered too');
    });

    test('an action argument can pick its own tier', () {
      final risk = commandRiskTiers['claude.account']!;
      expect(risk.tierFor(const {'action': 'list'}), RiskTier.observe);
      expect(risk.tierFor(const {'action': 'set'}), RiskTier.escalate);
      expect(risk.tierFor(const {}), RiskTier.escalate);
    });

    test('capabilities --allow-rules prints the generated agent allow rules', () async {
      final d = DaemonDispatcher();
      // The CLI shape (`clide capabilities --allow-rules`) and the plain arg.
      for (final args in [
        {
          'flags': {'allow-rules': true},
        },
        {'allowRules': true},
      ]) {
        final r = await d.dispatch(IpcRequest(id: '1', cmd: 'capabilities', args: args));
        expect(r.data['allowRules'], agentAllowRules(), reason: '$args');
        expect(r.data.containsKey('commands'), isFalse);
      }
    });

    test('capabilities reports each command\'s tier', () async {
      final d = DaemonDispatcher()
        ..register('git.push', noop)
        ..register('claude.account', noop);
      final caps = (await d.dispatch(_req('capabilities'))).data['commands'] as Map;
      expect((caps['git.push'] as Map)['risk'], 'escalate');
      expect((caps['ping'] as Map)['risk'], 'observe');
      expect((caps['claude.account'] as Map)['risk'], 'escalate');
      expect((caps['claude.account'] as Map)['riskByAction'], {'list': 'observe'});
    });
  });

  // D-115: an escalating command from an agent waits for the user.
  group('escalation confirm (D-115)', () {
    late DaemonDispatcher d;
    late List<EscalationRequest> asked;
    late List<String> ran;
    late EscalationVerdict answer;

    setUp(() {
      asked = [];
      ran = [];
      answer = EscalationVerdict.deny;
      d = DaemonDispatcher();
      for (final cmd in ['git.push', 'git.status', 'files.write', 'claude.account']) {
        d.register(cmd, (req) async {
          ran.add(cmd);
          return IpcResponse.ok(id: req.id, data: const {});
        });
      }
      registerArgvUnwrap(d);
      d.escalationGate = (req) async {
        asked.add(req);
        return answer;
      };
    });

    CallerInfo caller(String? agentKey) => CallerInfo(pid: 42, detector: _FixedDetector(agentKey));
    Future<IpcResponse> call(String cmd, {Map<String, Object?> args = const {}, CallerInfo? from}) =>
        runZoned(() => d.dispatch(_req(cmd, args: args)), zoneValues: {callerZoneKey: from});

    test('an in-app call (no caller) runs without asking', () async {
      expect((await call('git.push')).ok, isTrue);
      expect(asked, isEmpty);
    });

    test('a person at a terminal runs without asking', () async {
      expect((await call('git.push', from: caller(null))).ok, isTrue);
      expect(asked, isEmpty);
    });

    test('an agent is asked, and a deny refuses without running', () async {
      final r = await call('git.push', args: const {'argv': 'x'}, from: caller('claude:7'));
      expect(r.ok, isFalse);
      expect(r.error!.kind, IpcErrorKind.userError);
      expect(r.error!.message, contains('declined'));
      expect(ran, isEmpty);
      expect(asked.single.command, 'git.push');
      expect(asked.single.args['argv'], 'x');
      expect(asked.single.agent.key, 'claude:7');
    });

    test('allow once runs this call only', () async {
      answer = EscalationVerdict.once;
      expect((await call('git.push', from: caller('claude:7'))).ok, isTrue);
      expect((await call('git.push', from: caller('claude:7'))).ok, isTrue);
      expect(asked, hasLength(2));
      expect(ran, ['git.push', 'git.push']);
    });

    test('allow for this session covers the same exact command from the same agent', () async {
      answer = EscalationVerdict.session;
      await call('git.push', args: const {'argv': 'make test'}, from: caller('claude:7'));
      answer = EscalationVerdict.deny;
      expect((await call('git.push', args: const {'argv': 'make test'}, from: caller('claude:7'))).ok, isTrue);
      expect(asked, hasLength(1), reason: 'remembered');
      expect(
        (await call('git.push', args: const {'argv': 'make other'}, from: caller('claude:7'))).ok,
        isFalse,
        reason: 'different args ask again',
      );
      expect(
        (await call('git.push', args: const {'argv': 'make test'}, from: caller('claude:8'))).ok,
        isFalse,
        reason: 'a different agent asks again',
      );
      expect(asked, hasLength(3));
    });

    test('with no confirm available, escalation from an agent is refused', () async {
      d.escalationGate = null;
      final r = await call('git.push', from: caller('claude:7'));
      expect(r.ok, isFalse);
      expect(ran, isEmpty);
    });

    test('a handler-checked command is left to its handler (pane ownership, allowlist)', () async {
      d.register('pane.spawn', (req) async => IpcResponse.ok(id: req.id, data: const {}));
      expect(d.riskOf('pane.spawn')!.handlerChecked, isTrue);
      expect((await call('pane.spawn', from: caller('claude:7'))).ok, isTrue);
      expect(asked, isEmpty, reason: 'pane_commands decides; its tests pin that it asks');
    });

    test('lower tiers from an agent never ask', () async {
      for (final cmd in ['git.status', 'files.write']) {
        expect((await call(cmd, from: caller('claude:7'))).ok, isTrue, reason: cmd);
      }
      expect(asked, isEmpty);
    });

    test('the action picks the tier: list reads freely, set asks', () async {
      expect((await call('claude.account', args: const {'action': 'list'}, from: caller('claude:7'))).ok, isTrue);
      expect(asked, isEmpty);
      expect((await call('claude.account', args: const {'action': 'set'}, from: caller('claude:7'))).ok, isFalse);
      expect(asked, hasLength(1));
    });

    test('the argv transport carries the caller into the inner command', () async {
      final r = await call(
        '_argv',
        args: const {
          'argv': ['git', 'push'],
        },
        from: caller('claude:7'),
      );
      expect(r.ok, isFalse);
      expect(asked.single.command, 'git.push');
      expect(ran, isEmpty);
    });

    test('checkEscalation lets a handler escalate a call its tier would not', () async {
      d.register('editor.save', (req) async {
        final refusal = await d.checkEscalation(req, reason: 'writes a protected file');
        if (refusal != null) return refusal;
        ran.add('editor.save');
        return IpcResponse.ok(id: req.id, data: const {});
      });
      expect((await call('editor.save', from: caller('claude:7'))).ok, isFalse);
      expect(asked.single.reason, 'writes a protected file');
      expect((await call('editor.save')).ok, isTrue, reason: 'the user saving in the app is never asked');
    });
  });
}

class _FixedDetector implements AgentDetector {
  _FixedDetector(this.key);
  final String? key;

  @override
  Future<AgentIdentity?> agentOf(int? pid) async => key == null ? null : AgentIdentity(key: key!, label: key!);
}
