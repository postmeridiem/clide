/// Unit tests for [PaneRegistry].
///
/// Exercises spawn / list / write / resize / close against the real
/// `ptyc` binary (small enough, and realistic enough, to not be worth
/// mocking). Events are captured via [RecordingEventSink].
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/clide.dart';
import 'package:test/test.dart';

void main() {
  if (!Platform.isLinux && !Platform.isMacOS) return;

  final ptycPath = File('ptyc/bin/ptyc').existsSync()
      ? File('ptyc/bin/ptyc').absolute.path
      : 'ptyc';

  group('PaneRegistry', () {
    late RecordingEventSink sink;
    late PaneRegistry registry;

    setUp(() {
      sink = RecordingEventSink();
      registry = PaneRegistry(events: sink);
    });

    tearDown(() => registry.shutdown());

    test('spawn → emits pane.spawned and lists the pane', () async {
      final pane = await registry.spawn(
        kind: PaneKind.terminal,
        argv: const ['/bin/echo', 'hi'],
        ptycPath: ptycPath,
      );

      expect(pane.id, startsWith('p_'));
      expect(pane.kind, PaneKind.terminal);
      expect(registry.panes, contains(pane));
      expect(sink.ofKind('pane.spawned'), hasLength(1));
      final evt = sink.ofKind('pane.spawned').first;
      expect(evt.data['id'], pane.id);
    });

    test('output events base64-encode the child bytes', () async {
      await registry.spawn(
        kind: PaneKind.terminal,
        argv: const ['/bin/echo', 'hello-panes'],
        ptycPath: ptycPath,
      );

      // /bin/echo closes its pty quickly. Wait briefly for output +
      // the resulting pane.exit event to settle.
      for (var i = 0; i < 30; i++) {
        if (sink.ofKind('pane.output').isNotEmpty &&
            sink.ofKind('pane.exit').isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      final out = sink.ofKind('pane.output').toList();
      expect(out, isNotEmpty);
      final decoded = out
          .map((e) => utf8.decode(base64Decode(e.data['bytes_b64']! as String)))
          .join();
      expect(decoded, contains('hello-panes'));
    });

    test('write + resize emit no spurious events, update state', () async {
      final pane = await registry.spawn(
        kind: PaneKind.terminal,
        argv: const ['/bin/cat'],
        ptycPath: ptycPath,
      );

      final writeCount = registry.write(pane.id, utf8.encode('abc'));
      expect(writeCount, greaterThan(0));

      registry.resize(pane.id, cols: 120, rows: 40);
      final resized = sink.ofKind('pane.resized').toList();
      expect(resized, hasLength(1));
      expect(resized.single.data['cols'], 120);
      expect(resized.single.data['rows'], 40);
    });

    test('close is idempotent + emits pane.closed once', () async {
      final pane = await registry.spawn(
        kind: PaneKind.terminal,
        argv: const ['/bin/cat'],
        ptycPath: ptycPath,
      );

      await registry.close(pane.id);
      await registry.close(pane.id); // second call: no-op

      expect(registry.get(pane.id), isNull);
      expect(sink.ofKind('pane.closed'), hasLength(1));
    });

    test('close on unknown id does nothing', () async {
      await registry.close('p_nonexistent');
      expect(sink.ofKind('pane.closed'), isEmpty);
    });

    test('claude kind round-trips on the wire', () async {
      final pane = await registry.spawn(
        kind: PaneKind.claude,
        argv: const ['/bin/sh', '-c', 'exit 0'],
        ptycPath: ptycPath,
      );
      expect(pane.kind, PaneKind.claude);
      expect(pane.toJson()['kind'], 'claude');
    });
  });
}
