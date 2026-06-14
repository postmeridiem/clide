/// Tests for the shared git plumbing in operations.dart. The legacy
/// free-function operation API (gitStage/gitCommit/...) was removed in
/// the T-385 dead-code sweep — it duplicated GitClient verb-for-verb
/// with zero non-test callers; GitClient's own tests cover the verbs.
library;

import 'dart:io';

import 'package:clide/src/git/operations.dart';
import 'package:test/test.dart';

void main() {
  test('GitException.toString includes the message', () {
    expect(const GitException('boom').toString(), contains('boom'));
  });

  test('GitLogEntry.toJson serialises every field (body omitted when empty)', () {
    const a = GitLogEntry(hash: 'h', shortHash: 's', subject: 'sub', author: 'a', date: 'd');
    expect(a.toJson(), {'hash': 'h', 'shortHash': 's', 'subject': 'sub', 'author': 'a', 'date': 'd'});
    const b = GitLogEntry(hash: 'h', shortHash: 's', subject: 'sub', author: 'a', date: 'd', body: 'bd');
    expect(b.toJson()['body'], 'bd');
  });

  test('validateGitRef accepts plain refs', () {
    expect(() => validateGitRef('main', kind: 'branch'), returnsNormally);
    expect(() => validateGitRef('feature/foo', kind: 'branch'), returnsNormally);
    expect(() => validateGitRef('origin', kind: 'remote'), returnsNormally);
  });

  test('validateGitRef rejects empty and -prefixed values (argv-injection guard)', () {
    expect(() => validateGitRef(null, kind: 'branch'), throwsA(isA<GitException>()));
    expect(() => validateGitRef('', kind: 'branch'), throwsA(isA<GitException>()));
    expect(() => validateGitRef('--upload-pack=evil', kind: 'remote'), throwsA(isA<GitException>()));
  });

  test('gitBin resolves to a runnable git', () async {
    expect(gitBin, isNotEmpty);
    final r = await Process.run(gitBin, ['--version']);
    expect(r.exitCode, 0);
  });
}
