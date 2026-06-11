/// Unit tests for the `_argv` unwrap handler (T-126).
///
/// Exercises the two branches the e2e test doesn't reliably hit:
///   1. `args.argv` not a List → userError
///   2. argv parses to an ArgvError → that error flows back through
library;

import 'package:clide/src/cli/argv_dispatch.dart';
import 'package:clide/src/daemon/dispatcher.dart';
import 'package:clide/src/ipc/envelope.dart';
import 'package:clide/src/ipc/schema_v1.dart';
import 'package:test/test.dart';

void main() {
  late DaemonDispatcher d;

  setUp(() {
    d = DaemonDispatcher();
    registerArgvUnwrap(d);
  });

  test('valid argv → parsed and re-dispatched (round-trip via ping)', () async {
    final res = await d.dispatch(
      IpcRequest(
        id: 'x',
        cmd: argvSentinelCmd,
        args: {
          'argv': ['ping'],
        },
      ),
    );
    expect(res.ok, isTrue);
    expect(res.id, 'x');
    expect(res.data['pong'], isTrue);
  });

  test('args.argv missing → userError', () async {
    final res = await d.dispatch(IpcRequest(id: 'y', cmd: argvSentinelCmd, args: const {}));
    expect(res.ok, isFalse);
    expect(res.error?.kind, IpcErrorKind.userError);
    expect(res.error?.message, contains('argv'));
  });

  test('args.argv is not a list → userError', () async {
    final res = await d.dispatch(IpcRequest(id: 'z', cmd: argvSentinelCmd, args: {'argv': 'not a list'}));
    expect(res.ok, isFalse);
    expect(res.error?.kind, IpcErrorKind.userError);
  });

  test('argv that fails parseArgv → that error flows back unmodified', () async {
    final res = await d.dispatch(
      IpcRequest(
        id: 'p',
        cmd: argvSentinelCmd,
        args: {
          'argv': const <String>[], // empty argv triggers parseArgv usage error
        },
      ),
    );
    expect(res.ok, isFalse);
    expect(res.error?.kind, IpcErrorKind.userError);
    expect(res.error?.message, contains('usage'));
  });

  test('outer request id is preserved on the response', () async {
    final res = await d.dispatch(
      IpcRequest(
        id: 'unique-id-123',
        cmd: argvSentinelCmd,
        args: {
          'argv': ['ping'],
        },
      ),
    );
    expect(res.id, 'unique-id-123');
  });
}
