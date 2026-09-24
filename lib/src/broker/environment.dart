/// The broker's configuration from the environment it runs with (D-121):
/// where its store is, its secrets, and overrides of stored settings.
library;

import 'dart:io';

/// The environment is missing something or holds a bad value. The message
/// names the variable and never repeats a value, which may be a secret.
class BrokerConfigException implements Exception {
  BrokerConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The secret in [variable], or in the file its `_FILE` variant names, such
/// as a Docker secret; null when neither is set. A file's final newline is
/// not part of the secret.
String? secretFromEnvironment(Map<String, String> environment, String variable, {String Function(String path)? readFile}) {
  final fileVariable = '${variable}_FILE';
  final direct = environment[variable] ?? '';
  final path = environment[fileVariable] ?? '';
  if (direct.isNotEmpty && path.isNotEmpty) throw BrokerConfigException('Set $variable or $fileVariable, not both.');
  if (path.isEmpty) return direct.isEmpty ? null : direct;
  final String contents;
  try {
    contents = (readFile ?? (p) => File(p).readAsStringSync())(path);
  } on FileSystemException {
    throw BrokerConfigException('$fileVariable names a file that cannot be read: $path');
  }
  final secret = contents.endsWith('\r\n')
      ? contents.substring(0, contents.length - 2)
      : contents.endsWith('\n')
      ? contents.substring(0, contents.length - 1)
      : contents;
  if (secret.isEmpty) throw BrokerConfigException('$fileVariable names an empty file: $path');
  return secret;
}
