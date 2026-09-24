import 'dart:io';

import 'package:clide/src/broker/auth/secrets.dart';
import 'package:clide/src/broker/auth/sessions.dart';
import 'package:clide/src/broker/store/broker_store.dart';
import 'package:clide/src/broker/store/location.dart';
import 'package:test/test.dart';

void main() {
  group('secrets', () {
    test('are random, long, and safe in a URL, a form and a cookie', () {
      final a = randomSecret();
      expect(a, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(randomSecret(), isNot(a));
      expect(looksLikeSecret(a), isTrue);
    });

    test('only the shape the broker makes is looked up', () {
      for (final value in ['', 'short', 'x' * 129, 'has space in it here', '../../etc/passwd/x', 'a=b;c' * 4]) {
        expect(looksLikeSecret(value), isFalse, reason: value);
      }
    });

    test('are kept as their SHA-256, compared whole', () {
      expect(secretHash('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
      expect(sameHash(secretHash('abc'), secretHash('abc')), isTrue);
      expect(sameHash(secretHash('abc'), secretHash('abd')), isFalse);
      expect(sameHash('ab', 'abc'), isFalse);
    });
  });

  group('sessions', () {
    late Directory dir;
    late BrokerStore store;
    late DateTime now;
    late Sessions sessions;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('clide-sessions-');
      now = DateTime.utc(2026, 9, 24, 12);
      store = await BrokerStore.open(SqliteLocation('${dir.path}/broker.db'), clock: () => now);
      sessions = Sessions(store, lifetime: const Duration(hours: 2), clock: () => now);
    });
    tearDown(() async {
      await store.close();
      dir.deleteSync(recursive: true);
    });

    test('a started session is found from its cookie until it expires, and the store keeps only its hash', () async {
      final cookie = await sessions.start(0, via: 'token');
      final header = 'other=1; ${cookie.split(';').first}; more=2';
      final id = Sessions.sessionId(header)!;
      final found = await sessions.find(header);
      expect([found!.user, found.via, found.idHash], [0, 'token', secretHash(id)]);
      now = now.add(const Duration(hours: 2));
      expect(await sessions.find(header), isNull);
    });

    test('ending a session removes it', () async {
      final header = (await sessions.start(0, via: 'link')).split(';').first;
      await sessions.end(header);
      expect(await sessions.find(header), isNull);
      await sessions.end(null);
    });

    test('reads only its own cookie, and only a value shaped like a session id', () {
      expect(Sessions.sessionId(null), isNull);
      expect(Sessions.sessionId('clide_session=${'a' * 43}'), isNull);
      expect(Sessions.sessionId('__Host-clide_session=bad value'), isNull);
      expect(Sessions.sessionId(' __Host-clide_session = ${'a' * 43} '), 'a' * 43);
    });

    test('the cookie that clears it matches the one that set it', () {
      expect(Sessions.clearCookie, '__Host-clide_session=; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=0');
    });
  });
}
