/// ClideTestApp — standalone test harness for platform integration.
///
/// Launched via `make run-testmode`. Runs a table of tests against
/// external binaries, IPC, and extension lifecycle, prints structured
/// results to stdout, then exits. Non-zero exit on any failure.
///
/// Categories (via CLIDE_TESTMODE dart-define):
///   true / all  — run every category
///   toolchain   — binary resolution + exec only
///   ipc         — IPC dispatcher round-trip only
///   extensions  — extension register + activate only
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate' show Isolate;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

import 'builtin/diff/diff.dart';
import 'builtin/files/files.dart';
import 'builtin/git/git.dart';
import 'builtin/terminal/terminal.dart';
import 'extension/extension.dart' show ClideExtension;
import 'kernel/kernel.dart';

// Web fence (T-438, D-100): the FFI fd-inheritance probe is desktop-only; the
// web build gets a no-op stub so dart:ffi / package:ffi / libc stay out.
import 'fd_check_stub.dart' if (dart.library.ffi) 'fd_check_io.dart';
import 'src/daemon/pane_commands.dart';
import 'src/ipc/envelope.dart';
import 'src/ipc/paths.dart' show logDirectory;
import 'src/panes/event_sink.dart';
import 'src/panes/registry.dart';
import 'src/daemon/dispatcher.dart';
import 'src/pty/env.dart' show expandedPath;

const _timeout = Duration(seconds: 30);

class ClideTestApp extends StatefulWidget {
  const ClideTestApp({super.key});

  @override
  State<ClideTestApp> createState() => _ClideTestAppState();
}

class _ClideTestAppState extends State<ClideTestApp> {
  final List<_TestResult> _results = [];
  // Wired through the kernel logger so testmode output goes through
  // the same plumbing as production code. Sink stays default (stderr);
  // `make run-testmode` pipes 2>&1 so the harness still grep-checks
  // the structured `[testmode:json]` line.
  final _logger = Logger();
  bool _done = false;

  void _say(String message) => _logger.info('testmode', message);

  @override
  void initState() {
    super.initState();
    _attachCrashLogging();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runTests());
    Timer(_timeout, () {
      _say('timeout reached — exiting');
      exit(1);
    });
  }

  /// Opt-in crash evidence for testmode (T-436): when `CLIDE_LOG_DIR` is set
  /// (CI / a manual Windows repro), tee this harness's logger to a
  /// FileLogSink and spawn the watchdog, so a wedged testmode run leaves the
  /// same log + watchdog files the real app would. `_say` breadcrumbs each
  /// test through the logger, so they land in the file too. Off by default —
  /// normal `make run-testmode` keeps the stderr-only path, no isolate.
  void _attachCrashLogging() {
    final dir = Platform.environment['CLIDE_LOG_DIR'];
    if (dir == null || dir.isEmpty) return;
    final logDir = logDirectory();
    try {
      _logger.addSink(FileLogSink(dir: Directory(logDir)).call);
    } catch (_) {}
    unawaited(_spawnWatchdog(logDir));
  }

  Future<void> _spawnWatchdog(String logDir) async {
    try {
      await Isolate.spawn(watchdogEntry, ('$logDir/clide-watchdog.log', 500, 2000));
    } catch (_) {}
  }

  Future<void> _runTests() async {
    const workspace = String.fromEnvironment('CLIDE_PROJECT');
    const category = String.fromEnvironment('CLIDE_TESTMODE');
    final workDir = workspace.isNotEmpty ? workspace : Directory.current.path;

    final runAll = category.isEmpty || category == 'true' || category == 'all';
    final runToolchain = runAll || category == 'toolchain';
    final runIpc = runAll || category == 'ipc';
    final runExtensions = runAll || category == 'extensions';
    final runTerminal = runAll || category == 'terminal';

    _say('=== ClideTestApp starting ===');
    _say('workspace=$workDir');
    _say('cwd=${Directory.current.path}');
    _say('category=${runAll ? "all" : category}');
    _say('expandedPath=$expandedPath');
    _say('');

    final tc = Toolchain();
    tc.applyResolved(Toolchain.resolvePaths());

    if (runToolchain) await _runToolchainTests(tc, workDir);
    if (runIpc) await _runIpcTests(workDir);
    if (runExtensions) await _runExtensionTests(workDir, tc);
    if (runTerminal) await _runTerminalTests(tc, workDir);

    final passed = _results.where((r) => r.ok).length;
    final failed = _results.where((r) => !r.ok).length;
    final failedNames = _results.where((r) => !r.ok).map((r) => r.name).toList();

    _say('=== done ($passed passed, $failed failed, ${_results.length} total) ===');
    // Emitted under a distinct source so the harness's grep
    // (`make run-testmode` checks for `"failed":0`) keeps working
    // without depending on the human-readable lines above.
    _logger.info('testmode:json', jsonEncode({'passed': passed, 'failed': failed, 'total': _results.length, 'failures': failedNames}));

    setState(() => _done = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    exit(failed > 0 ? 1 : 0);
  }

  // -- toolchain category ---------------------------------------------------

  Future<void> _runToolchainTests(Toolchain tc, String workDir) async {
    _say('--- toolchain ---');
    _log('toolchain.git', tc.git);
    _log('toolchain.pql', tc.pql);
    _log('toolchain.shell', tc.shell);
    _log('toolchain.missing', tc.missing.isEmpty ? 'none' : tc.missing.join(', '));
    _say('');

    await _testExists('git', tc.git);
    await _testExists('pql', tc.pql);
    await _testExists('shell', tc.shell);
    _say('');

    await _testExec('git --version', tc.git, ['--version'], workDir);
    await _testExec('pql --version', tc.pql, ['--version'], workDir);
    // PowerShell has no --version flag; ask for the version variable
    // through the same -c path the passthrough tests use.
    await _testExec('shell --version', tc.shell, Platform.isWindows ? ['-c', r'$PSVersionTable.PSVersion.ToString()'] : ['--version'], workDir);
    _say('');

    // Shell passthrough — use the resolved shell, not a hardcoded path
    // (-c works for POSIX shells and as PowerShell's -Command alias).
    // PowerShell needs the & call operator to run a quoted path; POSIX
    // shells take the bare path.
    String shellCall(String exe, String args) => Platform.isWindows ? "& '$exe' $args" : '$exe $args';
    await _testExec('shell -c git', tc.shell, ['-c', shellCall(tc.git, '--version')], workDir);
    await _testExec('shell -c pql', tc.shell, ['-c', shellCall(tc.pql, '--version')], workDir);
    await _testExec('shell -c git (bare)', tc.shell, ['-c', 'git --version'], workDir);
    _say('');

    // git with env (dugite needs GIT_EXEC_PATH)
    await _testExec('git --version (env)', tc.git, ['--version'], workDir, env: tc.gitEnv);
    await _testExec('git status (env)', tc.git, ['status', '--porcelain'], workDir, env: tc.gitEnv);
    await _testExec('git rev-parse (env)', tc.git, ['rev-parse', '--show-toplevel'], workDir, env: tc.gitEnv);
    _say('');

    _log('gitEnv', '${tc.gitEnv}');
    _say('');

    // Boot sequence simulation tests
    _say('--- boot sequence ---');

    await _testAsync('compute(resolveToolchainPaths)', () async {
      final paths = await compute((_) => resolveToolchainPaths(), null);
      return 'git=${paths.git} pql=${paths.pql}';
    });

    await _testAsync('Isolate.run(resolveToolchainPaths)', () async {
      final paths = await Isolate.run(resolveToolchainPaths);
      return 'git=${paths.git} pql=${paths.pql}';
    });

    await _testAsync('git rev-parse (project.open sim)', () async {
      final r = await Process.run(tc.git, ['rev-parse', '--show-toplevel'], workingDirectory: workDir, environment: tc.gitEnv);
      return 'exit=${r.exitCode} ${(r.stdout as String).trim()}';
    });

    await _testAsync('sequential git calls', () async {
      final r1 = await Process.run(tc.git, ['rev-parse', '--show-toplevel'], workingDirectory: workDir, environment: tc.gitEnv);
      final r2 = await Process.run(tc.git, ['rev-parse', '--abbrev-ref', 'HEAD'], workingDirectory: workDir, environment: tc.gitEnv);
      return 'root=${(r1.stdout as String).trim()} branch=${(r2.stdout as String).trim()}';
    });

    await _testAsync('compute + immediate Process.run', () async {
      final paths = await compute((_) => resolveToolchainPaths(), null);
      final tc2 = Toolchain();
      tc2.applyResolved(paths);
      final r = await Process.run(tc2.git, ['rev-parse', '--show-toplevel'], workingDirectory: workDir, environment: tc2.gitEnv);
      return 'exit=${r.exitCode} ${(r.stdout as String).trim()}';
    });

    _say('');
  }

  // -- ipc category ---------------------------------------------------------

  Future<void> _runIpcTests(String workDir) async {
    _say('--- ipc ---');
    final dispatcher = DaemonDispatcher();

    // ping round-trip
    final pingReq = IpcRequest(id: 'test-ping-1', cmd: 'ping');
    final pingResp = await dispatcher.dispatch(pingReq);
    _addResult('ipc ping', pingResp.ok && pingResp.data['pong'] == true, pingResp.ok ? 'pong=${pingResp.data['pong']}' : 'error: ${pingResp.error?.message}');

    // version round-trip
    final verReq = IpcRequest(id: 'test-ver-1', cmd: 'version');
    final verResp = await dispatcher.dispatch(verReq);
    final version = verResp.data['version'];
    _addResult('ipc version', verResp.ok && version is String && version.isNotEmpty, 'version=$version');

    // unknown command → notFound
    final badReq = IpcRequest(id: 'test-bad-1', cmd: 'no_such_command');
    final badResp = await dispatcher.dispatch(badReq);
    _addResult('ipc unknown cmd', !badResp.ok && badResp.error?.kind == 'not_found', badResp.ok ? 'unexpected ok' : 'kind=${badResp.error?.kind}');

    // envelope encode/decode round-trip
    final encoded = pingReq.encode();
    final decoded = IpcMessage.decode(encoded);
    final isReq = decoded is IpcRequest && decoded.cmd == 'ping' && decoded.id == 'test-ping-1';
    _addResult('ipc encode/decode', isReq, isReq ? 'round-trip ok' : 'mismatch');

    _say('');
  }

  // -- extensions category --------------------------------------------------

  Future<void> _runExtensionTests(String workDir, Toolchain tc) async {
    _say('--- extensions ---');

    // Theme loading
    try {
      const loader = ThemeLoader();
      for (final p in kBundledThemePaths) {
        final name = p.split('/').last.replaceAll('.yaml', '');
        try {
          final theme = await loader.fromAsset(rootBundle, p);
          _addResult('theme:$name', true, 'loaded (${theme.name})');
        } catch (e) {
          _addResult('theme:$name', false, '$e');
        }
      }
    } catch (e) {
      _addResult('theme:init', false, '$e');
    }

    // Extension lifecycle — register + activate core built-ins
    try {
      final appDir = Directory('/tmp/clide-testmode-${DateTime.now().millisecondsSinceEpoch}');
      await appDir.create(recursive: true);
      final themes = <ThemeDefinition>[];
      try {
        const loader = ThemeLoader();
        themes.add(await loader.fromAsset(rootBundle, kBundledThemePaths.first));
      } catch (_) {}

      final services = await KernelServices.boot(
        appDir: appDir,
        bundledThemes: themes,
        i18nLoader: AssetCatalogLoader(bundle: rootBundle),
        preloadNamespaces: const [],
        autoStartDaemonClient: false,
        toolchain: tc,
      );

      final extensions = <ClideExtension>[DiffExtension(), FilesExtension(), GitExtension(), TerminalExtension()];

      for (final ext in extensions) {
        try {
          services.extensions.register(ext);
          _addResult('ext:register:${ext.id}', true, 'ok');
        } catch (e) {
          _addResult('ext:register:${ext.id}', false, '$e');
        }
      }

      try {
        await services.extensions.activateAll();
        for (final ext in extensions) {
          final active = services.extensions.isActivated(ext.id);
          _addResult('ext:activate:${ext.id}', active, active ? 'active' : 'not active');
        }
      } catch (e) {
        _addResult('ext:activateAll', false, '$e');
      }

      // Cleanup
      try {
        await appDir.delete(recursive: true);
      } catch (_) {}
    } catch (e) {
      _addResult('ext:boot', false, '$e');
    }

    _say('');
  }

  // -- terminal category ----------------------------------------------------

  Future<void> _runTerminalTests(Toolchain tc, String workDir) async {
    _say('--- terminal ---');

    // Test PTY via the dispatcher directly — skip the socket
    // round-trip for the smoke test since it adds setup without
    // testing anything new for pane.spawn. The real app's path is
    // covered by the IPC server + client tests under test/ipc/.
    await _testAsync('pane.spawn via IPC', () async {
      final dispatcher = DaemonDispatcher();
      final bus = DaemonBus();
      final eventSink = _TestEventSink(bus);
      final paneRegistry = PaneRegistry(events: eventSink);
      registerPaneCommands(dispatcher, paneRegistry);

      Future<IpcResponse> dispatch(String cmd, Map<String, Object?> args) {
        return dispatcher.dispatch(IpcRequest(id: 'tm-${DateTime.now().microsecondsSinceEpoch}', cmd: cmd, args: args));
      }

      // Spawn a pane running /bin/echo.
      // Use interactive shell — fast-exiting commands lose output on macOS
      // because the slave closes before we can read the master.
      final spawnResp = await dispatch('pane.spawn', {
        'argv': [tc.shell],
        'kind': 'terminal',
      });
      _say('  spawn: ok=${spawnResp.ok} ${spawnResp.ok ? spawnResp.data : spawnResp.error?.message}');
      if (!spawnResp.ok) {
        return 'spawn failed: ${spawnResp.error?.message}';
      }
      final paneId = spawnResp.data['id'] as String;

      // Collect pane.output events.
      final outputParts = <String>[];
      int eventCount = 0;
      final sub = bus.on<DaemonEvent>().listen((e) {
        eventCount++;
        if (e.subsystem == 'pane' && e.kind == 'pane.output' && e.data['id'] == paneId) {
          final b64 = e.data['bytes_b64'] as String?;
          if (b64 != null) outputParts.add(utf8.decode(base64Decode(b64), allowMalformed: true));
        }
      });
      await Future.delayed(const Duration(seconds: 3));
      _say('  events=$eventCount output_parts=${outputParts.length} bytes=${outputParts.join().length}');
      if (outputParts.isNotEmpty) {
        _say('  first output: ${outputParts.first.substring(0, outputParts.first.length.clamp(0, 80))}');
      }
      await sub.cancel();
      paneRegistry.shutdown();

      final output = outputParts.join();
      return output.isNotEmpty ? 'got ${output.length} chars' : 'no output (0 chars)';
    });

    // Test: does Dart's Process.start inherit socket fds on macOS? (T-438: the
    // FFI body lives in fd_check_io.dart so the web build can stub it out.)
    await _testAsync('fd inheritance check', fdInheritanceCheck);

    _say('');
  }

  // -- helpers --------------------------------------------------------------

  void _log(String key, String value) {
    _say('$key = $value');
  }

  void _addResult(String name, bool ok, String output) {
    final r = _TestResult(name: name, detail: '', ok: ok, output: output);
    _say('${ok ? "PASS" : "FAIL"} | $name | $output');
    setState(() => _results.add(r));
  }

  Future<void> _testExists(String name, String path) async {
    final exists = File(path).existsSync();
    final r = _TestResult(name: '$name exists', detail: path, ok: exists, output: exists ? 'yes' : 'NO');
    _say('exists | $name | path=$path | ${exists ? "yes" : "NO"}');
    setState(() => _results.add(r));
  }

  Future<void> _testAsync(String label, Future<String> Function() fn) async {
    try {
      final result = await fn().timeout(const Duration(seconds: 10));
      _addResult(label, true, result);
    } on TimeoutException {
      _addResult(label, false, 'TIMEOUT (10s)');
    } catch (e) {
      _addResult(label, false, '$e');
    }
  }

  Future<void> _testExec(String label, String bin, List<String> args, String workDir, {Map<String, String>? env}) async {
    try {
      final r = await Process.run(bin, args, workingDirectory: workDir, environment: env).timeout(const Duration(seconds: 5));
      final stdout = (r.stdout as String).trim();
      final stderr = (r.stderr as String).trim();
      final firstLine = stdout.isNotEmpty ? stdout.split('\n').first : (stderr.isNotEmpty ? stderr.split('\n').first : '(empty)');
      final ok = r.exitCode == 0 || r.exitCode == 1;
      final result = _TestResult(name: label, detail: '$bin ${args.join(" ")}', ok: ok, output: 'exit=${r.exitCode} $firstLine');
      _say('exec  | $label | exit=${r.exitCode} | ${ok ? "OK" : "FAIL"} | $firstLine');
      setState(() => _results.add(result));
    } on ProcessException catch (e) {
      final result = _TestResult(name: label, detail: '$bin ${args.join(" ")}', ok: false, output: 'ProcessException: ${e.message}');
      _say('exec  | $label | EXCEPTION | ${e.message}');
      setState(() => _results.add(result));
    } on TimeoutException {
      final result = _TestResult(name: label, detail: '$bin ${args.join(" ")}', ok: false, output: 'TIMEOUT (5s)');
      _say('exec  | $label | TIMEOUT');
      setState(() => _results.add(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFF1E1E2E),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ClideTestApp',
              style: TextStyle(color: Color(0xFFCDD6F4), fontSize: 20, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
            ),
            const SizedBox(height: 4),
            Text(
              _done ? 'Done — exiting' : 'Running tests...',
              style: const TextStyle(color: Color(0xFF6C7086), fontSize: 13, decoration: TextDecoration.none),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (ctx, i) {
                  final r = _results[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text(
                          r.ok ? '●' : '●',
                          style: TextStyle(color: r.ok ? const Color(0xFFA6E3A1) : const Color(0xFFF38BA8), fontSize: 12, decoration: TextDecoration.none),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 220,
                          child: Text(
                            r.name,
                            style: const TextStyle(color: Color(0xFFCDD6F4), fontSize: 12, fontFamily: 'monospace', decoration: TextDecoration.none),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            r.output,
                            style: const TextStyle(color: Color(0xFF9399B2), fontSize: 12, fontFamily: 'monospace', decoration: TextDecoration.none),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TestEventSink implements DaemonEventSink {
  _TestEventSink(this._bus);
  final DaemonBus _bus;

  @override
  void emit(IpcEvent event) {
    _bus.emit(DaemonEvent(subsystem: event.subsystem, kind: event.kind, data: event.data, ts: DateTime.now()));
  }
}

class _TestResult {
  const _TestResult({required this.name, required this.detail, required this.ok, required this.output});
  final String name;
  final String detail;
  final bool ok;
  final String output;
}
