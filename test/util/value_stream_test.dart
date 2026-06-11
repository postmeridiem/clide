/// Tests for [ValueStream] — the replay-latest state holder (T-386).
library;

import 'package:clide/src/util/value_stream.dart';
import 'package:test/test.dart';

void main() {
  test('a late subscriber receives the latest value immediately', () async {
    final v = ValueStream<int>();
    v.add(1);
    v.add(2);
    final got = <int>[];
    v.stream.listen(got.add);
    await Future<void>.delayed(Duration.zero);
    expect(got, [2]);
  });

  test('an unseeded holder replays nothing until the first add', () async {
    final v = ValueStream<int>();
    final got = <int>[];
    v.stream.listen(got.add);
    await Future<void>.delayed(Duration.zero);
    expect(got, isEmpty);
    v.add(7);
    await Future<void>.delayed(Duration.zero);
    expect(got, [7]);
  });

  test('seeded constructor provides the initial value', () async {
    final v = ValueStream<bool>.seeded(false);
    expect(v.hasValue, isTrue);
    expect(v.value, isFalse);
    final got = <bool>[];
    v.stream.listen(got.add);
    await Future<void>.delayed(Duration.zero);
    expect(got, [false]);
  });

  test('live updates flow to existing subscribers', () async {
    final v = ValueStream<String>();
    final got = <String>[];
    v.stream.listen(got.add);
    v.add('a');
    v.add('b');
    await Future<void>.delayed(Duration.zero);
    expect(got, ['a', 'b']);
  });

  test('each stream access gives every subscriber its own replay', () async {
    final v = ValueStream<int>.seeded(5);
    final a = <int>[];
    final b = <int>[];
    v.stream.listen(a.add);
    v.stream.listen(b.add);
    v.add(6);
    await Future<void>.delayed(Duration.zero);
    expect(a, [5, 6]);
    expect(b, [5, 6]);
  });

  test('value throws before the first add; valueOrNull is null', () {
    final v = ValueStream<int>();
    expect(() => v.value, throwsStateError);
    expect(v.valueOrNull, isNull);
    expect(v.hasValue, isFalse);
  });

  test('a nullable type can hold null as a real value', () async {
    final v = ValueStream<String?>.seeded(null);
    expect(v.hasValue, isTrue);
    expect(v.valueOrNull, isNull);
    final got = <String?>[];
    v.stream.listen(got.add);
    await Future<void>.delayed(Duration.zero);
    expect(got, [null]);
  });

  test('close ends derived streams; a post-close subscriber still gets the replay', () async {
    final v = ValueStream<int>();
    v.add(3);
    final done = <String>[];
    v.stream.listen((_) {}, onDone: () => done.add('a'));
    await v.close();
    await Future<void>.delayed(Duration.zero);
    expect(done, ['a']);
    expect(v.isClosed, isTrue);

    final got = <int>[];
    var closed = false;
    v.stream.listen(got.add, onDone: () => closed = true);
    await Future<void>.delayed(Duration.zero);
    expect(got, [3], reason: 'the last value survives close for late readers');
    expect(closed, isTrue);
  });

  test('add after close updates the value without throwing', () {
    final v = ValueStream<int>.seeded(1);
    v.close();
    v.add(2);
    expect(v.value, 2);
  });

  test('pause/resume on a derived stream buffers updates', () async {
    final v = ValueStream<int>();
    final got = <int>[];
    final sub = v.stream.listen(got.add);
    v.add(1);
    await Future<void>.delayed(Duration.zero);
    sub.pause();
    v.add(2);
    await Future<void>.delayed(Duration.zero);
    expect(got, [1]);
    sub.resume();
    await Future<void>.delayed(Duration.zero);
    expect(got, [1, 2]);
  });
}
