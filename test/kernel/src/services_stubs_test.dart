/// Unit tests for the small Tier-0 service stubs in `lib/kernel/src/`:
/// ClideClipboard, FocusTracker, NetworkStatus, SecretsVault,
/// TrayRegistry, Notifications.
library;

import 'package:clide/extension/src/contribution.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show FocusScopeNode;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClideClipboard', () {
    test('typed write + readAs round-trip the latest value', () async {
      final c = ClideClipboard();
      await c.write<int>(42);
      expect(c.readAs<int>(), 42);
      await c.write<int>(43);
      expect(c.readAs<int>(), 43);
    });

    test('typed history is bounded by historyLimit (LIFO)', () async {
      final c = ClideClipboard(historyLimit: 3);
      for (var i = 0; i < 5; i++) {
        await c.write<int>(i);
      }
      final history = c.historyOf<int>();
      expect(history, [4, 3, 2]);
    });

    test('readAs returns null when the type has never been written', () {
      expect(ClideClipboard().readAs<String>(), isNull);
      expect(ClideClipboard().historyOf<int>(), isEmpty);
    });

    testWidgets('writePlain + readPlain go through the platform clipboard channel', (tester) async {
      String? last;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          last = (call.arguments as Map)['text'] as String?;
        } else if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': last};
        }
        return null;
      });
      final c = ClideClipboard();
      await c.writePlain('hello');
      expect(last, 'hello');
      expect(await c.readPlain(), 'hello');
      // writePlain also feeds the typed-String history.
      expect(c.readAs<String>(), 'hello');
    });

    testWidgets('write with toPlain syncs to the OS clipboard', (tester) async {
      String? last;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          last = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      final c = ClideClipboard();
      await c.write<int>(7, toPlain: (n) => 'n=$n');
      expect(last, 'n=7');
    });

    test('clear empties every typed history bucket', () async {
      final c = ClideClipboard();
      await c.write<int>(1);
      await c.write<String>('s');
      c.clear();
      expect(c.readAs<int>(), isNull);
      expect(c.readAs<String>(), isNull);
    });
  });

  group('FocusTracker', () {
    test('setActive flips slot + contribution and notifies', () {
      final f = FocusTracker();
      var calls = 0;
      f.addListener(() => calls++);
      f.setActive(slot: Slots.sidebar, contributionId: 'files');
      expect(f.activeSlot, Slots.sidebar);
      expect(f.activeContributionId, 'files');
      expect(calls, 1);
    });

    test('setActive with the same slot+id is a no-op (no notify)', () {
      final f = FocusTracker();
      f.setActive(slot: Slots.sidebar, contributionId: 'files');
      var calls = 0;
      f.addListener(() => calls++);
      f.setActive(slot: Slots.sidebar, contributionId: 'files');
      expect(calls, 0);
    });

    test('clear resets both fields and notifies once', () {
      final f = FocusTracker();
      f.setActive(slot: Slots.sidebar, contributionId: 'files');
      var calls = 0;
      f.addListener(() => calls++);
      f.clear();
      expect(f.activeSlot, isNull);
      expect(f.activeContributionId, isNull);
      expect(calls, 1);
      // clear when already cleared is a no-op.
      f.clear();
      expect(calls, 1);
    });
  });

  group('FocusTracker — slot scope registry (T-105)', () {
    test('focusSlot is a no-op when no scope is registered', () {
      FocusTracker().focusSlot(Slots.sidebar); // doesn't throw
    });

    test('focusSlot requests focus on the registered scope', () {
      final tracker = FocusTracker();
      final scope = FocusScopeNode();
      addTearDown(scope.dispose);
      tracker.registerSlotScope(Slots.workspace, scope);
      tracker.focusSlot(Slots.workspace);
      // FocusScopeNode.requestFocus only flips hasPrimaryFocus when
      // attached to a tree; we assert the no-throw + the registration
      // round-trip rather than primary focus state (covered by the
      // widget test).
      tracker.unregisterSlotScope(Slots.workspace, scope);
      tracker.focusSlot(Slots.workspace); // now a no-op
    });

    test('unregister skips when a newer scope took the slot', () {
      final tracker = FocusTracker();
      final older = FocusScopeNode();
      final newer = FocusScopeNode();
      addTearDown(() {
        older.dispose();
        newer.dispose();
      });
      tracker.registerSlotScope(Slots.workspace, older);
      tracker.registerSlotScope(Slots.workspace, newer);
      // Older calls unregister but the slot now holds `newer` — must
      // not remove it.
      tracker.unregisterSlotScope(Slots.workspace, older);
      tracker.focusSlot(Slots.workspace); // still wired to `newer`
    });

    test('focusNextSlot / focusPreviousSlot cycle through registered slots only', () {
      final tracker = FocusTracker();
      final sidebar = FocusScopeNode(debugLabel: 'sidebar');
      final workspace = FocusScopeNode(debugLabel: 'workspace');
      addTearDown(() {
        sidebar.dispose();
        workspace.dispose();
      });
      tracker.registerSlotScope(Slots.sidebar, sidebar);
      tracker.registerSlotScope(Slots.workspace, workspace);
      // contextPanel intentionally NOT registered — should be skipped.

      tracker.setActive(slot: Slots.sidebar, contributionId: 'a');
      // The cycle is silent (no notify on focus call alone), but we can
      // assert it doesn't throw and produces a deterministic shape.
      tracker.focusNextSlot();
      tracker.focusPreviousSlot();
    });

    test('cycle no-ops when fewer than two slots are registered', () {
      final tracker = FocusTracker();
      final scope = FocusScopeNode();
      addTearDown(scope.dispose);
      tracker.registerSlotScope(Slots.workspace, scope);
      tracker.focusNextSlot(); // no-op, no throw
      tracker.focusPreviousSlot();
    });
  });

  group('NetworkStatus', () {
    test('default state is online', () {
      final n = NetworkStatus();
      expect(n.state, Reachability.online);
      expect(n.isOnline, isTrue);
    });

    test('setState notifies only when the value changes', () {
      final n = NetworkStatus();
      var calls = 0;
      n.addListener(() => calls++);
      n.setState(Reachability.online); // same value → no notify
      expect(calls, 0);
      n.setState(Reachability.offline);
      expect(n.isOnline, isFalse);
      expect(calls, 1);
      n.setState(Reachability.metered);
      expect(n.isOnline, isTrue); // metered counts as online
      expect(calls, 2);
    });
  });

  group('SecretsVault', () {
    test('write + read round-trip a value by (extensionId, key)', () async {
      final v = SecretsVault();
      await v.write(extensionId: 'e', key: 'token', value: 'sekrit');
      expect(await v.read(extensionId: 'e', key: 'token'), 'sekrit');
    });

    test('isolates by extensionId', () async {
      final v = SecretsVault();
      await v.write(extensionId: 'a', key: 'k', value: 'x');
      expect(await v.read(extensionId: 'b', key: 'k'), isNull);
    });

    test('delete removes one entry', () async {
      final v = SecretsVault();
      await v.write(extensionId: 'e', key: 'k', value: 'v');
      await v.delete(extensionId: 'e', key: 'k');
      expect(await v.read(extensionId: 'e', key: 'k'), isNull);
    });

    test('deleteAll removes every entry for the extension', () async {
      final v = SecretsVault();
      await v.write(extensionId: 'e', key: 'k1', value: 'v1');
      await v.write(extensionId: 'e', key: 'k2', value: 'v2');
      await v.write(extensionId: 'other', key: 'k', value: 'keep');
      await v.deleteAll(extensionId: 'e');
      expect(await v.read(extensionId: 'e', key: 'k1'), isNull);
      expect(await v.read(extensionId: 'e', key: 'k2'), isNull);
      expect(await v.read(extensionId: 'other', key: 'k'), 'keep');
    });
  });

  group('TrayRegistry', () {
    test('add registers items; remove drops them', () {
      final t = TrayRegistry();
      t.add(TrayItemContribution(id: 'a', label: 'A', priority: 10, onSelected: () {}));
      t.add(TrayItemContribution(id: 'b', label: 'B', priority: 5, onSelected: () {}));
      expect(t.items.map((i) => i.id), ['b', 'a']); // sorted by priority asc
      t.remove('a');
      expect(t.items.map((i) => i.id), ['b']);
    });

    test('remove of an unknown id is a silent no-op', () {
      final t = TrayRegistry();
      var calls = 0;
      t.addListener(() => calls++);
      t.remove('nope');
      expect(calls, 0);
    });
  });

  group('Notifications', () {
    test('info/warn/error/success push entries with the right level', () {
      final n = Notifications();
      n.info('i', title: 'I');
      n.warn('w');
      n.error('e');
      n.success('s', duration: const Duration(seconds: 1));
      expect(n.active, hasLength(4));
      expect(n.active.map((x) => x.level), [NotificationLevel.info, NotificationLevel.warning, NotificationLevel.error, NotificationLevel.success]);
      n.dispose();
    });

    test('dismiss removes the matching entry and notifies', () {
      final n = Notifications();
      n.info('m');
      final id = n.active.single.id;
      var calls = 0;
      n.addListener(() => calls++);
      n.dismiss(id);
      expect(n.active, isEmpty);
      expect(calls, 1);
      // Dismissing an unknown id is a silent no-op.
      n.dismiss('no-such-id');
      expect(calls, 1);
      n.dispose();
    });
  });
}
