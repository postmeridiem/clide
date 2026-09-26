import 'dart:async';
import 'dart:io';

import 'package:clide/src/broker/auth/secrets.dart';
import 'package:clide/src/broker/cli.dart';
import 'package:clide/src/broker/store/broker_store.dart';
import 'package:clide/src/broker/store/location.dart';
import 'package:test/test.dart';

/// `clide_broker token rotate`, `signin-link` and `serve` (D-118).
void main() {
  late Directory dir;
  late Map<String, String> environment;
  final now = DateTime.utc(2026, 9, 24, 12);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('clide-broker-signin-');
    environment = {'CLIDE_BROKER_STORE': 'sqlite:${dir.path}/broker.db', 'CLIDE_BROKER_PUBLIC_ORIGIN': 'https://clide.test'};
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<(int, String, String)> run(List<String> args, {Future<void>? stop}) async {
    final out = StringBuffer();
    final err = StringBuffer();
    final code = await runBrokerCli(
      args,
      environment: environment,
      out: out,
      err: err,
      stop: stop,
      clock: () => now,
      caddyStartupGrace: const Duration(milliseconds: 200),
    );
    return (code, out.toString(), err.toString());
  }

  Future<T> withStore<T>(Future<T> Function(BrokerStore store) body) async {
    final store = await BrokerStore.open(SqliteLocation('${dir.path}/broker.db'), clock: () => now);
    try {
      return await body(store);
    } finally {
      await store.close();
    }
  }

  group('token rotate', () {
    test('prints the sign-in link once, keeps only the hash, and ends every session', () async {
      await withStore(
        (store) => store.putSession(StoredSession(idHash: 'h', user: 0, via: 'token', createdAt: now, expiresAt: now.add(const Duration(hours: 1)))),
      );
      final (code, out, err) = await run(['token', 'rotate']);
      expect(code, 0);
      final token = RegExp(r'^https://clide\.test/auth/login#token=([A-Za-z0-9_-]{43})\n$').firstMatch(out)![1]!;
      expect(err, contains('ended every session'));
      await withStore((store) async {
        expect(await store.tokenHash(0), secretHash(token));
        expect(await store.session('h'), isNull);
      });
    });

    test('without public_origin it prints the token alone, and says what would give the link', () async {
      environment.remove('CLIDE_BROKER_PUBLIC_ORIGIN');
      final (code, out, err) = await run(['token', 'rotate']);
      expect(code, 0);
      expect(out.trim(), matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(err, contains('Set public_origin'));
    });
  });

  group('signin-link', () {
    test('is refused in token mode, where the token already serves', () async {
      environment['CLIDE_BROKER_SIGNIN_MODE'] = 'token';
      final (code, out, err) = await run(['signin-link']);
      expect([code, out], [exitUsage, '']);
      expect(err, contains('token rotate'));
    });

    test('in OIDC mode prints a link that works once, for ten minutes', () async {
      environment['CLIDE_BROKER_SIGNIN_MODE'] = 'oidc';
      final (code, out, err) = await run(['signin-link']);
      expect(code, 0);
      final link = RegExp(r'^https://clide\.test/auth/login#link=([A-Za-z0-9_-]{43})\n$').firstMatch(out)![1]!;
      expect(err, contains('2026-09-24T12:10:00.000Z'));
      await withStore((store) async {
        expect(await store.useSigninLink(secretHash(link)), 0);
        expect(await store.useSigninLink(secretHash(link)), isNull);
      });
    });

    test('without public_origin there is no link to print', () async {
      environment
        ..['CLIDE_BROKER_SIGNIN_MODE'] = 'oidc'
        ..remove('CLIDE_BROKER_PUBLIC_ORIGIN');
      final (code, _, err) = await run(['signin-link']);
      expect(code, exitConfig);
      expect(err, contains('public_origin is not set'));
    });
  });

  group('serve', () {
    test('refuses to start on incomplete settings, naming each problem', () async {
      environment.remove('CLIDE_BROKER_PUBLIC_ORIGIN');
      final (code, _, err) = await run(['serve', '--socket', '${dir.path}/broker.sock']);
      expect(code, exitConfig);
      expect(err, allOf(contains('public_origin is not set'), contains('signin.mode is not set')));
      expect(FileSystemEntity.typeSync('${dir.path}/broker.sock'), FileSystemEntityType.notFound);
    });

    test('serves until stopped, then removes its socket', () async {
      environment['CLIDE_BROKER_SIGNIN_MODE'] = 'token';
      await run(['token', 'rotate']);
      final socket = '${dir.path}/run/broker.sock';
      final stop = Completer<void>();
      final served = run(['serve', '--socket', socket], stop: stop.future);

      while (FileSystemEntity.typeSync(socket) != FileSystemEntityType.unixDomainSock) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final client = HttpClient()
        ..connectionFactory = (uri, proxyHost, proxyPort) => Socket.startConnect(InternetAddress(socket, type: InternetAddressType.unix), 0);
      final request = await client.getUrl(Uri.parse('http://broker/auth/verify'));
      request.headers.set('x-forwarded-uri', '/');
      final response = await request.close();
      await response.drain<void>();
      client.close(force: true);
      expect(response.statusCode, 401);

      stop.complete();
      final (code, _, err) = await served;
      expect(code, 0);
      expect(err, allOf(contains('serving https://clide.test on $socket'), contains('stopped')));
      expect(FileSystemEntity.typeSync(socket), FileSystemEntityType.notFound);
    });

    test('needs an absolute socket path', () async {
      for (final args in [
        ['serve'],
        ['serve', '--socket'],
        ['serve', '--socket', 'relative.sock'],
        ['serve', '--socket', '/x.sock', '--caddy', '/caddy'],
        ['serve', '--socket', '/x.sock', '--host'],
        ['serve', '--socket', '/x.sock', '--host', 'host'],
        ['serve', '--socket', '/x.sock', '--users', 'users'],
        ['serve', '--socket', '/x.sock', '--socket', '/y.sock'],
        ['serve', '--socket', '/x.sock', '--hosts', '/host'],
      ]) {
        expect((await run(args)).$1, exitUsage, reason: args.join(' '));
      }
    });

    String standIn(String body) {
      final file = File('${dir.path}/caddy')..writeAsStringSync('#!/bin/sh\n$body\n');
      Process.runSync('chmod', ['755', file.path]);
      return file.path;
    }

    test('with --caddy, runs Caddy once its socket is up, and stops Caddy first', () async {
      environment['CLIDE_BROKER_SIGNIN_MODE'] = 'token';
      await run(['token', 'rotate']);
      final pidFile = '${dir.path}/caddy.pid';
      final caddy = standIn('echo \$\$ > $pidFile; echo "running \$*"; exec sleep 30');
      final stop = Completer<void>();
      final served = run(['serve', '--socket', '${dir.path}/run/broker.sock', '--caddy', caddy, '--caddy-config', '/etc/caddy/Caddyfile'], stop: stop.future);
      while (!File(pidFile).existsSync()) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
      stop.complete();
      final (code, _, err) = await served;
      expect(code, 0);
      expect(err, allOf(contains('caddy: running run --config /etc/caddy/Caddyfile --adapter caddyfile'), contains('behind Caddy')));
      final pid = File(pidFile).readAsStringSync().trim();
      expect(Process.runSync('kill', ['-0', pid]).exitCode, isNot(0), reason: 'Caddy is still running');
    }, testOn: '!windows');

    test('a Caddy that cannot start stops the broker, which says why', () async {
      environment['CLIDE_BROKER_SIGNIN_MODE'] = 'token';
      await run(['token', 'rotate']);
      final socket = '${dir.path}/run/broker.sock';
      final (code, _, err) = await run(['serve', '--socket', socket, '--caddy', standIn('echo "port 8443 in use" >&2; exit 1'), '--caddy-config', '/x']);
      expect(code, exitConfig);
      expect(err, allOf(contains('caddy: port 8443 in use'), contains('Caddy exited while starting, with code 1')));
      expect(FileSystemEntity.typeSync(socket), FileSystemEntityType.notFound);
      final (missing, _, missingErr) = await run(['serve', '--socket', socket, '--caddy', '${dir.path}/no-caddy', '--caddy-config', '/x']);
      expect(missing, exitConfig);
      expect(missingErr, contains('Caddy could not be started'));
    }, testOn: '!windows');

    test('stops on the first signal of any kind, then stops listening to all of them', () async {
      final term = StreamController<Object?>();
      final interrupt = StreamController<Object?>();
      var done = false;
      unawaited(firstEvent([term.stream, interrupt.stream]).then((_) => done = true));
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      interrupt.add(null);
      await Future<void>.delayed(Duration.zero);
      expect([done, term.hasListener, interrupt.hasListener], [true, false, false]);
    });
  });
}
