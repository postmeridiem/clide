import 'package:clide/src/env/supporter_binaries.dart';
import 'package:test/test.dart';

void main() {
  SupporterBinaries make({Map<String, String> overrides = const {}, Set<String> files = const {}, String path = '/usr/bin:/bin', String home = '/home/u'}) =>
      SupporterBinaries(overrides: overrides, exists: files.contains, searchPath: () => path, home: home);

  group('resolve', () {
    test('an explicit override wins', () {
      final r = make(overrides: {'d2': '/opt/d2'}, files: {'/opt/d2', '/usr/bin/d2'});
      expect(r.resolve('d2'), '/opt/d2');
    });

    test('a stale override falls through to the PATH', () {
      final r = make(overrides: {'d2': '/gone/d2'}, files: {'/usr/bin/d2'});
      expect(r.resolve('d2'), '/usr/bin/d2');
    });

    test('searches the PATH when there is no override', () {
      final r = make(files: {'/bin/d2'});
      expect(r.resolve('d2'), '/bin/d2');
    });

    test('finds a tool in linuxbrew via the well-known dirs (the D-104 gap)', () {
      final r = make(files: {'/home/linuxbrew/.linuxbrew/bin/d2'});
      expect(r.resolve('d2'), '/home/linuxbrew/.linuxbrew/bin/d2');
    });

    test('finds a tool in ~/.local/bin', () {
      final r = make(files: {'/home/u/.local/bin/pql'}, path: '/usr/bin');
      expect(r.resolve('pql'), '/home/u/.local/bin/pql');
    });

    test('returns null when unresolved', () {
      expect(make().resolve('nope'), isNull);
    });
  });

  group('isStalePin', () {
    test('true when the override points at a missing file', () {
      expect(make(overrides: {'d2': '/gone'}).isStalePin('d2'), isTrue);
    });
    test('false when the override exists', () {
      expect(make(overrides: {'d2': '/ok'}, files: {'/ok'}).isStalePin('d2'), isFalse);
    });
    test('false when there is no override', () {
      expect(make().isStalePin('d2'), isFalse);
    });
  });

  group('detect', () {
    test('finds tools across the PATH and well-known dirs', () {
      final r = make(files: {'/usr/bin/claude', '/home/linuxbrew/.linuxbrew/bin/d2'}, path: '/usr/bin');
      expect(r.detect(['claude', 'd2', 'missing']), {'claude': '/usr/bin/claude', 'd2': '/home/linuxbrew/.linuxbrew/bin/d2'});
    });

    test('prefers the earliest matching directory', () {
      final r = make(files: {'/usr/bin/d2', '/home/linuxbrew/.linuxbrew/bin/d2'}, path: '/usr/bin');
      expect(r.detect(['d2'])['d2'], '/usr/bin/d2');
    });
  });
}
