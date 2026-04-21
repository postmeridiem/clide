import 'dart:io';

String defaultSocketPath() {
  final xdg = Platform.environment['XDG_RUNTIME_DIR'];
  final user = Platform.environment['USER'] ?? 'anon';
  final base = (xdg != null && xdg.isNotEmpty) ? xdg : '/tmp';
  return '$base/clide-$user.sock';
}
