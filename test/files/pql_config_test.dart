/// Tests for `readIgnoreFiles` — resolving the clide-owned
/// `ignore_files:` key from `.pql/config.yaml` (D-3 / D-4).
library;

import 'dart:io';

import 'package:clide/src/files/pql_config.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('clide-pqlconfig-');
  });
  tearDown(() async {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  void writeConfig(String body) {
    Directory('${root.path}/.pql').createSync();
    File('${root.path}/.pql/config.yaml').writeAsStringSync(body);
  }

  test('no config → defaults to [.gitignore]', () {
    expect(readIgnoreFiles(root), ['.gitignore']);
  });

  test('no config but .clideignore present → adds it after .gitignore', () {
    File('${root.path}/.clideignore').writeAsStringSync('build/\n');
    expect(readIgnoreFiles(root), ['.gitignore', '.clideignore']);
  });

  test('explicit ignore_files list is honoured verbatim and in order', () {
    writeConfig('ignore_files: [.gitignore, .pqlignore]\n');
    expect(readIgnoreFiles(root), ['.gitignore', '.pqlignore']);
  });

  test('explicit empty list disables file-based exclusions', () {
    writeConfig('ignore_files: []\n');
    expect(readIgnoreFiles(root), isEmpty);
  });

  test('config present but key absent → default (ignores .clideignore rule only via default)', () {
    writeConfig('frontmatter: yaml\n');
    expect(readIgnoreFiles(root), ['.gitignore']);
  });

  test('non-string entries are dropped from the list', () {
    writeConfig('ignore_files: [.gitignore, 42, .pqlignore]\n');
    expect(readIgnoreFiles(root), ['.gitignore', '.pqlignore']);
  });

  test('malformed YAML falls back to the default (never throws)', () {
    writeConfig('ignore_files: [unterminated\n:::bad');
    expect(readIgnoreFiles(root), ['.gitignore']);
  });

  test('ignore_files set to a scalar (not a list) falls back to default', () {
    writeConfig('ignore_files: .gitignore\n');
    expect(readIgnoreFiles(root), ['.gitignore']);
  });
}
