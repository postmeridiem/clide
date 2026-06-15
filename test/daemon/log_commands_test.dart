import 'package:clide/kernel/src/log.dart';
import 'package:clide/src/daemon/dispatcher.dart';
import 'package:clide/src/daemon/log_commands.dart';
import 'package:clide/src/ipc/envelope.dart';
import 'package:test/test.dart';

void main() {
  group('log.level command (T-433)', () {
    test('no arg reports the current level + the vocabulary', () async {
      final log = Logger(minLevel: LogLevel.info);
      final d = DaemonDispatcher();
      registerLogCommands(d, log, (_) async {});

      final r = await d.dispatch(IpcRequest(id: '1', cmd: 'log.level', args: const {}));
      expect(r.ok, isTrue);
      expect(r.data['level'], 'info');
      expect(r.data['levels'], containsAll(<String>['trace', 'debug', 'info', 'warn', 'error']));
    });

    test('a valid level sets the running logger AND persists it', () async {
      final log = Logger(minLevel: LogLevel.info);
      String? persisted;
      final d = DaemonDispatcher();
      registerLogCommands(d, log, (name) async => persisted = name);

      final r = await d.dispatch(IpcRequest(id: '1', cmd: 'log.level', args: {'level': 'warn'}));
      expect(r.ok, isTrue);
      expect(r.data['level'], 'warn');
      expect(log.minLevel, LogLevel.warn); // live
      expect(persisted, 'warn'); // durable
    });

    test('level name is case-insensitive', () async {
      final log = Logger(minLevel: LogLevel.info);
      final d = DaemonDispatcher();
      registerLogCommands(d, log, (_) async {});
      await d.dispatch(IpcRequest(id: '1', cmd: 'log.level', args: {'level': 'ERROR'}));
      expect(log.minLevel, LogLevel.error);
    });

    test('an unknown level errors (code 64), leaves the logger untouched, does not persist', () async {
      final log = Logger(minLevel: LogLevel.info);
      var persistCalls = 0;
      final d = DaemonDispatcher();
      registerLogCommands(d, log, (_) async => persistCalls++);

      final r = await d.dispatch(IpcRequest(id: '1', cmd: 'log.level', args: {'level': 'loud'}));
      expect(r.ok, isFalse);
      expect(r.error?.code, 64);
      expect(r.error?.hint, contains('warn'));
      expect(log.minLevel, LogLevel.info);
      expect(persistCalls, 0);
    });
  });
}
