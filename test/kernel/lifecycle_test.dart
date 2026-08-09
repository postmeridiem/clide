import 'package:clide/kernel/src/lifecycle.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Registers a WidgetsBindingObserver, so there has to be a binding — plain
  // `test` does not create one.
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLifecycle lifecycle;

  setUp(() => lifecycle = AppLifecycle()..start());
  tearDown(() => lifecycle.dispose());

  group('visibility', () {
    test('starts visible', () {
      // A window is on screen when it boots. Assuming otherwise would leave
      // every consumer suspended until a transition that, on a window nobody
      // minimises, never arrives.
      expect(lifecycle.visible, isTrue);
      expect(lifecycle.state, AppLifecycleState.resumed);
    });

    test('hidden and paused are not visible', () {
      for (final state in const [AppLifecycleState.hidden, AppLifecycleState.paused, AppLifecycleState.detached]) {
        lifecycle.didChangeAppLifecycleState(state);
        expect(lifecycle.visible, isFalse, reason: '$state should not count as visible');
      }
    });

    test('inactive IS visible — the load-bearing case', () {
      // On desktop, clicking another application makes clide `inactive` while
      // it stays fully on screen beside it. Treating that as hidden would
      // freeze a window the user is looking straight at, which is a worse
      // defect than the one suspension exists to fix.
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(lifecycle.visible, isTrue);
    });

    test('resuming makes it visible again', () {
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.hidden);
      expect(lifecycle.visible, isFalse);
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(lifecycle.visible, isTrue);
    });
  });

  group('notification', () {
    test('notifies on a real change', () {
      var notified = 0;
      lifecycle.addListener(() => notified++);
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.hidden);
      expect(notified, 1);
    });

    test('does not notify when the state repeats', () {
      // The platform is free to report the same state twice; consumers rebuild
      // on notification and should not be woken for nothing.
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.hidden);
      var notified = 0;
      lifecycle.addListener(() => notified++);
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.hidden);
      expect(notified, 0);
    });
  });

  group('lifecycle of the observer itself', () {
    test('start is idempotent', () {
      // Registering twice would deliver every transition twice.
      lifecycle.start();
      lifecycle.start();
      var notified = 0;
      lifecycle.addListener(() => notified++);
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.hidden);
      expect(notified, 1);
    });

    test('disposing detaches from the binding', () {
      final other = AppLifecycle()..start();
      other.dispose();
      // Would throw if the observer were still registered on a disposed
      // notifier.
      WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  });
}
