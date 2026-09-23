/// The agent allow rules generated from the risk tiers (D-115).
library;

import 'package:clide/src/daemon/risk_tiers.dart';
import 'package:test/test.dart';

void main() {
  group('agentAllowRules (D-115)', () {
    final rules = agentAllowRules();

    test('pre-approves observe and display verbs, in their CLI spelling', () {
      expect(rules, contains('Bash(clide git status:*)'));
      expect(rules, contains('Bash(clide ui toast:*)'));
      expect(rules, contains('Bash(clide pql decisions.list:*)'), reason: 'the first dot splits subsystem from verb');
      expect(rules, contains('Bash(clide capabilities:*)'), reason: 'umbrella commands have no verb');
    });

    test('never pre-approves workspace-write or escalate verbs', () {
      for (final cmd in ['files.write', 'git.commit', 'git.push', 'pane.spawn', 'pane.write', 'app.update', 'clipboard.history']) {
        final prefix = cmd.contains('.') ? 'clide ${cmd.replaceFirst('.', ' ')}' : 'clide $cmd';
        expect(rules.where((r) => r.startsWith('Bash($prefix')), isEmpty, reason: cmd);
      }
      expect(rules, isNot(contains('Bash(clide:*)')), reason: 'the blanket rule is gone');
    });

    test('a pre-approved action of an escalating command gets its own rule', () {
      expect(rules, contains('Bash(clide claude account list:*)'));
      expect(rules, contains('Bash(clide env path list:*)'));
      expect(rules.where((r) => r.startsWith('Bash(clide claude account') && !r.contains(' list:')), isEmpty);
    });

    test('covers the server- and client-side reads, and skips the transport sentinel', () {
      expect(rules, containsAll(['Bash(clide tail:*)', 'Bash(clide events:*)', 'Bash(clide instances:*)']));
      expect(rules.where((r) => r.contains('_argv')), isEmpty);
    });

    test('is sorted and duplicate-free', () {
      expect(rules, [...rules]..sort());
      expect(rules.toSet(), hasLength(rules.length));
    });

    test('rides on --allowedTools as one comma-joined argument', () {
      final args = agentAllowedToolsArgs();
      expect(args, hasLength(2));
      expect(args.first, '--allowedTools');
      expect(args.last.split(','), rules);
    });
  });
}
