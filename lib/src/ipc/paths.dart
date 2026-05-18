import 'dart:io';

/// Resolve the per-workspace Unix-domain socket path served by the
/// running clide app. Per D-70:
///
///   Linux:  `$XDG_RUNTIME_DIR/clide/<hash>.sock`
///   macOS:  `$HOME/Library/Caches/clide/<hash>.sock`
///
/// The C `clide` client and any other consumer derive the same path
/// from the same workspace root, so server + client always agree
/// without configuration.
String workspaceSocketPath(String workspaceRoot) {
  final dir = socketDirectory();
  return '$dir/${_hash(workspaceRoot)}.sock';
}

/// Parent directory that holds every per-workspace socket for this
/// user. Created with `0700` on bind (see D-71). Exposed separately
/// so the server can prepare/perm-fix the directory before binding.
String socketDirectory() {
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return '$home/Library/Caches/clide';
  }
  final xdg = Platform.environment['XDG_RUNTIME_DIR'];
  final base = (xdg != null && xdg.isNotEmpty) ? xdg : '/tmp';
  return '$base/clide';
}

/// FNV-1a 64-bit, lower-case hex, fixed 16 chars. Matches the shape
/// used by `lib/builtin/claude/src/session_naming.dart#_hash`. Not a
/// cryptographic hash — D-70 explains why one isn't needed here.
String _hash(String s) {
  // 0xcbf29ce484222325 as two 32-bit halves to dodge JS-precision
  // issues if this file ever runs under the web target.
  var hiHi = 0xcbf2, hiLo = 0x9ce4;
  var loHi = 0x8422, loLo = 0x2325;
  const primeHiHi = 0x0000, primeHiLo = 0x0100;
  const primeLoHi = 0x0000, primeLoLo = 0x01b3;
  for (var i = 0; i < s.length; i++) {
    loLo ^= s.codeUnitAt(i) & 0xffff;
    // 64-bit multiply, hand-rolled across four 16-bit limbs.
    final r0 = loLo * primeLoLo;
    final r1 = (loLo * primeLoHi) + (loHi * primeLoLo) + (r0 >> 16);
    final r2 = (loLo * primeHiLo) + (loHi * primeLoHi) + (hiLo * primeLoLo) + (r1 >> 16);
    final r3 = (loLo * primeHiHi) + (loHi * primeHiLo) + (hiLo * primeLoHi) + (hiHi * primeLoLo) + (r2 >> 16);
    loLo = r0 & 0xffff;
    loHi = r1 & 0xffff;
    hiLo = r2 & 0xffff;
    hiHi = r3 & 0xffff;
  }
  String hex4(int v) => v.toRadixString(16).padLeft(4, '0');
  return '${hex4(hiHi)}${hex4(hiLo)}${hex4(loHi)}${hex4(loLo)}';
}
