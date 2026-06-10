/// The "pick up this ticket" prompt builder (T-327): lead-in, header, meta
/// line, and description, with missing fields omitted gracefully.
library;

import 'package:clide/builtin/tickets/src/pick_up_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('renders the lead-in, header, meta line, and description', () {
    final p = pickUpPrompt({
      'id': 'T-327',
      'title': 'Pick up icon',
      'type': 'story',
      'status': 'ready',
      'priority': 'medium',
      'parent_id': 'T-276',
      'description': 'Do the thing.',
    });
    expect(p, startsWith('Pick up and start working this ticket'));
    expect(p, contains('**T-327 — Pick up icon**'));
    expect(p, contains('story · ready · medium · parent T-276'));
    expect(p, contains('Do the thing.'));
  });

  test('omits the meta line and parent when those fields are absent', () {
    final p = pickUpPrompt({'id': 'T-1', 'title': 'Bare'});
    expect(p, contains('**T-1 — Bare**'));
    expect(p, isNot(contains('·')));
    expect(p, isNot(contains('parent')));
  });

  test('includes the decision ref and assignee when present', () {
    final p = pickUpPrompt({'id': 'T-2', 'title': 'x', 'decision_ref': 'D-90', 'assigned_to': 'jeroen'});
    expect(p, contains('D-90'));
    expect(p, contains('@jeroen'));
  });
}
