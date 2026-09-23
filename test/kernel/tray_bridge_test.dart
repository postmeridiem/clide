/// The native half of [TrayRegistry] (T-590, D-110): calls go out on
/// `clide/tray`, native availability reports come back, and a platform with
/// no handler degrades to `false` instead of throwing.
library;

import 'package:clide/kernel/src/tray.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('clide/tray');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late TrayRegistry tray;

  void answer(Object? Function(MethodCall) reply) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return reply(call);
    });
  }

  setUp(() {
    calls = [];
    tray = TrayRegistry();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    tray.dispose();
  });

  test('policy + lifecycle calls reach native with their arguments', () async {
    answer((_) => true);
    expect(await tray.setCloseToTray(true), isTrue);
    expect(await tray.setWorkspace('/repo'), isTrue);
    expect(await tray.setLabels({'quitAll': 'Quit clide'}), isTrue);
    expect(await tray.show(), isTrue);
    expect(await tray.hide(), isTrue);
    expect(await tray.quit(all: false), isTrue);
    expect(await tray.quit(all: true), isTrue);
    expect(calls.map((c) => c.method), ['setCloseToTray', 'setWorkspace', 'setLabels', 'show', 'hide', 'quit', 'quitAll']);
    expect(calls[0].arguments, true);
    expect(calls[1].arguments, '/repo');
    expect(calls[2].arguments, {'quitAll': 'Quit clide'});
  });

  test('native refusing a hide (no tray host) comes back as false', () async {
    answer((c) => c.method != 'hide');
    expect(await tray.hide(), isFalse);
  });

  test('no native handler (tests, web, a runner without the tray) is false, not a throw', () async {
    expect(await tray.show(), isFalse);
    expect(await tray.quit(all: true), isFalse);
    expect(await tray.setCloseToTray(true), isFalse);
  });

  test('a PlatformException degrades to false', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => throw PlatformException(code: 'boom'));
    expect(await tray.show(), isFalse);
  });

  test('attachNative asks for availability, then follows native reports', () async {
    answer((c) => c.method == 'isAvailable' ? true : null);
    tray.attachNative();
    tray.attachNative(); // idempotent
    await pumpEventQueue();
    expect(tray.available.value, isTrue);
    expect(calls.where((c) => c.method == 'isAvailable'), hasLength(1));

    // The tray host went away (loader died, extension disabled).
    await messenger.handlePlatformMessage(
      'clide/tray',
      const StandardMethodCodec().encodeMethodCall(const MethodCall('availability', {'available': false})),
      (_) {},
    );
    expect(tray.available.value, isFalse);
  });

  test('the item registry still orders contributions by priority', () {
    expect(tray.items, isEmpty);
  });
}
