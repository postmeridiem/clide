/// Unit tests for ToastService (T-50): MessageBus consumption, queueing,
/// the visible cap, manual dismiss, clear, and per-severity auto-dismiss.
///
/// Timer-driven cases run under testWidgets so flutter_test's fake clock
/// fires the Timers on `tester.pump(duration)` — no `fake_async` dependency.
library;

import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:clide/kernel/src/toast.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A service wired to a fresh bus; both torn down.
  (ToastService, MessageBus) make({int maxVisible = 4}) {
    final bus = MessageBus();
    final t = ToastService(messages: bus, maxVisible: maxVisible);
    addTearDown(t.dispose);
    addTearDown(bus.dispose);
    return (t, bus);
  }

  group('ToastService — MessageBus consumption', () {
    test('shows a toast for each message published to the toast channel', () async {
      final (t, bus) = make();
      publishToast(bus, 'builtin.git', 'Pushed to origin/main', severity: ToastSeverity.success, duration: Duration.zero);
      await pumpEventQueue(); // let the broadcast stream deliver
      expect(t.entries.single.message, 'Pushed to origin/main');
      expect(t.entries.single.severity, ToastSeverity.success);
    });

    test('ignores messages without a string "message" payload', () async {
      final (t, bus) = make();
      bus.publish('x', toastChannel, {'severity': 'error'}); // no message
      bus.publish('x', 'other-channel', {'message': 'nope'}); // wrong channel
      await pumpEventQueue();
      expect(t.entries, isEmpty);
    });

    test('parses severity by name and defaults unknown to info', () async {
      final (t, bus) = make();
      bus.publish('x', toastChannel, {'message': 'a', 'severity': 'warning', 'durationMs': 0});
      bus.publish('x', toastChannel, {'message': 'b', 'severity': 'bogus', 'durationMs': 0});
      await pumpEventQueue();
      expect(t.entries.map((e) => e.severity), [ToastSeverity.warning, ToastSeverity.info]);
    });
  });

  group('ToastService — queue', () {
    test('show appends entries with monotonic ids and the given severity', () {
      final (t, _) = make();
      final a = t.show('hello', duration: Duration.zero);
      final b = t.show('there', severity: ToastSeverity.error, duration: Duration.zero);
      expect(a, isNot(b));
      expect(t.entries.map((e) => e.message), ['hello', 'there']);
      expect(t.entries.first.severity, ToastSeverity.info); // default
      expect(t.entries.last.severity, ToastSeverity.error);
    });

    test('caps the visible count, dropping the oldest', () {
      final (t, _) = make(maxVisible: 2);
      t.show('1', duration: Duration.zero);
      t.show('2', duration: Duration.zero);
      t.show('3', duration: Duration.zero);
      expect(t.entries.map((e) => e.message), ['2', '3']);
    });

    test('dismiss removes by id and is a no-op for unknown ids', () {
      final (t, _) = make();
      final id = t.show('x', duration: Duration.zero);
      var fired = 0;
      t.addListener(() => fired++);
      t.dismiss(99999); // unknown → no notify
      expect(fired, 0);
      t.dismiss(id);
      expect(t.entries, isEmpty);
      expect(fired, 1);
    });

    test('clear drops everything (and only notifies when non-empty)', () {
      final (t, _) = make();
      var fired = 0;
      t.addListener(() => fired++);
      t.clear(); // already empty → no notify
      expect(fired, 0);
      t.show('a', duration: Duration.zero);
      t.show('b', duration: Duration.zero);
      fired = 0;
      t.clear();
      expect(t.entries, isEmpty);
      expect(fired, 1);
    });
  });

  group('ToastService — auto-dismiss timers', () {
    testWidgets('fires after the default duration; errors linger longer', (tester) async {
      final (t, _) = make();
      await tester.pumpWidget(const SizedBox());
      t.show('info');
      t.show('boom', severity: ToastSeverity.error);
      await tester.pump(const Duration(seconds: 3, milliseconds: 900));
      expect(t.entries.length, 2);
      await tester.pump(const Duration(milliseconds: 200)); // past 4s
      expect(t.entries.map((e) => e.message), ['boom']);
      await tester.pump(const Duration(seconds: 4)); // past 8s
      expect(t.entries, isEmpty);
    });

    testWidgets('a zero/sticky duration never auto-dismisses', (tester) async {
      final (t, _) = make();
      await tester.pumpWidget(const SizedBox());
      t.show('sticky', duration: Duration.zero);
      await tester.pump(const Duration(minutes: 5));
      expect(t.entries.length, 1);
    });

    testWidgets('dispose cancels pending timers (no lingering callbacks)', (tester) async {
      final bus = MessageBus();
      addTearDown(bus.dispose);
      final t = ToastService(messages: bus);
      await tester.pumpWidget(const SizedBox());
      t.show('x');
      t.dispose();
      await tester.pump(const Duration(seconds: 10)); // cancelled timer must not fire
    });
  });
}
