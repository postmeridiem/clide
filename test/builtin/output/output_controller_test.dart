import 'package:clide/builtin/output/src/output_controller.dart';
import 'package:clide/kernel/src/log.dart';
import 'package:clide/kernel/src/log_ring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OutputController Level chip (T-433)', () {
    test('initialLevel sets the starting level (reflects the kernel logger)', () {
      final c = OutputController(LogRing(), initialLevel: LogLevel.warn);
      expect(c.minLevel, LogLevel.warn);
      c.dispose();
    });

    test('defaults to debug when no initial level is given', () {
      final c = OutputController(LogRing());
      expect(c.minLevel, LogLevel.debug);
      c.dispose();
    });

    test('setMinLevel updates the level, fires onMinLevelChanged + notifies', () {
      final changes = <LogLevel>[];
      var notified = 0;
      final c = OutputController(LogRing(), initialLevel: LogLevel.info, onMinLevelChanged: changes.add)..addListener(() => notified++);

      c.setMinLevel(LogLevel.warn);
      expect(c.minLevel, LogLevel.warn);
      expect(changes, [LogLevel.warn]); // the chip drove the kernel + persist hook
      expect(notified, 1);
      c.dispose();
    });

    test('setting the same level is a no-op (no kernel write, no notify)', () {
      final changes = <LogLevel>[];
      var notified = 0;
      final c = OutputController(LogRing(), initialLevel: LogLevel.info, onMinLevelChanged: changes.add)..addListener(() => notified++);

      c.setMinLevel(LogLevel.info);
      expect(changes, isEmpty);
      expect(notified, 0);
      c.dispose();
    });

    test('with no callback the chip is a pure view filter (no throw)', () {
      final c = OutputController(LogRing(), initialLevel: LogLevel.info);
      expect(() => c.setMinLevel(LogLevel.error), returnsNormally);
      expect(c.minLevel, LogLevel.error);
      c.dispose();
    });
  });
}
