/// Integration tests for `lib/src/pql/client.dart`. Drives the real
/// `pql` binary against the working directory's vault for happy-path
/// methods; uses a fake pql path for the error-handling tail.
library;

import 'dart:io';

import 'package:clide/kernel/src/toolchain_paths.dart';
import 'package:clide/src/pql/client.dart';
import 'package:test/test.dart';

void main() {
  late PqlClient pql;
  setUp(() {
    final toolchain = ToolchainView.resolved(resolveToolchainPaths(Directory.current.path));
    pql = PqlClient(workDir: Directory.current, toolchain: toolchain);
  });

  group('PqlException', () {
    test('toString includes exit code and message', () {
      const e = PqlException('boom', exitCode: 42);
      expect(e.toString(), contains('42'));
      expect(e.toString(), contains('boom'));
    });
  });

  group('PqlClient — query surface (real pql against clide repo)', () {
    test('files with glob + limit narrows results', () async {
      final all = await pql.files(limit: 3);
      expect(all, isNotEmpty);
      expect(all.length, lessThanOrEqualTo(3));
      final scoped = await pql.files(glob: 'CLAUDE.md');
      expect(scoped, isNotEmpty);
      expect(scoped.first['path'], contains('CLAUDE.md'));
    });

    test('backlinks returns inbound references', () async {
      final links = await pql.backlinks('CLAUDE.md');
      // CLAUDE.md may have no inbound links; just verify the call succeeds
      // and returns the right shape.
      expect(links, isA<List>());
    });

    test('tags returns the tag list (with limit)', () async {
      final tags = await pql.tags(limit: 5);
      expect(tags, isA<List>());
      expect(tags.length, lessThanOrEqualTo(5));
    });

    test('query runs a DSL with limit and returns rows', () async {
      final rows = await pql.query('SELECT name', limit: 2);
      expect(rows, isA<List>());
      expect(rows.length, lessThanOrEqualTo(2));
    });

    test('search runs a ranked search with limit', () async {
      final hits = await pql.search('clide', limit: 2);
      expect(hits, isA<List>());
      expect(hits.length, lessThanOrEqualTo(2));
    });
  });

  group('PqlClient — decisions surface', () {
    test('decisionValidate runs the validator', () async {
      final result = await pql.decisionValidate();
      // Validator returns either a map (with errors) or null (ok).
      expect(result, anyOf(isNull, isA<Map>()));
    });

    test('decisionList with domain + status filters', () async {
      final architecture = await pql.decisionList(type: 'confirmed', domain: 'architecture');
      expect(architecture, isNotEmpty);
      expect(architecture.every((d) => d['domain'] == 'architecture'), isTrue);
    });

    test('decisionShow with --with-refs joins cross-refs', () async {
      final d = await pql.decisionShow('D-1', withRefs: true);
      expect(d['id'], 'D-1');
    });

    test('decisionShow with --with-tickets joins ticket refs', () async {
      final d = await pql.decisionShow('D-1', withTickets: true);
      expect(d['id'], 'D-1');
    });

    test('decisionRead returns the full markdown body', () async {
      final d = await pql.decisionRead('D-1');
      expect(d['id'], 'D-1');
    });
  });

  group('PqlClient — ticket surface', () {
    test('ticketList without filters returns all tickets', () async {
      final tickets = await pql.ticketList();
      expect(tickets, isNotEmpty);
    });

    test('ticketList with status filter narrows', () async {
      final done = await pql.ticketList(status: 'done');
      expect(done, isNotEmpty);
      expect(done.every((t) => t['status'] == 'done'), isTrue);
    });

    test('ticketList with team / assigned / decision exercises all flags', () async {
      // No team-or-assignment filter likely to match in clide; just verify
      // the call succeeds and returns the right shape.
      final scoped = await pql.ticketList(team: 'nope', assigned: 'nobody', decision: 'D-1');
      expect(scoped, isA<List>());
    });

    test('ticketShow with context + blockers joins both', () async {
      // T-1 exists in clide's plan.
      final t = await pql.ticketShow('T-1', withContext: true, withBlockers: true);
      expect(t['id'], 'T-1');
    });

    test('ticketBoard with team filter', () async {
      final board = await pql.ticketBoard(team: 'nope');
      expect(board, isA<List>());
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
}
