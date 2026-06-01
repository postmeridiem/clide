/// Unit tests for the retained right-pane nav history (T-196).
///
/// [ReaderNav] records selections (even before the reader mounts), holds
/// browser-style back/forward history, exposes the latest as [current]
/// for grab-on-mount, and re-emits every navigation on the `load`
/// channel so the reader has a single load path.
library;

import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:clide/kernel/src/reader_nav.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MessageBus bus;
  late ReaderNav nav;
  late List<String> loads;

  setUp(() {
    bus = MessageBus();
    nav = ReaderNav(messages: bus, publisherId: 'builtin.decisions', dataKey: 'id');
    loads = [];
    bus.subscribe(publisher: 'builtin.decisions', channel: 'load').listen((m) {
      final id = m.data['id'];
      if (id is String) loads.add(id);
    });
  });
  tearDown(() {
    nav.dispose();
    bus.dispose();
  });

  // Let the broadcast bus deliver.
  Future<void> tick() => Future<void>.delayed(Duration.zero);

  test('starts empty', () {
    expect(nav.current, isNull);
    expect(nav.canGoBack, isFalse);
    expect(nav.canGoForward, isFalse);
    expect(nav.hasPinned, isFalse);
  });

  test('open records the entry, sets current, and emits a load', () async {
    nav.open('D-1');
    expect(nav.current, 'D-1');
    expect(nav.canGoBack, isFalse);
    await tick();
    expect(loads, ['D-1']);
  });

  test('a selection on the bus is recorded (retained) and emits a load', () async {
    bus.publish('builtin.decisions', 'selection', {'id': 'D-9'});
    await tick();
    expect(nav.current, 'D-9');
    expect(loads, ['D-9']);
  });

  test('two opens enable back; back re-emits the prior entry', () async {
    nav.open('D-1');
    nav.open('D-2');
    expect(nav.canGoBack, isTrue);
    expect(nav.canGoForward, isFalse);
    nav.back();
    expect(nav.current, 'D-1');
    expect(nav.canGoForward, isTrue);
    await tick();
    expect(loads, ['D-1', 'D-2', 'D-1']);
  });

  test('forward after back re-emits the later entry', () async {
    nav.open('D-1');
    nav.open('D-2');
    nav.back();
    nav.forward();
    expect(nav.current, 'D-2');
  });

  test('back at start / forward at end are no-ops', () async {
    nav.open('D-1');
    nav.back(); // canGoBack false → no-op
    nav.forward(); // canGoForward false → no-op
    await tick();
    expect(loads, ['D-1']); // only the open emitted
    expect(nav.current, 'D-1');
  });

  test('a new open truncates forward history', () {
    nav.open('D-1');
    nav.open('D-2');
    nav.open('D-3');
    nav.back(); // D-2
    nav.back(); // D-1
    nav.open('D-9'); // truncates D-2/D-3
    expect(nav.current, 'D-9');
    expect(nav.canGoForward, isFalse);
    expect(nav.canGoBack, isTrue);
  });

  test('opening the current entry again re-emits but does not push', () async {
    nav.open('D-1');
    nav.open('D-1');
    expect(nav.canGoBack, isFalse); // no duplicate pushed
    await tick();
    expect(loads, ['D-1', 'D-1']); // but both re-emit a load
  });

  test('pin + jumpToPin returns to the pinned entry and re-emits', () async {
    nav.open('D-1');
    nav.pin();
    expect(nav.hasPinned, isTrue);
    nav.open('D-2');
    nav.open('D-3');
    nav.jumpToPin();
    expect(nav.current, 'D-1');
    await tick();
    expect(loads.last, 'D-1');
  });

  test('togglePin pins the current entry, then clears it', () {
    nav.open('D-1');
    expect(nav.hasPinned, isFalse);
    nav.togglePin();
    expect(nav.hasPinned, isTrue);
    nav.togglePin();
    expect(nav.hasPinned, isFalse);
  });

  test('pin replaces the previous pin', () {
    nav.open('D-1');
    nav.pin();
    nav.open('D-2');
    nav.pin(); // replaces
    nav.open('D-3');
    nav.jumpToPin();
    expect(nav.current, 'D-2');
  });

  test('registry retains one nav per reader id', () {
    final reg = ReaderNavRegistry(bus);
    addTearDown(reg.dispose);
    final a = reg.navFor('builtin.markdown', dataKey: 'path');
    final b = reg.navFor('builtin.markdown', dataKey: 'path');
    expect(identical(a, b), isTrue);
    final c = reg.navFor('builtin.decisions', dataKey: 'id');
    expect(identical(a, c), isFalse);
  });
}
