import 'package:clide/src/cli/argv_to_request.dart';
import 'package:clide/src/ipc/envelope.dart';
import 'package:clide/src/ipc/schema_v1.dart';
import 'package:test/test.dart';

IpcRequest _expectOk(ArgvParseResult r) {
  expect(r, isA<ArgvParsed>(), reason: 'expected parse to succeed: $r');
  return (r as ArgvParsed).request;
}

IpcResponse _expectErr(ArgvParseResult r) {
  expect(r, isA<ArgvError>(), reason: 'expected parse to error: $r');
  return (r as ArgvError).response;
}

void main() {
  group('parseArgv — subsystem.verb shape', () {
    test('subsystem + verb maps to "subsystem.verb"', () {
      final req = _expectOk(parseArgv(['git', 'status'], requestId: '1'));
      expect(req.cmd, 'git.status');
      expect(req.id, '1');
      expect(req.args, isEmpty);
    });

    test('positional args land in args.positional', () {
      final req = _expectOk(parseArgv(['files', 'read', 'lib/main.dart'], requestId: '2'));
      expect(req.cmd, 'files.read');
      expect(req.args['positional'], ['lib/main.dart']);
      expect(req.args.containsKey('flags'), isFalse);
    });

    test('multiple positionals preserve order', () {
      final req = _expectOk(parseArgv(['git', 'stage', 'a.dart', 'b.dart', 'c.dart'], requestId: '3'));
      expect(req.args['positional'], ['a.dart', 'b.dart', 'c.dart']);
    });

    test('--key=value flag', () {
      final req = _expectOk(parseArgv(['git', 'log', '--count=20'], requestId: '4'));
      expect(req.cmd, 'git.log');
      expect((req.args['flags'] as Map)['count'], '20');
    });

    test('--key value flag (separated)', () {
      final req = _expectOk(parseArgv(['git', 'log', '--count', '20'], requestId: '5'));
      expect((req.args['flags'] as Map)['count'], '20');
    });

    test('boolean flag at end of argv', () {
      final req = _expectOk(parseArgv(['git', 'push', '--force'], requestId: '6'));
      expect((req.args['flags'] as Map)['force'], isTrue);
    });

    test('boolean flag followed by another flag', () {
      final req = _expectOk(parseArgv(['git', 'log', '--graph', '--count=10'], requestId: '7'));
      expect((req.args['flags'] as Map)['graph'], isTrue);
      expect((req.args['flags'] as Map)['count'], '10');
    });

    test('bare -- terminates options; rest is passthrough', () {
      final req = _expectOk(parseArgv(['pane', 'spawn', '--name', 'foo', '--', 'bash', '-c', 'echo hi'], requestId: '8'));
      expect(req.cmd, 'pane.spawn');
      expect((req.args['flags'] as Map)['name'], 'foo');
      expect(req.args['passthrough'], ['bash', '-c', 'echo hi']);
    });

    test('mixed positional + flag + passthrough', () {
      final req = _expectOk(parseArgv(['files', 'read', 'a.dart', '--limit=4096', '--', '--not-a-flag'], requestId: '9'));
      expect(req.args['positional'], ['a.dart']);
      expect((req.args['flags'] as Map)['limit'], '4096');
      expect(req.args['passthrough'], ['--not-a-flag']);
    });
  });

  group('parseArgv — umbrella commands', () {
    test('"status" maps to cmd "status" with no subsystem', () {
      final req = _expectOk(parseArgv(['status'], requestId: 's'));
      expect(req.cmd, 'status');
      expect(req.args, isEmpty);
    });

    test('"tail --events" sets the events boolean flag', () {
      final req = _expectOk(parseArgv(['tail', '--events'], requestId: 't'));
      expect(req.cmd, 'tail');
      expect((req.args['flags'] as Map)['events'], isTrue);
    });

    test('"tail --events --filter git" pairs the filter value', () {
      final req = _expectOk(parseArgv(['tail', '--events', '--filter', 'git'], requestId: 'tf'));
      expect((req.args['flags'] as Map)['events'], isTrue);
      expect((req.args['flags'] as Map)['filter'], 'git');
    });

    test('ping + version are recognised as umbrella commands', () {
      expect(_expectOk(parseArgv(['ping'], requestId: 'p')).cmd, 'ping');
      expect(_expectOk(parseArgv(['version'], requestId: 'v')).cmd, 'version');
    });
  });

  group('parseArgv — errors', () {
    test('empty argv → usage error (EX_USAGE)', () {
      final err = _expectErr(parseArgv(const [], requestId: 'e1'));
      expect(err.error?.code, IpcExitCode.userError);
      expect(err.error?.message, contains('usage'));
    });

    test('subsystem without verb → usage error', () {
      final err = _expectErr(parseArgv(['git'], requestId: 'e2'));
      expect(err.error?.message, contains('usage'));
      expect(err.error?.message, contains('git'));
    });

    test('garbage in the subsystem token is rejected', () {
      final err = _expectErr(parseArgv(['bad subsystem', 'verb'], requestId: 'e3'));
      expect(err.error?.message, contains('subsystem'));
    });

    test('"--" with no name is a flag-shape error', () {
      // "git status -- --" — first -- starts passthrough so second is
      // not a flag; that's fine. Reproduce the failure with the
      // option-name-empty path via `git status --=foo` which gives an
      // empty key.
      final err = _expectErr(parseArgv(['git', 'status', '--=foo'], requestId: 'e4'));
      expect(err.error?.message, contains('flag'));
    });

    test('empty flag body before passthrough is treated as bare --', () {
      // `git status -- bar` — bar is passthrough, not a positional.
      final req = _expectOk(parseArgv(['git', 'status', '--', 'bar'], requestId: 'e5'));
      expect(req.args['passthrough'], ['bar']);
      expect(req.args.containsKey('positional'), isFalse);
    });
  });

  group('parseArgv — wire round-trip', () {
    test('encoded request → decoded request matches', () {
      final req = _expectOk(parseArgv(['files', 'read', 'README.md'], requestId: 'rt'));
      final wire = req.encode();
      final decoded = IpcMessage.decode(wire);
      expect(decoded, isA<IpcRequest>());
      final r = decoded as IpcRequest;
      expect(r.cmd, 'files.read');
      expect(r.args['positional'], ['README.md']);
    });
  });
}
