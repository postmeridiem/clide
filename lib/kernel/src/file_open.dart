/// The single dispatch point for opening a workspace file the way
/// clide routes file activations (T-51 / T-187):
///   * `.md` paths → the markdown reader, via the kernel MessageBus;
///   * every other path → the editor, via the `editor.open` IPC verb.
///
/// Records the open in [KernelServices.recentFiles] so the quick-open
/// overlay's empty-query state reflects it. Shared by the files panel
/// and the quick-open overlay so the routing stays in one place.
library;

import 'dart:async';

import 'package:clide/kernel/src/facade.dart';

void openWorkspaceFile(KernelServices services, String path) {
  if (path.isEmpty) return;
  services.recentFiles.push(path);
  if (path.toLowerCase().endsWith('.md')) {
    services.messages.publish('builtin.markdown', 'selection', {'path': path});
  } else {
    unawaited(services.ipc.request('editor.open', args: {'path': path}));
  }
}
