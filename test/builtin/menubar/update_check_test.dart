/// T-47 P1: the manual update-check logic — semver comparison, repo parsing,
/// and the GitHub-release check (against a fake fetch, so no test hits the
/// network). Flutter-free.
library;

import 'dart:io';

import 'package:clide/builtin/menubar/src/update_check.dart';
import 'package:test/test.dart';

void main() {
  group('githubGet (real HTTP against a loopback server)', () {
    test('returns the body on 200 and throws on a non-200', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((req) {
        if (req.uri.path == '/ok') {
          req.response.write('{"tag_name":"v1.0.0"}');
        } else {
          req.response.statusCode = 404;
        }
        req.response.close();
      });
      final base = 'http://127.0.0.1:${server.port}';
      expect(await githubGet(Uri.parse('$base/ok')), contains('v1.0.0'));
      expect(() => githubGet(Uri.parse('$base/missing')), throwsA(isA<HttpException>()));
    });
  });

  group('compareSemver', () {
    test('compares major.minor.patch numerically (2.3.10 > 2.3.9)', () {
      expect(compareSemver('2.3.10', '2.3.9'), 1);
      expect(compareSemver('2.3.9', '2.3.10'), -1);
      expect(compareSemver('2.8.1', '2.8.1'), 0);
      expect(compareSemver('3.0.0', '2.9.9'), 1);
    });

    test('a pre-release ranks below the release of the same core', () {
      expect(compareSemver('2.8.2-rc1', '2.8.2'), -1);
      expect(compareSemver('2.8.2', '2.8.2-rc1'), 1);
      expect(compareSemver('2.8.2-rc2', '2.8.2-rc1'), 1);
    });

    test('missing components count as 0', () {
      expect(compareSemver('2.8', '2.8.0'), 0);
    });
  });

  group('parseGithubRepo', () {
    test('extracts owner/repo from an https URL', () {
      final r = parseGithubRepo('https://github.com/postmeridiem/clide');
      expect(r?.owner, 'postmeridiem');
      expect(r?.repo, 'clide');
    });

    test('strips a .git suffix and the ssh form; rejects non-github', () {
      expect(parseGithubRepo('git@github.com:foo/bar.git')?.repo, 'bar');
      expect(parseGithubRepo('https://gitlab.com/x/y'), isNull);
    });
  });

  group('checkForUpdate', () {
    String release(String tag) => '{"tag_name": "$tag", "html_url": "https://github.com/postmeridiem/clide/releases/$tag"}';
    const repo = 'https://github.com/postmeridiem/clide';

    test('a newer release returns UpdateAvailable with version + url', () async {
      final r = await checkForUpdate(repositoryUrl: repo, currentVersion: '2.8.1', fetch: (_) async => release('v2.9.0'));
      expect(r, isA<UpdateAvailable>());
      expect((r as UpdateAvailable).latest, '2.9.0');
      expect(r.url, contains('releases/v2.9.0'));
    });

    test('the same or older release returns UpToDate', () async {
      expect(await checkForUpdate(repositoryUrl: repo, currentVersion: '2.8.1', fetch: (_) async => release('v2.8.1')), isA<UpdateUpToDate>());
      expect(await checkForUpdate(repositoryUrl: repo, currentVersion: '2.8.1', fetch: (_) async => release('v2.8.0')), isA<UpdateUpToDate>());
    });

    test('a fetch failure returns UpdateCheckFailed and never throws', () async {
      final r = await checkForUpdate(repositoryUrl: repo, currentVersion: '2.8.1', fetch: (_) => Future.error('offline'));
      expect(r, isA<UpdateCheckFailed>());
    });

    test('an unrecognized repo URL or a tagless response fails cleanly', () async {
      expect(await checkForUpdate(repositoryUrl: 'not-a-url', currentVersion: '2.8.1', fetch: (_) async => '{}'), isA<UpdateCheckFailed>());
      expect(await checkForUpdate(repositoryUrl: repo, currentVersion: '2.8.1', fetch: (_) async => '{}'), isA<UpdateCheckFailed>());
    });
  });
}
