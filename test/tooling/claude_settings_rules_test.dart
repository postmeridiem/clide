/// The committed `.claude/settings.json` pre-approves exactly the clide verbs
/// the risk tiers pre-approve (D-115) — no blanket `Bash(clide *)`, and no
/// hand-kept list to drift from what clide enforces. Anyone who clones this
/// public repo and runs Claude Code in it gets these rules.
library;

import 'dart:convert';
import 'dart:io';

import 'package:clide/src/daemon/risk_tiers.dart';
import 'package:test/test.dart';

void main() {
  test('the committed clide allow rules are the generated tier rules', () {
    final settings = jsonDecode(File('.claude/settings.json').readAsStringSync()) as Map<String, Object?>;
    final allow = ((settings['permissions'] as Map)['allow'] as List).cast<String>();
    final clide = allow.where((r) => r.startsWith('Bash(clide')).toList();
    expect(clide, agentAllowRules(), reason: 'regenerate the clide entries from agentAllowRules() — `clide capabilities` reports each tier');
  });
}
