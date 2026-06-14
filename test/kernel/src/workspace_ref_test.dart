/// Unit tests for `WorkspaceRef` (T-332) — local/remote workspace
/// identity and the `ssh://[user@]host[:port]/abs/path` open scheme.
library;

import 'package:clide/kernel/kernel.dart';
import 'package:test/test.dart';

void main() {
  group('WorkspaceRef.parse — local', () {
    test('a bare path is a local ref', () {
      final ref = WorkspaceRef.parse('/var/repo');
      expect(ref, const WorkspaceRef.local('/var/repo'));
      expect(ref!.isRemote, isFalse);
      expect(ref.uri, '/var/repo');
      expect(ref.display, '/var/repo');
    });

    test('a relative path stays a local ref verbatim', () {
      expect(WorkspaceRef.parse('repo'), const WorkspaceRef.local('repo'));
    });
  });

  group('WorkspaceRef.parse — ssh://', () {
    test('host + path', () {
      final ref = WorkspaceRef.parse('ssh://buildbox/srv/repo');
      expect(ref, WorkspaceRef.remote(host: 'buildbox', path: '/srv/repo'));
      expect(ref!.isRemote, isTrue);
      expect(ref.port, isNull);
      expect(ref.user, isNull);
    });

    test('user@host:port + path', () {
      final ref = WorkspaceRef.parse('ssh://jeroen@buildbox:2222/srv/repo');
      expect(ref!.user, 'jeroen');
      expect(ref.host, 'buildbox');
      expect(ref.port, 2222);
      expect(ref.path, '/srv/repo');
    });

    test('uri round-trips through parse', () {
      const refs = [
        WorkspaceRef.local('/var/repo'),
        WorkspaceRef.remote(host: 'buildbox', path: '/srv/repo'),
        WorkspaceRef.remote(host: 'buildbox', path: '/srv/repo', port: 2222, user: 'jeroen'),
      ];
      for (final ref in refs) {
        expect(WorkspaceRef.parse(ref.uri), ref, reason: ref.uri);
      }
    });

    test('display is host:path', () {
      expect(WorkspaceRef.remote(host: 'buildbox', path: '/srv/repo').display, 'buildbox:/srv/repo');
    });

    test('missing host or missing path is rejected', () {
      expect(WorkspaceRef.parse('ssh:///srv/repo'), isNull);
      expect(WorkspaceRef.parse('ssh://buildbox'), isNull);
      expect(WorkspaceRef.parse('ssh://buildbox/'), isNull);
    });

    test('garbage after the scheme is rejected, not crashed on', () {
      expect(WorkspaceRef.parse('ssh://[::bad'), isNull);
    });
  });

  group('WorkspaceRef equality', () {
    test('value equality + hashCode', () {
      expect(WorkspaceRef.remote(host: 'h', path: '/p'), WorkspaceRef.remote(host: 'h', path: '/p'));
      expect(WorkspaceRef.remote(host: 'h', path: '/p').hashCode, WorkspaceRef.remote(host: 'h', path: '/p').hashCode);
      expect(WorkspaceRef.remote(host: 'h', path: '/p'), isNot(const WorkspaceRef.local('/p')));
      expect(WorkspaceRef.remote(host: 'h', path: '/p', port: 22), isNot(WorkspaceRef.remote(host: 'h', path: '/p')));
    });

    test('toString carries the uri form', () {
      expect(WorkspaceRef.remote(host: 'h', path: '/p').toString(), contains('ssh://h/p'));
    });
  });
}
