/// Tests for FocusTracker's status-widget slot (T-150).
library;

import 'package:clide/kernel/src/focus.dart';
import 'package:clide/kernel/src/panels/slot_id.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FocusTracker status widget', () {
    test('setStatusWidget applies only for the focused contribution', () {
      final f = FocusTracker();
      f.setActive(slot: Slots.workspace, contributionId: 'a');
      const wa = SizedBox(key: ValueKey('a'));
      f.setStatusWidget('a', wa);
      expect(f.activeStatusWidget, wa);

      // A background contribution's update is ignored.
      f.setStatusWidget('b', const SizedBox(key: ValueKey('b')));
      expect(f.activeStatusWidget, wa);
    });

    test('a focus change clears the previous status widget', () {
      final f = FocusTracker();
      f.setActive(slot: Slots.workspace, contributionId: 'a');
      f.setStatusWidget('a', const SizedBox());
      expect(f.activeStatusWidget, isNotNull);

      f.setActive(slot: Slots.workspace, contributionId: 'b');
      expect(f.activeStatusWidget, isNull);
    });

    test('clear() resets focus and status', () {
      final f = FocusTracker();
      f.setActive(slot: Slots.workspace, contributionId: 'a');
      f.setStatusWidget('a', const SizedBox());
      f.clear();
      expect(f.activeContributionId, isNull);
      expect(f.activeStatusWidget, isNull);
    });

    test('setStatusWidget notifies on change, not on a repeat', () {
      final f = FocusTracker();
      f.setActive(slot: Slots.workspace, contributionId: 'a');
      var n = 0;
      f.addListener(() => n++);
      const w = SizedBox();
      f.setStatusWidget('a', w);
      expect(n, 1);
      f.setStatusWidget('a', w); // identical → no notify
      expect(n, 1);
    });
  });
}
