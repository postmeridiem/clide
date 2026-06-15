import 'dart:convert';
import 'dart:io';

/// Resolve the per-workspace Unix-domain socket path served by the
/// running clide app. Per D-70:
///
///   Linux:   `$XDG_RUNTIME_DIR/clide/<hash>.sock`
///   macOS:   `$HOME/Library/Caches/clide/<hash>.sock`
///   Windows: `%LOCALAPPDATA%\clide\<hash>.sock` (AF_UNIX — supported
///            by winsock since Windows 10 1803 and by dart:io)
///
/// The C `clide` client and any other consumer derive the same path
/// from the same workspace root, so server + client always agree
/// without configuration.
String workspaceSocketPath(String workspaceRoot) {
  final dir = socketDirectory();
  return '$dir/${_hash(canonicalWorkspaceKey(workspaceRoot))}.sock';
}

/// Canonical form of the workspace root used as the FNV hash input.
///
/// On Windows one directory has many spellings — either slash kind,
/// any letter case (NTFS is case-insensitive and getcwd preserves
/// whatever the shell typed) — so the server and the C client could
/// derive different hashes for the same workspace. Backslash +
/// ASCII-lower-case is the canonical spelling; the C client applies
/// the same byte-level fold (which is why this is NOT Unicode
/// `toLowerCase()` — the fold must be reproducible over raw UTF-8
/// bytes in C). POSIX paths pass through untouched.
String canonicalWorkspaceKey(String workspaceRoot) {
  if (!Platform.isWindows) return workspaceRoot;
  final folded = workspaceRoot.replaceAll('/', r'\');
  final units = folded.codeUnits.map((u) => (u >= 0x41 && u <= 0x5a) ? u + 0x20 : u).toList();
  return String.fromCharCodes(units);
}

/// Parent directory that holds every per-workspace socket for this
/// user. Created with `0700` on bind (see D-71; on Windows the
/// per-user ACL on `%LOCALAPPDATA%` is the equivalent gate). Exposed
/// separately so the server can prepare/perm-fix the directory before
/// binding.
String socketDirectory() {
  if (Platform.isWindows) {
    final local = Platform.environment['LOCALAPPDATA'];
    final base = (local != null && local.isNotEmpty) ? local : '${Platform.environment['USERPROFILE'] ?? r'C:\'}\\AppData\\Local';
    return '$base\\clide';
  }
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return '$home/Library/Caches/clide';
  }
  final xdg = Platform.environment['XDG_RUNTIME_DIR'];
  final base = (xdg != null && xdg.isNotEmpty) ? xdg : '/tmp';
  return '$base/clide';
}

/// Persistent per-platform directory for crash-survivable logs (T-425).
///
///   Linux:   `$XDG_STATE_HOME/clide/logs` (else `$HOME/.local/state/...`)
///   macOS:   `$HOME/Library/Logs/clide`
///   Windows: `%LOCALAPPDATA%\clide\logs`
///
/// Unlike [socketDirectory] — which intentionally lives in an EPHEMERAL
/// runtime dir (`$XDG_RUNTIME_DIR`, `~/Library/Caches`) that the OS may wipe
/// on logout/reboot — this is a DURABLE location. The whole point of the
/// FileLogSink is that a freeze's last breadcrumbs survive the power-cycle, so
/// the log dir must outlive a reboot.
String logDirectory() {
  if (Platform.isWindows) {
    final local = Platform.environment['LOCALAPPDATA'];
    final base = (local != null && local.isNotEmpty) ? local : '${Platform.environment['USERPROFILE'] ?? r'C:\'}\\AppData\\Local';
    return '$base\\clide\\logs';
  }
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return '$home/Library/Logs/clide';
  }
  final state = Platform.environment['XDG_STATE_HOME'];
  final base = (state != null && state.isNotEmpty) ? state : '${Platform.environment['HOME'] ?? '/tmp'}/.local/state';
  return '$base/clide/logs';
}

/// FNV-1a 64-bit hash of [s] as a 16-char lower-case hex string.
/// The C client (T-126) reproduces the same algorithm byte-for-byte
/// so server + client always agree on socket path. Not cryptographic
/// — D-70 explains why one isn't needed here. The algorithm:
///
///   h = 0xcbf29ce484222325                  // FNV offset basis
///   for each byte b in utf-8(s):
///     h = (h xor b) * 0x100000001b3 mod 2^64 // FNV prime, 64-bit wrap
///
/// Reference: <http://isthe.com/chongo/tech/comp/fnv/> — FNV-1a 64-bit.
String fnv1a64Hex(String s) {
  // Desktop-only (the IPC server is desktop-only per D-56). Dart VM
  // ints are 64-bit; arithmetic wraps modulo 2^64 naturally.
  var h = 0xcbf29ce484222325;
  const prime = 0x100000001b3;
  final bytes = utf8.encode(s);
  for (final b in bytes) {
    h ^= b;
    h = h * prime; // wraps mod 2^64 on the VM (signed int64)
  }
  // Dart's `int` is signed 64-bit on the VM; once the high bit lights
  // up, `toRadixString` would emit a leading minus. Split into two
  // unsigned 32-bit halves (>>> is logical shift) and concatenate.
  final hi = (h >>> 32) & 0xffffffff;
  final lo = h & 0xffffffff;
  return '${hi.toRadixString(16).padLeft(8, '0')}${lo.toRadixString(16).padLeft(8, '0')}';
}

String _hash(String s) => fnv1a64Hex(s);
