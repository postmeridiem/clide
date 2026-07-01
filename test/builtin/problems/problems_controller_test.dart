import 'package:clide/builtin/problems/src/problems_controller.dart';
import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/env/supporter_binaries.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_ipc.dart';

void main() {
  group('supporterToolProblems', () {
    test('flags a stale supporter-binary pin', () {
      final tools = SupporterBinaries(overrides: {'d2': '/gone/d2'}, exists: (_) => false);
      final ps = supporterToolProblems(tools);
      expect(ps.single.source, 'tools');
      expect(ps.single.message, contains('d2'));
      expect(ps.single.hint, isNotNull);
    });

    test('no problem when the configured path resolves', () {
      expect(supporterToolProblems(SupporterBinaries(overrides: {'d2': '/ok'}, exists: {'/ok'}.contains)), isEmpty);
    });

    test('no problem with no override or no resolver', () {
      expect(supporterToolProblems(SupporterBinaries(exists: (_) => false)), isEmpty);
      expect(supporterToolProblems(null), isEmpty);
    });
  });

  group('ProblemsController.refresh', () {
    late FakeDaemonClient ipc;
    SupporterBinaries? saved;

    setUp(() {
      saved = activeSupporterBinaries;
      activeSupporterBinaries = null; // isolate from supporter-tool problems
      ipc = FakeDaemonClient(log: Logger(), events: DaemonBus());
    });
    tearDown(() => activeSupporterBinaries = saved);

    IpcResponse ok(Map<String, Object?> data) => IpcResponse.ok(id: '1', data: data);

    test('a clean doctor + sync yields no problems', () async {
      ipc.stub(
        'pql.doctor',
        (_) async => ok({
          'db': {'exists': true},
          'skill': {
            'project': {'state': 'ok'},
          },
        }),
      );
      ipc.stub('pql.decisions.sync', (_) async => ok({'broken': 0}));
      final c = ProblemsController(ipc: ipc);
      var notified = 0;
      c.addListener(() => notified++);
      await c.refresh();
      expect(c.problems, isEmpty);
      expect(c.loading, isFalse);
      expect(c.error, isNull);
      expect(notified, greaterThan(0)); // loading toggled + final
    });

    test('flags a missing db, a stale skill, and broken refs', () async {
      ipc.stub(
        'pql.doctor',
        (_) async => ok({
          'db': {'exists': false},
          'skill': {
            'project': {'state': 'stale'},
          },
        }),
      );
      ipc.stub('pql.decisions.sync', (_) async => ok({'broken': 2}));
      final c = ProblemsController(ipc: ipc);
      await c.refresh();
      final msgs = c.problems.map((p) => p.message).join('\n');
      expect(c.problems.map((p) => p.source), containsAll(['pql', 'decisions']));
      expect(msgs, contains('not found'));
      expect(msgs, contains('stale'));
      expect(msgs, contains('broken'));
    });

    test('a missing skill is flagged with the install hint', () async {
      ipc.stub(
        'pql.doctor',
        (_) async => ok({
          'db': {'exists': true},
          'skill': {
            'project': {'state': 'missing'},
          },
        }),
      );
      ipc.stub('pql.decisions.sync', (_) async => ok({'broken': 0}));
      final c = ProblemsController(ipc: ipc);
      await c.refresh();
      expect(c.problems.any((p) => p.message.contains('not installed')), isTrue);
    });

    test('a failed doctor surfaces as a problem', () async {
      ipc.stub(
        'pql.doctor',
        (_) async => IpcResponse.err(
          id: '1',
          error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'boom'),
        ),
      );
      ipc.stub('pql.decisions.sync', (_) async => ok({'broken': 0}));
      final c = ProblemsController(ipc: ipc);
      await c.refresh();
      expect(c.problems.any((p) => p.message.contains('doctor failed')), isTrue);
    });
  });
}
