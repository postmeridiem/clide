/// State + grammar + execution for the Vim ex command-line overlay (T-407).
///
/// `:` (under `vim.normal`) opens a transient one-line prompt that runs a
/// small, fixed table of ex commands (`:w` `:q` `:wq` `:x` `:e <path>` `:N`).
/// It is NOT a vim *mode* — it's an overlay with its own `exline.open` scope
/// flag, dismissed with Esc, exactly the deferral `vim_mode_service.dart`
/// always named. The controller mirrors [QuickOpenController]'s open/close
/// shape so the overlay can reuse the quick-open chrome.
///
/// The command grammar ([parseExCommand]) is a pure switch — no parser, no
/// vimscript. Execution ([exWriteActive] etc.) goes through the editor IPC
/// verbs (the daemon is the source of truth for buffer state), so every ex
/// command is editor-targeted and no-ops when no buffer is active (the
/// 2026-06-13 decision on T-407).
library;

import 'dart:async';

import 'package:clide/clide.dart' show IpcResponse;
import 'package:clide/kernel/src/ipc/client.dart';
import 'package:flutter/foundation.dart';

class ExLineController extends ChangeNotifier {
  bool _open = false;
  String _input = '';
  // Bumped each time an unknown command is rejected so the overlay can flash
  // without closing. A monotonic nonce (not a bool) keeps repeated rejections
  // individually observable by a listener.
  int _invalidNonce = 0;

  bool get isOpen => _open;
  String get input => _input;

  /// Increments whenever a typed command is rejected ([flashInvalid]); the
  /// overlay watches it to flash the input and stay open.
  int get invalidNonce => _invalidNonce;

  void open() {
    if (_open) return;
    _open = true;
    _input = '';
    notifyListeners();
  }

  void close() {
    if (!_open) return;
    _open = false;
    _input = '';
    notifyListeners();
  }

  void setInput(String value) {
    if (_input == value) return;
    _input = value;
    notifyListeners();
  }

  /// Signal that the submitted command was unknown — the overlay flashes and
  /// stays open rather than executing or dismissing.
  void flashInvalid() {
    _invalidNonce++;
    notifyListeners();
  }
}

// --- Grammar ---------------------------------------------------------------

/// One parsed ex command. v1 table; anything off it is [ExUnknown].
sealed class ExCommand {
  const ExCommand();
}

/// Empty input (`:` then Enter) — dismiss with no action.
class ExNoop extends ExCommand {
  const ExNoop();
}

/// `:w` — write (save) the active buffer.
class ExWrite extends ExCommand {
  const ExWrite();
}

/// `:q` (and `:q!`) — close the active editor tab.
class ExQuit extends ExCommand {
  const ExQuit();
}

/// `:wq` / `:x` (and bang variants) and `ZZ` — save then close the active tab.
class ExWriteQuit extends ExCommand {
  const ExWriteQuit();
}

/// `:e <path>` — open quick-open seeded with `<path>` (empty seed allowed).
class ExEdit extends ExCommand {
  const ExEdit(this.query);
  final String query;

  @override
  bool operator ==(Object other) => other is ExEdit && other.query == query;
  @override
  int get hashCode => query.hashCode;
}

/// `:<n>` — jump the active buffer to 1-based line `<n>`.
class ExGoto extends ExCommand {
  const ExGoto(this.line);
  final int line;

  @override
  bool operator ==(Object other) => other is ExGoto && other.line == line;
  @override
  int get hashCode => line.hashCode;
}

/// Anything not on the v1 table — the overlay flashes and stays open.
class ExUnknown extends ExCommand {
  const ExUnknown();
}

/// Parse the text typed after `:` into an [ExCommand]. A leading colon is
/// tolerated (in case the user types it). v1 grammar only.
ExCommand parseExCommand(String raw) {
  var s = raw.trim();
  if (s.startsWith(':')) s = s.substring(1).trim();
  if (s.isEmpty) return const ExNoop();

  // `:e` / `:e <path>` — everything after the first token seeds quick-open.
  if (s == 'e') return const ExEdit('');
  if (s.startsWith('e ')) return ExEdit(s.substring(2).trim());

  switch (s) {
    case 'w':
      return const ExWrite();
    case 'q' || 'q!':
      // No dirty-guard in v1, so `q!` is just `q`.
      return const ExQuit();
    case 'wq' || 'wq!' || 'x' || 'x!':
      return const ExWriteQuit();
  }

  final line = int.tryParse(s);
  if (line != null && line >= 1) return ExGoto(line);

  return const ExUnknown();
}

// --- Execution (editor-targeted; no-op when no active buffer) ---------------

/// The active editor buffer id, or null when no buffer is active.
Future<String?> activeEditorBufferId(DaemonClient ipc) async {
  final IpcResponse r = await ipc.request('editor.active');
  if (!r.ok) return null;
  final active = r.data['active'];
  return active is Map ? active['id'] as String? : null;
}

/// `:w` — save the active buffer. `editor.save` resolves the active buffer
/// server-side, so a missing buffer is a silent no-op.
Future<void> exWriteActive(DaemonClient ipc) async {
  await ipc.request('editor.save');
}

/// `:q` — close the active editor tab. The registry promotes the next buffer
/// (or collapses the split on the last one) — no separate split-close needed.
Future<void> exQuitActive(DaemonClient ipc) async {
  final id = await activeEditorBufferId(ipc);
  if (id == null) return;
  await ipc.request('editor.close', args: {'id': id});
}

/// `:wq` / `:x` / `ZZ` — save the active buffer then close its tab.
Future<void> exWriteQuitActive(DaemonClient ipc) async {
  final id = await activeEditorBufferId(ipc);
  if (id == null) return;
  await ipc.request('editor.save', args: {'id': id});
  await ipc.request('editor.close', args: {'id': id});
}

/// `:<n>` — jump the active buffer to 1-based [line]. `editor.goto-line`
/// resolves the active buffer server-side and clamps out-of-range lines.
Future<void> exGotoLineActive(DaemonClient ipc, int line) async {
  await ipc.request('editor.goto-line', args: {'line': line});
}
