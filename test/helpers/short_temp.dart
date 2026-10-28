/// Temp directories short enough to hold a unix socket. Flutter-free on
/// purpose, so both `dart test` and `flutter test` files can import it.
library;

import 'dart:io';

/// A fresh temp directory whose path leaves room for a socket under it.
///
/// A unix socket path is capped at 104 bytes on macOS, and macOS's own
/// temp directory (`/var/folders/…/T/`) spends about half of that, so a
/// socket a few directories down fails to bind. There it is made under
/// `/tmp`; elsewhere under the system temp directory as usual.
Directory shortTempDir(String prefix) {
  final root = Platform.isMacOS ? Directory('/tmp') : Directory.systemTemp;
  return root.createTempSync(prefix);
}
