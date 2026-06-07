/// Tests for [FilterStateCache] — the observe-half backing store for
/// `clide ui filter` (T-270). It listens on the MessageBus `filter.state`
/// channel and remembers the latest value per address.
library;

import 'package:clide/kernel/src/events/filter_state.dart';
import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:test/test.dart';

void main() {
  late MessageBus bus;
  late FilterStateCache cache;

  setUp(() {
    bus = MessageBus();
    cache = FilterStateCache(messages: bus);
  });

  tearDown(() {
    cache.dispose();
    bus.dispose();
  });

  // Bus delivery is async (broadcast stream), so settle a turn after publish.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('returns null for an address that never reported', () {
    expect(cache.get('decisions.panel'), isNull);
  });

  test('remembers the latest filter.state value per address', () async {
    bus.publish('decisions.panel', 'filter.state', {'query': 'git'});
    await settle();
    expect(cache.get('decisions.panel'), 'git');

    bus.publish('decisions.panel', 'filter.state', {'query': 'pql'});
    await settle();
    expect(cache.get('decisions.panel'), 'pql', reason: 'latest wins');
  });

  test('keeps addresses independent', () async {
    bus.publish('decisions.panel', 'filter.state', {'query': 'git'});
    bus.publish('files.tree', 'filter.state', {'query': 'lib'});
    await settle();
    expect(cache.get('decisions.panel'), 'git');
    expect(cache.get('files.tree'), 'lib');
  });

  test('ignores other channels', () async {
    bus.publish('decisions.panel', 'filter.set', {'query': 'git'});
    await settle();
    expect(cache.get('decisions.panel'), isNull, reason: 'only filter.state feeds the cache');
  });

  test('a missing query is treated as empty', () async {
    bus.publish('decisions.panel', 'filter.state', {});
    await settle();
    expect(cache.get('decisions.panel'), '');
  });

  test('stops updating after dispose', () async {
    cache.dispose();
    bus.publish('decisions.panel', 'filter.state', {'query': 'git'});
    await settle();
    expect(cache.get('decisions.panel'), isNull);
  });
}
