/// The in-app confirm for an agent's escalating command (D-115).
library;

import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/daemon/escalation.dart';
import 'package:clide/src/shell/escalation_confirm.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

const _req = EscalationRequest(
  command: 'pane.spawn',
  args: {
    'argv': ['make', 'test'],
    'cwd': '/repo',
    'env': null,
  },
  agent: AgentIdentity(key: 'claude:7', label: 'claude (pid 7)'),
);

void main() {
  test('describes the exact command and every argument', () {
    final text = describeEscalation(_req);
    expect(text.split('\n').first, 'clide pane spawn');
    expect(text, contains('argv: ["make","test"]'));
    expect(text, contains('cwd: /repo'));
    expect(text, isNot(contains('env')), reason: 'absent args are left out');
    expect(
      describeEscalation(const EscalationRequest(command: 'editor.save', args: {}, agent: _agent, reason: 'writes a protected file')),
      contains('(writes a protected file)'),
    );
  });

  group('confirmEscalation', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() => f.dispose());

    Future<EscalationVerdict> pressAndWait(WidgetTester tester, String? label) async {
      await tester.pumpWidget(harness(f, DialogHost(router: f.services.dialog, child: const SizedBox())));
      final verdict = confirmEscalation(f.services.dialog, _req);
      await tester.pump();
      expect(find.text('Allow an agent to run this?'), findsOneWidget);
      expect(find.text('claude (pid 7) wants to run:'), findsOneWidget);
      if (label == null) {
        f.services.dialog.dismiss(); // backdrop tap / escape
      } else {
        await tester.tap(find.text(label));
      }
      await tester.pump();
      return verdict;
    }

    testWidgets('Deny denies', (tester) async {
      expect(await pressAndWait(tester, 'Deny'), EscalationVerdict.deny);
    });

    testWidgets('Allow once allows once', (tester) async {
      expect(await pressAndWait(tester, 'Allow once'), EscalationVerdict.once);
    });

    testWidgets('Allow for this session remembers', (tester) async {
      expect(await pressAndWait(tester, 'Allow for this session'), EscalationVerdict.session);
    });

    testWidgets('dismissing without choosing denies', (tester) async {
      expect(await pressAndWait(tester, null), EscalationVerdict.deny);
    });
  });
}

const _agent = AgentIdentity(key: 'claude:7', label: 'claude (pid 7)');
