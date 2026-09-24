import 'dart:io';

import 'package:clide/src/broker/environment.dart';
import 'package:test/test.dart';

void main() {
  String files(String path) => switch (path) {
    '/s/lf' => 'secret\n',
    '/s/crlf' => 'secret\r\n',
    '/s/two' => 'secret\n\n',
    '/s/bare' => 'secret',
    '/s/empty' => '\n',
    _ => throw FileSystemException('missing', path),
  };

  String? secret(Map<String, String> environment) => secretFromEnvironment(environment, 'CLIDE_BROKER_X', readFile: files);

  test('reads the variable, and treats an empty one as unset', () {
    expect(secret({'CLIDE_BROKER_X': 'secret'}), 'secret');
    expect(secret({'CLIDE_BROKER_X': ''}), isNull);
    expect(secret({}), isNull);
  });

  test("reads the _FILE variant's file without its final newline, and only that one", () {
    expect(secret({'CLIDE_BROKER_X_FILE': '/s/lf'}), 'secret');
    expect(secret({'CLIDE_BROKER_X_FILE': '/s/crlf'}), 'secret');
    expect(secret({'CLIDE_BROKER_X_FILE': '/s/bare'}), 'secret');
    expect(secret({'CLIDE_BROKER_X_FILE': '/s/two'}), 'secret\n');
  });

  test('refuses both at once, an unreadable file and an empty one', () {
    Matcher refused(String part) => throwsA(isA<BrokerConfigException>().having((e) => e.message, 'message', contains(part)));
    expect(() => secret({'CLIDE_BROKER_X': 'a', 'CLIDE_BROKER_X_FILE': '/s/lf'}), refused('not both'));
    expect(() => secret({'CLIDE_BROKER_X_FILE': '/s/missing'}), refused('CLIDE_BROKER_X_FILE names a file that cannot be read'));
    expect(() => secret({'CLIDE_BROKER_X_FILE': '/s/empty'}), refused('empty file'));
  });
}
