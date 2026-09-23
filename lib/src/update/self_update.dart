/// Installing a newer release over an installed bundle, and moving every open
/// window onto it (T-621 — T-47 P2/P3, Linux; D-113).
///
/// [SelfUpdater.install] leaves the old install untouched until the last step:
///   1. download the release tarball next to the install dir;
///   2. check its SHA-256 against the digest GitHub recorded for the asset —
///      the interim integrity check until releases are signed (T-491);
///   3. unpack it beside the install (`<install>.new`) and make sure it holds
///      a runnable `clide`;
///   4. swap by rename — `<install>` → `<install>.old`, `.new` → `<install>` —
///      and replace the `clide` CLI client in `~/.local/bin` the same way.
///
/// [WindowRelauncher] then restarts each window on the new binary. The tray
/// loader (D-110) keeps running: its D-Bus protocol is unchanged, and once the
/// last old window exits it goes too, so the next launch starts a new one.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../ipc/envelope.dart';
import '../ipc/paths.dart';
import 'update_check.dart';

/// Where an install stands, for progress reporting.
enum UpdatePhase { downloading, verifying, unpacking, installing, restarting }

typedef UpdateProgress = void Function(UpdatePhase phase, {double? fraction});

/// Download [url] into [to], reporting bytes as they arrive.
typedef BundleDownload = Future<void> Function(Uri url, File to, void Function(int received, int? total) onChunk);

/// Run a helper tool; injectable so tests never shell out for real.
typedef ToolRun = Future<ProcessResult> Function(String executable, List<String> args);

class SelfUpdateException implements Exception {
  const SelfUpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SelfUpdater {
  SelfUpdater({required this.installDir, this.cliPath, BundleDownload? download, ToolRun? run})
    : _download = download ?? httpDownload,
      _run = run ?? Process.run;

  /// The bundle directory being replaced, e.g. `~/.local/lib/clide`.
  final String installDir;

  /// The installed `clide` CLI client, replaced alongside when present.
  final String? cliPath;

  final BundleDownload _download;
  final ToolRun _run;

  /// The bundle directory [executable] runs from, or null when this run can't
  /// update itself: not Linux (the only platform releases build today), or a
  /// development/CI build under a `build/` tree rather than an installed one.
  static String? installDirOf(String executable, {bool? isLinux}) {
    if (!(isLinux ?? Platform.isLinux)) return null;
    final dir = File(executable).parent.path;
    if (dir.contains('/build/')) return null;
    return dir;
  }

  /// `~/.local/bin/clide` when it exists — where `make install` puts the CLI.
  static String? installedCli(Map<String, String> env) {
    final home = env['HOME'];
    if (home == null || home.isEmpty) return null;
    final path = '$home/.local/bin/clide';
    return File(path).existsSync() ? path : null;
  }

  /// Download, verify, unpack and swap in [bundle]. Throws
  /// [SelfUpdateException] with the old install intact on any failure before
  /// the swap; a failed swap is rolled back.
  Future<void> install(ReleaseBundle bundle, {UpdateProgress? onProgress}) async {
    final parent = Directory(installDir).parent.path;
    final tarball = File('$parent/.clide-update-${bundle.name}');
    final staged = Directory('$installDir.new');
    try {
      onProgress?.call(UpdatePhase.downloading, fraction: 0);
      await _download(Uri.parse(bundle.url), tarball, (got, total) {
        final all = total ?? bundle.size;
        onProgress?.call(UpdatePhase.downloading, fraction: all > 0 ? got / all : null);
      });

      onProgress?.call(UpdatePhase.verifying);
      final sum = await _sha256(tarball);
      if (sum != bundle.sha256) throw SelfUpdateException('checksum mismatch — expected ${bundle.sha256}, got $sum');

      onProgress?.call(UpdatePhase.unpacking);
      if (staged.existsSync()) staged.deleteSync(recursive: true);
      staged.createSync(recursive: true);
      await _tool('tar', ['-xzf', tarball.path, '-C', staged.path]);
      final exe = File('${staged.path}/clide');
      if (!exe.existsSync() || exe.statSync().mode & 0x49 == 0) {
        throw const SelfUpdateException('the downloaded bundle has no runnable clide');
      }

      onProgress?.call(UpdatePhase.installing);
      _swap(staged);
      await _replaceCli();
    } finally {
      if (tarball.existsSync()) tarball.deleteSync();
      // Still here only when something failed before or during the swap.
      if (staged.existsSync()) staged.deleteSync(recursive: true);
    }
  }

  Future<String> _sha256(File f) async {
    final out = await _tool('sha256sum', [f.path]);
    return out.split(RegExp(r'\s+')).first.toLowerCase();
  }

  /// Old install → `.old` (replacing a previous one), staged → install. On a
  /// failed second rename the old install goes back where it was.
  void _swap(Directory staged) {
    final old = Directory('$installDir.old');
    if (old.existsSync()) old.deleteSync(recursive: true);
    Directory(installDir).renameSync(old.path);
    try {
      staged.renameSync(installDir);
    } catch (e) {
      Directory(old.path).renameSync(installDir);
      throw SelfUpdateException('could not move the new version into place: $e');
    }
  }

  /// Replace the CLI client with the bundle's copy: install beside it, then
  /// rename over it, so a `clide` call mid-update sees the old or the new
  /// file, never half of one.
  Future<void> _replaceCli() async {
    final cli = cliPath;
    final fresh = File('$installDir/clide-cli');
    if (cli == null || !fresh.existsSync()) return;
    await _tool('install', ['-m', '755', fresh.path, '$cli.new']);
    File('$cli.new').renameSync(cli);
  }

  Future<String> _tool(String exe, List<String> args) async {
    final r = await _run(exe, args);
    if (r.exitCode != 0) throw SelfUpdateException('$exe failed: ${'${r.stderr}'.trim()}');
    return '${r.stdout}';
  }
}

/// Stream [url] into [to] (GitHub redirects asset downloads; [HttpClient]
/// follows them). A non-200 answer throws.
Future<void> httpDownload(Uri url, File to, void Function(int received, int? total) onChunk) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(url);
    req.headers.set(HttpHeaders.userAgentHeader, 'clide');
    final resp = await req.close();
    if (resp.statusCode != 200) throw SelfUpdateException('download failed: HTTP ${resp.statusCode}');
    final total = resp.contentLength >= 0 ? resp.contentLength : null;
    final sink = to.openWrite();
    var got = 0;
    try {
      await for (final chunk in resp) {
        sink.add(chunk);
        got += chunk.length;
        onChunk(got, total);
      }
    } finally {
      await sink.close();
    }
  } finally {
    client.close();
  }
}

/// Environment variable that tells a starting window it replaces one that is
/// still shutting down: its IPC server waits for the socket instead of
/// refusing to bind (D-113).
const kRelaunchEnv = 'CLIDE_RELAUNCH';

/// Restarts clide windows on the binary at [executable].
class WindowRelauncher {
  WindowRelauncher({
    required this.executable,
    String? socketDir,
    Map<String, String>? environment,
    Future<Process> Function(String exe, String cwd, Map<String, String> env)? start,
  }) : _socketDir = socketDir ?? socketDirectory(),
       _environment = environment ?? Platform.environment,
       _start = start ?? _startDetached;

  final String executable;
  final String _socketDir;
  final Map<String, String> _environment;
  final Future<Process> Function(String exe, String cwd, Map<String, String> env) _start;

  static Future<Process> _startDetached(String exe, String cwd, Map<String, String> env) =>
      Process.start(exe, const [], workingDirectory: cwd, mode: ProcessStartMode.detached, environment: env, includeParentEnvironment: false);

  /// Start a window for [root]. It picks its workspace from its working
  /// directory, never inherits this window's IPC identity (T-421), and waits
  /// for [root]'s socket to be released ([kRelaunchEnv]).
  Future<void> launch(String root) => _start(executable, root, {...withoutWindowIdentity(_environment), kRelaunchEnv: '1'});

  /// Every other live clide window — its socket and workspace root, asked via
  /// `files.root`. Sockets that don't answer are skipped.
  Future<List<({String socket, String root})>> siblings({required String ownSocket}) async {
    final dir = Directory(_socketDir);
    if (!dir.existsSync()) return const [];
    final out = <({String socket, String root})>[];
    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.sock') || f.path == ownSocket) continue;
      final r = await ipcOneShot(f.path, 'files.root');
      final root = r != null && r.ok ? r.data['path'] : null;
      if (root is String && root.isNotEmpty) out.add((socket: f.path, root: root));
    }
    return out;
  }

  /// Move every other window onto the new binary: start its replacement,
  /// then ask the old one to quit. Returns how many were restarted.
  Future<int> relaunchSiblings({required String ownSocket}) async {
    var n = 0;
    for (final s in await siblings(ownSocket: ownSocket)) {
      await launch(s.root);
      await ipcOneShot(s.socket, 'app.quit');
      n++;
    }
    return n;
  }
}

/// One request/response over a window's socket; null when it doesn't answer.
Future<IpcResponse?> ipcOneShot(String socketPath, String cmd, {Map<String, Object?> args = const {}, Duration timeout = const Duration(seconds: 2)}) async {
  Socket? s;
  try {
    s = await Socket.connect(InternetAddress(socketPath, type: InternetAddressType.unix), 0).timeout(timeout);
    s.write('${IpcRequest(id: 'update-$cmd', cmd: cmd, args: args).encode()}\n');
    await for (final line in s.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).timeout(timeout)) {
      final msg = IpcMessage.decode(line);
      if (msg is IpcResponse) return msg;
    }
    return null;
  } catch (_) {
    return null;
  } finally {
    s?.destroy();
  }
}
