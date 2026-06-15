/// Flutter-free logic for the "Install clide command in PATH" affordance
/// (T-212).
///
/// Detects whether the `clide` shell command resolves on PATH and points at
/// the real C client — not a stale symlink to the Flutter GUI runner, the
/// exact footgun a live dogfood hit: a `~/.local/bin/clide` symlink into the
/// GUI bundle launched a *second* app instead of querying the IPC socket. The
/// installer copies the bundled C client into a PATH dir, VS Code
/// "Install code command" style.
///
/// Kept Flutter-free (only `dart:io`) so it runs under `dart test`; the
/// builtin extension wraps it with the command + notification surfaces.
library;

import 'dart:io';

/// State of the `clide` shell command relative to the running GUI.
enum CliInstallState {
  /// No `clide` resolves on PATH.
  missing,

  /// `clide` resolves but points at the Flutter GUI runner, not the C
  /// client — running it launches a second app instead of querying.
  staleGui,

  /// `clide` resolves to a dev-tree build artifact (`native/<plat>/clide`),
  /// not a packaged production install (T-256). A working client — fine on a
  /// dev checkout — but worth surfacing so it isn't mistaken for a real
  /// install, and so a rebuild/reinstall isn't silently skipped.
  devTree,

  /// `clide` resolves to something that is not the GUI or a dev build —
  /// assumed a good production install.
  installed,
}

/// Result of [CliInstaller.inspect]: what `clide` on PATH points at.
class CliInstallStatus {
  const CliInstallStatus(this.state, {this.pathEntry, this.resolvedTarget});

  final CliInstallState state;

  /// The `clide` entry found on PATH (the symlink/file itself), if any.
  final String? pathEntry;

  /// Where [pathEntry] resolves to after following symlinks, if any.
  final String? resolvedTarget;

  /// True when the user should (re)install — `clide` is absent or points at
  /// the GUI. A dev-tree build is intentional on a checkout, so it doesn't
  /// trigger an install prompt.
  bool get needsInstall => state == CliInstallState.missing || state == CliInstallState.staleGui;
}

/// Result of [CliInstaller.install].
class CliInstallResult {
  const CliInstallResult({required this.ok, required this.message, this.installedPath, this.onPath = true, this.fromDevTree = false});

  final bool ok;
  final String message;
  final String? installedPath;

  /// False when [installedPath]'s directory is not itself on PATH (the copy
  /// succeeded but the user must add the dir to PATH to reach `clide`).
  final bool onPath;

  /// True when the source copied was a dev-tree build artifact rather than the
  /// bundled production client (T-256) — a packaged install ships the latter.
  final bool fromDevTree;
}

/// Copies the bundled C client onto PATH and reports what `clide` currently
/// resolves to. Every external dependency (the running executable, the
/// environment, candidate client locations, the target dir) is injectable so
/// the logic is unit-testable without a real install.
class CliInstaller {
  CliInstaller({required this.resolvedExecutable, Map<String, String>? env, List<String>? bundledClientCandidates, String? installDir})
    : env = env ?? Platform.environment,
      bundledClientCandidates = bundledClientCandidates ?? _defaultBundledCandidates(resolvedExecutable, env ?? Platform.environment),
      installDir = installDir ?? _defaultInstallDir(env ?? Platform.environment);

  /// Path to the running Flutter GUI executable
  /// (`Platform.resolvedExecutable`).
  final String resolvedExecutable;

  final Map<String, String> env;

  /// Ordered locations to look for the bundled C client to install from.
  final List<String> bundledClientCandidates;

  /// Directory the C client is installed into (created if absent).
  final String installDir;

  /// First bundled C client candidate that exists, or null.
  String? findBundledClient() {
    for (final c in bundledClientCandidates) {
      if (c.isNotEmpty && File(c).existsSync()) return c;
    }
    return null;
  }

  /// Inspect the current state of `clide` on PATH. Filesystem-only — never
  /// execs the binary, since exec'ing a stale GUI symlink is exactly the bug
  /// this guards against (it would launch a second app).
  CliInstallStatus inspect() {
    final found = _findOnPath('clide');
    if (found == null) return const CliInstallStatus(CliInstallState.missing);
    final resolved = _resolve(found);
    if (_isGui(resolved)) {
      return CliInstallStatus(CliInstallState.staleGui, pathEntry: found, resolvedTarget: resolved);
    }
    if (isDevTreeClient(resolved)) {
      return CliInstallStatus(CliInstallState.devTree, pathEntry: found, resolvedTarget: resolved);
    }
    return CliInstallStatus(CliInstallState.installed, pathEntry: found, resolvedTarget: resolved);
  }

  /// Copy the bundled C client to `<installDir>/clide` (overwriting any stale
  /// entry) and mark it executable.
  CliInstallResult install() {
    final src = findBundledClient();
    if (src == null) {
      return const CliInstallResult(
        ok: false,
        message:
            'No bundled clide client found to install. Build with '
            '`make build` so the C client ships inside the app bundle.',
      );
    }
    final dest = '${_normalize(installDir)}/clide${Platform.isWindows ? '.exe' : ''}';
    try {
      Directory(installDir).createSync(recursive: true);
      // Delete any existing entry first so a stale symlink (e.g. one into
      // the GUI bundle) is replaced, not followed. typeSync never throws —
      // a missing path reports notFound.
      if (FileSystemEntity.typeSync(dest, followLinks: false) != FileSystemEntityType.notFound) {
        File(dest).deleteSync();
      }
      File(src).copySync(dest);
      _chmodExec(dest);
    } on FileSystemException catch (e) {
      return CliInstallResult(ok: false, message: 'Install failed: ${e.message}', installedPath: dest);
    }
    final onPath = _dirOnPath(installDir);
    final fromDevTree = isDevTreeClient(_resolve(src));
    final base = onPath ? 'Installed clide to $dest' : 'Installed clide to $dest — add $installDir to your PATH to use it.';
    return CliInstallResult(
      ok: true,
      installedPath: dest,
      onPath: onPath,
      fromDevTree: fromDevTree,
      message: fromDevTree ? '$base (from the dev-tree build; a packaged install ships the production client).' : base,
    );
  }

  /// True when [path] is, or sits inside, the Flutter GUI bundle. The C
  /// client is a standalone binary; the GUI runner ships alongside Flutter's
  /// asset payload (`data/flutter_assets`) or inside a macOS `.app`.
  bool _isGui(String path) {
    if (path == _resolve(resolvedExecutable)) return true;
    final dir = File(path).parent.path;
    if (Directory('$dir/data/flutter_assets').existsSync()) return true;
    if (path.contains('.app/Contents/')) return true;
    return false;
  }

  String _resolve(String path) {
    try {
      return File(path).resolveSymbolicLinksSync();
    } on FileSystemException {
      return path;
    }
  }

  void _chmodExec(String path) {
    if (Platform.isWindows) return;
    // dart:io has no chmod; copySync drops the source's +x under umask.
    Process.runSync('chmod', ['755', path]);
  }

  bool _dirOnPath(String dir) {
    final norm = _normalize(dir);
    return _expandedPath().split(_pathSep).any((d) => d.isNotEmpty && _normalize(d) == norm);
  }

  /// Trim a trailing slash; on Windows also fold separators and case so
  /// `C:\Users\x/.local/bin` and `c:\users\x\.local\bin` compare equal.
  String _normalize(String p) {
    var s = p;
    if (Platform.isWindows) s = s.replaceAll('\\', '/').toLowerCase();
    return s.length > 1 && s.endsWith('/') ? s.substring(0, s.length - 1) : s;
  }

  String? _findOnPath(String name) {
    for (final dir in _expandedPath().split(_pathSep)) {
      if (dir.isEmpty) continue;
      if (Platform.isWindows) {
        for (final ext in const ['.exe', '.bat', '.cmd', '']) {
          final f = File('$dir\\$name$ext');
          if (f.existsSync()) return f.path;
        }
      } else {
        final f = File('$dir/$name');
        if (f.existsSync()) return f.path;
      }
    }
    return null;
  }

  static String get _pathSep => Platform.isWindows ? ';' : ':';

  String _expandedPath() => expandedPath(env['PATH'] ?? '', macOS: Platform.isMacOS, home: env['HOME'] ?? '');

  /// `~/.local/bin` on every platform — on Windows that is
  /// `%USERPROFILE%\.local\bin`, the same convention the claude and
  /// pql installers use there.
  static String _defaultInstallDir(Map<String, String> env) => '${env['HOME'] ?? env['USERPROFILE'] ?? ''}/.local/bin';

  /// Where to find the C client to install from: a `CLIDE_CLI_BIN` dev
  /// override first, then `<exe-dir>/clide-cli` — where `make build` drops it
  /// inside the bundle (next to the GUI runner on Linux and Windows, in
  /// `Contents/MacOS/` on macOS).
  static List<String> _defaultBundledCandidates(String resolvedExecutable, Map<String, String> env) {
    final exeDir = File(resolvedExecutable).parent.path;
    return [if ((env['CLIDE_CLI_BIN'] ?? '').isNotEmpty) env['CLIDE_CLI_BIN']!, if (Platform.isWindows) '$exeDir/clide-cli.exe' else '$exeDir/clide-cli'];
  }
}

final RegExp _devTreeClient = RegExp(r'(^|/)native/(linux|macos|windows)-(x64|arm64)/clide(\.exe)?$');

/// True when [path] is a dev-tree C-client build artifact —
/// `native/<platform>/clide`, the Makefile's `CLIDE_CLI_BIN` output. On a clide
/// checkout `make run` points `CLIDE_CLI_BIN` there and a dev may put it on
/// PATH; it's a working client but not a packaged production install, so it's
/// classified separately (T-256) rather than as a clean install.
bool isDevTreeClient(String path) => _devTreeClient.hasMatch(path.replaceAll('\\', '/'));

/// Expand a `PATH` value. Mirrors `toolchain_paths.dart`: macOS GUI apps
/// launch with a sparse PATH that omits the usual user/homebrew bins, so on
/// macOS we prepend those (de-duplicated) before scanning. A top-level,
/// platform-parameterized function so both branches are testable off-platform.
String expandedPath(String base, {required bool macOS, String home = ''}) {
  if (!macOS) return base;
  final extras = <String>[if (home.isNotEmpty) '$home/.local/bin', '/opt/homebrew/bin', '/opt/homebrew/sbin', '/usr/local/bin'];
  final existing = base.split(':').toSet();
  final missing = extras.where((p) => !existing.contains(p));
  if (missing.isEmpty) return base;
  return [...missing, ...existing].join(':');
}
