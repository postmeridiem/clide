/// Tests for the workspace file-path resolver behind clickable conversation
/// references (T-300): only real files under the repo root resolve; relative
/// tokens resolve against the root, absolute tokens must already live inside it,
/// and `..` escapes are rejected.
library;

import 'dart:io';

import 'package:clide/builtin/claude/src/conversation_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('clide_wsfile_');
    await File('${root.path}/lib/app.dart').create(recursive: true);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('a relative path that exists resolves to its absolute path', () {
    expect(resolveWorkspaceFilePath(root.path, 'lib/app.dart'), '${root.path}/lib/app.dart');
  });

  test('an absolute path inside the root resolves', () {
    expect(resolveWorkspaceFilePath(root.path, '${root.path}/lib/app.dart'), '${root.path}/lib/app.dart');
  });

  test('a nonexistent path is null', () {
    expect(resolveWorkspaceFilePath(root.path, 'lib/ghost.dart'), isNull);
  });

  test('a directory is not a file', () {
    expect(resolveWorkspaceFilePath(root.path, 'lib'), isNull);
  });

  test('an absolute path outside the root is rejected', () {
    expect(resolveWorkspaceFilePath(root.path, '/etc/passwd'), isNull);
  });

  test('a `..` escape is rejected', () {
    expect(resolveWorkspaceFilePath(root.path, '../escape.dart'), isNull);
  });

  test('a null root (no project open) is null', () {
    expect(resolveWorkspaceFilePath(null, 'lib/app.dart'), isNull);
  });

  test('an empty token is null', () {
    expect(resolveWorkspaceFilePath(root.path, ''), isNull);
  });
}
