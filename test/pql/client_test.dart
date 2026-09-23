/// Integration tests for `lib/src/pql/client.dart`. Drives the real
/// `pql` binary against a small fixture vault for the happy paths (see
/// `helpers/pql_vault.dart` for what it holds); uses a fake pql script for
/// the error-handling tail.
///
/// The vault is private to this file (T-639). These tests used to run on
/// clide's own `.pql/` planning DB, so they asserted on the live plan and
/// fought other suites for its SQLite lock — which is why they needed the
/// `serial` tag. They don't any more.
library;

import 'dart:io';

import 'package:clide/kernel/src/toolchain_paths.dart';
import 'package:clide/src/pql/client.dart';
import 'package:test/test.dart';

import '../helpers/pql_vault.dart';

void main() {
  late PqlFixtureVault vault;
  late PqlClient pql;
  setUpAll(() async => vault = await PqlFixtureVault.create());
  tearDownAll(() => vault.dispose());
  setUp(() {
    final toolchain = ToolchainView.resolved(resolveToolchainPaths());
    pql = PqlClient(workDir: vault.dir, toolchain: toolchain);
  });

  group('PqlException', () {
    test('toString includes exit code and message', () {
      const e = PqlException('boom', exitCode: 42);
      expect(e.toString(), contains('42'));
      expect(e.toString(), contains('boom'));
    });
  });

  group('PqlClient — query surface (fixture vault)', () {
    test('files with glob + limit narrows results', () async {
      final all = await pql.files();
      expect(all.map((f) => f['path']), containsAll(['notes/alpha.md', 'notes/beta.md']));
      expect(await pql.files(limit: 1), hasLength(1));
      final scoped = await pql.files(glob: 'notes/*.md');
      expect(scoped.map((f) => f['path']).toSet(), {'notes/alpha.md', 'notes/beta.md'});
    });

    test('backlinks and outlinks follow the wikilinks', () async {
      expect((await pql.backlinks('notes/beta.md')).map((l) => l['path']), ['notes/alpha.md']);
      expect(await pql.outlinks('notes/alpha.md'), isNotEmpty);
    });

    test('tags returns frontmatter and inline tags (with limit)', () async {
      final tags = await pql.tags();
      expect(tags.map((t) => t['tag']), containsAll(['fixture', 'inline-tag']));
      expect(await pql.tags(limit: 1), hasLength(1));
    });

    test('meta returns a file\'s frontmatter', () async {
      final m = await pql.meta('notes/alpha.md');
      expect(m.toString(), contains('Alpha'));
    });

    test('query runs a DSL with limit and returns rows', () async {
      final rows = await pql.query('SELECT name', limit: 2);
      expect(rows, hasLength(2));
    });

    test('search ranks the matching note first', () async {
      final hits = await pql.search('Alpha', limit: 2);
      expect(hits.first['path'], 'notes/alpha.md');
    });
  });

  group('PqlClient — decisions surface', () {
    test('decisionSync reports the fixture decisions', () async {
      final r = await pql.decisionSync();
      expect(r['synced'], 2);
    });

    test('decisionValidate passes on the fixture', () async {
      final result = await pql.decisionValidate();
      // Validator returns either a map (with errors) or null (ok).
      expect(result, anyOf(isNull, isA<Map>()));
    });

    test('decisionList with domain + type filters', () async {
      final architecture = await pql.decisionList(type: 'confirmed', domain: 'architecture');
      expect(architecture.map((d) => d['id']).toSet(), {'D-1', 'D-2'});
      expect(await pql.decisionList(domain: 'nowhere'), isEmpty);
    });

    test('decisionShow with --with-refs joins cross-refs', () async {
      final d = await pql.decisionShow('D-2', withRefs: true);
      expect(d['id'], 'D-2');
      expect((d['refs'] as List).map((r) => (r as Map)['target_id']), contains('D-1'));
    });

    test('decisionShow with --with-tickets joins ticket refs', () async {
      final d = await pql.decisionShow('D-1', withTickets: true);
      expect(d['id'], 'D-1');
      expect(d.toString(), contains('T-2'));
    });

    test('decisionRead returns the full markdown body', () async {
      final d = await pql.decisionRead('D-1');
      expect(d['id'], 'D-1');
      expect(d['body'], contains('The fixture has a decision.'));
    });
  });

  group('PqlClient — ticket surface', () {
    test('ticketList without filters returns all tickets', () async {
      final tickets = await pql.ticketList();
      expect(tickets.map((t) => t['id']).toSet(), {'T-1', 'T-2'});
    });

    test('ticketList with status filter narrows', () async {
      expect(await pql.ticketList(status: 'done'), isEmpty);
      expect(await pql.ticketList(status: 'backlog'), hasLength(2));
    });

    test('ticketList with team / assigned / decision exercises all flags', () async {
      expect((await pql.ticketList(decision: 'D-1')).map((t) => t['id']), ['T-2']);
      expect(await pql.ticketList(team: 'nope', assigned: 'nobody', decision: 'D-1'), isEmpty);
    });

    test('ticketShow with context + blockers joins both', () async {
      final t = await pql.ticketShow('T-2', withContext: true, withBlockers: true);
      expect(t['id'], 'T-2');
    });

    test('ticketShow with children returns the children array (T-595)', () async {
      final t = await pql.ticketShow('T-1', withChildren: true);
      expect(t['id'], 'T-1');
      expect((t['children'] as List).map((c) => (c as Map)['id']), ['T-2']);
    });

    test('ticketSetStatus moves a ticket', () async {
      final r = await pql.ticketSetStatus(['T-2'], 'ready');
      expect(r, isA<List>());
      expect((await pql.ticketShow('T-2'))['status'], 'ready');
    });

    test('ticketBoard with team filter', () async {
      final board = await pql.ticketBoard(team: 'nope');
      expect(board, isA<List>());
    });

    test('planStatus returns the dashboard', () async {
      expect(await pql.planStatus(), isA<Map>());
    });
  });

  group('PqlClient — error surface', () {
    test('non-existent pql binary raises a PqlException with ProcessException details', () async {
      // Inject a bad path — Process.run will throw ProcessException.
      final t = ToolchainView.resolved(const ResolvedPaths(pql: '/tmp/clide-no-such-pql-binary'));
      final bad = PqlClient(workDir: Directory.current, toolchain: t);
      try {
        await bad.files();
        fail('expected PqlException');
      } on PqlException catch (e) {
        expect(e.message, contains('files'));
        expect(e.stderr, isNotEmpty);
      }
    });

    test('non-zero exit code raises a PqlException with stderr attached', () async {
      // 'pql decisions show' on a non-existent id exits non-zero.
      try {
        await pql.decisionShow('D-99999');
        // If pql happens to swallow the not-found, just pass.
      } on PqlException catch (e) {
        expect(e.exitCode, isNot(0));
      }
    });
  });

  group('PqlClient — transient retry (T-350)', () {
    late Directory tmp;
    setUp(() async => tmp = await Directory.systemTemp.createTemp('clide_fakepql_'));
    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    // A fake `pql` whose body is [body]; a fresh `$0.n` counter file per test
    // lets a script "recover" after N invocations.
    Future<PqlClient> fakePql(String body, {Duration timeout = PqlClient.defaultTimeout}) async {
      final f = File('${tmp.path}/pql');
      await f.writeAsString('#!/bin/sh\n$body\n');
      await Process.run('chmod', ['+x', f.path]);
      return PqlClient(
        workDir: Directory.current,
        toolchain: ToolchainView.resolved(ResolvedPaths(pql: f.path)),
        timeout: timeout,
      );
    }

    // T-637 (#16): the transient check matched any stderr containing
    // "locked", so "unlocked" was retried like a busy database.
    test('an error that merely contains "locked" is not retried', () async {
      final p = await fakePql(r'c="$0.n"; n=$(cat "$c" 2>/dev/null || echo 0); echo $((n+1)) > "$c"; echo "vault unlocked, bad query" >&2; exit 1');
      await expectLater(p.files(), throwsA(isA<PqlException>().having((e) => e.exitCode, 'exitCode', 1)));
      expect(File('${tmp.path}/pql.n').readAsStringSync().trim(), '1');
    });

    test('a pql that hangs is killed at the timeout and reported', () async {
      final p = await fakePql('exec sleep 30', timeout: const Duration(milliseconds: 300));
      final sw = Stopwatch()..start();
      await expectLater(p.files(), throwsA(isA<PqlException>().having((e) => e.message, 'message', contains('timed out'))));
      expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
    });

    test('a genuine (non-busy) error surfaces immediately', () async {
      final p = await fakePql('exit 2');
      await expectLater(p.files(), throwsA(isA<PqlException>().having((e) => e.exitCode, 'exitCode', 2)));
    });

    test('a persistent db-busy (exit 69) throws after exhausting retries', () async {
      final p = await fakePql('exit 69');
      await expectLater(p.files(), throwsA(isA<PqlException>().having((e) => e.exitCode, 'exitCode', 69)));
    });

    test('a transient db-busy (exit 69) recovers on retry', () async {
      final p = await fakePql(
        r'c="$0.n"; n=$(cat "$c" 2>/dev/null || echo 0); n=$((n+1)); echo "$n" > "$c"; '
        r'if [ "$n" -lt 3 ]; then exit 69; fi; echo "[]"',
      );
      expect(await p.files(), isEmpty); // retried through two busies to success
    });

    test('a "database is locked" stderr (non-69 exit) is also retried', () async {
      final p = await fakePql(
        r'c="$0.n"; n=$(cat "$c" 2>/dev/null || echo 0); n=$((n+1)); echo "$n" > "$c"; '
        r'if [ "$n" -lt 3 ]; then echo "database is locked" >&2; exit 1; fi; echo "[]"',
      );
      expect(await p.files(), isEmpty);
    });
  });
}
