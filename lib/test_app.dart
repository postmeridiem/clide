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
import 'kernel/src/backend.dart';
import 'kernel/src/events/bus.dart';
import 'kernel/src/events/types.dart';
import 'kernel/src/ipc/isolate_client.dart';
import 'kernel/src/log.dart';
import 'src/pty/session.dart';
import 'kernel/src/toolchain.dart';
import 'src/daemon/dispatcher.dart';
import 'src/ipc/envelope.dart';
import 'src/pty/env.dart' show expandedPath;

const _timeout = Duration(seconds: 30);

class ClideTestApp extends StatefulWidget {
  const ClideTestApp({super.key});

  @override
  State<ClideTestApp> createState() => _ClideTestAppState();
}

class _ClideTestAppState extends State<ClideTestApp> {
  final List<_TestResult> _results = [];
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runTests());
    Timer(_timeout, () {
      print('[testmode] timeout reached — exiting');
      exit(1);
    });
  }

  Future<void> _runTests() async {
    const workspace = String.fromEnvironment('CLIDE_WORKSPACE');
    const category = String.fromEnvironment('CLIDE_TESTMODE');
    final workDir = workspace.isNotEmpty ? workspace : Directory.current.path;

    final runAll = category.isEmpty || category == 'true' || category == 'all';
    final runToolchain = runAll || category == 'toolchain';
    final runIpc = runAll || category == 'ipc';
    final runExtensions = runAll || category == 'extensions';
    final runTerminal = runAll || category == 'terminal';

    print('[testmode] === ClideTestApp starting ===');
    print('[testmode] workspace=$workDir');
    print('[testmode] cwd=${Directory.current.path}');
    print('[testmode] category=${runAll ? "all" : category}');
    print('[testmode] expandedPath=$expandedPath');
    print('[testmode]');

    final tc = Toolchain();
    tc.applyResolved(Toolchain.resolvePaths(workspaceRoot: workDir));

    if (runToolchain) await _runToolchainTests(tc, workDir);
    if (runIpc) await _runIpcTests(workDir);
    if (runExtensions) await _runExtensionTests(workDir, tc);
    if (runTerminal) await _runTerminalTests(tc, workDir);

    final passed = _results.where((r) => r.ok).length;
    final failed = _results.where((r) => !r.ok).length;
    final failedNames = _results.where((r) => !r.ok).map((r) => r.name).toList();

    print('[testmode] === done ($passed passed, $failed failed, ${_results.length} total) ===');
    print('[testmode:json] ${jsonEncode({
      'passed': passed,
      'failed': failed,
      'total': _results.length,
      'failures': failedNames,
    })}');

    setState(() => _done = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    exit(failed > 0 ? 1 : 0);
  }

  // -- toolchain category ---------------------------------------------------

  Future<void> _runToolchainTests(Toolchain tc, String workDir) async {
    print('[testmode] --- toolchain ---');
    _log('toolchain.git', tc.git);
    _log('toolchain.pql', tc.pql);
    _log('toolchain.tmux', tc.tmux);
    _log('toolchain.ptyc', tc.ptyc);
    _log('toolchain.shell', tc.shell);
    _log('toolchain.missing', tc.missing.isEmpty ? 'none' : tc.missing.join(', '));
    print('[testmode]');

    await _testExists('git', tc.git);
    await _testExists('pql', tc.pql);
    await _testExists('tmux', tc.tmux);
    await _testExists('ptyc', tc.ptyc);
    await _testExists('shell', tc.shell);
    print('[testmode]');

    await _testExec('git --version', tc.git, ['--version'], workDir);
    await _testExec('pql --version', tc.pql, ['--version'], workDir);
    await _testExec('tmux -V', tc.tmux, ['-V'], workDir);
    await _testExec('ptyc (no args)', tc.ptyc, [], workDir);
    await _testExec('shell --version', tc.shell, ['--version'], workDir);
    print('[testmode]');

    // Shell passthrough — use the resolved shell, not a hardcoded path
    await _testExec('shell -c git', tc.shell, ['-c', '${tc.git} --version'], workDir);
    await _testExec('shell -c pql', tc.shell, ['-c', '${tc.pql} --version'], workDir);
    await _testExec('shell -c tmux', tc.shell, ['-c', '${tc.tmux} -V'], workDir);
    await _testExec('shell -c git (bare)', tc.shell, ['-c', 'git --version'], workDir);
    print('[testmode]');

    // git with env (dugite needs GIT_EXEC_PATH)
    await _testExec('git --version (env)', tc.git, ['--version'], workDir, env: tc.gitEnv);
    await _testExec('git status (env)', tc.git, ['status', '--porcelain'], workDir, env: tc.gitEnv);
    await _testExec('git rev-parse (env)', tc.git, ['rev-parse', '--show-toplevel'], workDir, env: tc.gitEnv);
    print('[testmode]');

    _log('gitEnv', '${tc.gitEnv}');
    print('[testmode]');

    // Boot sequence simulation tests
    print('[testmode] --- boot sequence ---');

    await _testAsync('compute(resolveToolchainPaths)', () async {
      final paths = await compute(resolveToolchainPaths, workDir);
      return 'git=${paths.git} pql=${paths.pql}';
    });

    await _testAsync('Isolate.run(resolveToolchainPaths)', () async {
      final paths = await Isolate.run(() => resolveToolchainPaths(workDir));
      return 'git=${paths.git} pql=${paths.pql}';
    });

    await _testAsync('git rev-parse (project.open sim)', () async {
      final r = await Process.run(tc.git, ['rev-parse', '--show-toplevel'],
          workingDirectory: workDir, environment: tc.gitEnv);
      return 'exit=${r.exitCode} ${(r.stdout as String).trim()}';
    });

    await _testAsync('sequential git calls', () async {
      final r1 = await Process.run(tc.git, ['rev-parse', '--show-toplevel'],
          workingDirectory: workDir, environment: tc.gitEnv);
      final r2 = await Process.run(tc.git, ['rev-parse', '--abbrev-ref', 'HEAD'],
          workingDirectory: workDir, environment: tc.gitEnv);
      return 'root=${(r1.stdout as String).trim()} branch=${(r2.stdout as String).trim()}';
    });

    await _testAsync('compute + immediate Process.run', () async {
      final paths = await compute(resolveToolchainPaths, workDir);
      final tc2 = Toolchain();
      tc2.applyResolved(paths);
      final r = await Process.run(tc2.git, ['rev-parse', '--show-toplevel'],
          workingDirectory: workDir, environment: tc2.gitEnv);
      return 'exit=${r.exitCode} ${(r.stdout as String).trim()}';
    });

    // ptyc stdin/stdout test — send a valid request, verify JSON response
    await _testAsync('ptyc spawn echo', () async {
      final proc = await Process.start(tc.ptyc, []);
      // Send a request for /bin/echo — simplest possible child
      proc.stdin.write('{"argv":["/bin/echo","hello"],"cwd":"/tmp","env":{},"cols":80,"rows":24}');
      await proc.stdin.close();
      final stdout = await proc.stdout.transform(const SystemEncoding().decoder).join();
      final exitCode = await proc.exitCode;
      return 'exit=$exitCode stdout=${stdout.trim().split('\n').first}';
    });

    print('[testmode]');
  }

  // -- ipc category ---------------------------------------------------------

  Future<void> _runIpcTests(String workDir) async {
    print('[testmode] --- ipc ---');
    final dispatcher = DaemonDispatcher();

    // ping round-trip
    final pingReq = IpcRequest(id: 'test-ping-1', cmd: 'ping');
    final pingResp = await dispatcher.dispatch(pingReq);
    _addResult(
      'ipc ping',
      pingResp.ok && pingResp.data['pong'] == true,
      pingResp.ok ? 'pong=${pingResp.data['pong']}' : 'error: ${pingResp.error?.message}',
    );

    // version round-trip
    final verReq = IpcRequest(id: 'test-ver-1', cmd: 'version');
    final verResp = await dispatcher.dispatch(verReq);
    final version = verResp.data['version'];
    _addResult(
      'ipc version',
      verResp.ok && version is String && version.isNotEmpty,
      'version=$version',
    );

    // unknown command → notFound
    final badReq = IpcRequest(id: 'test-bad-1', cmd: 'no_such_command');
    final badResp = await dispatcher.dispatch(badReq);
    _addResult(
      'ipc unknown cmd',
      !badResp.ok && badResp.error?.kind == 'not_found',
      badResp.ok ? 'unexpected ok' : 'kind=${badResp.error?.kind}',
    );

    // envelope encode/decode round-trip
    final encoded = pingReq.encode();
    final decoded = IpcMessage.decode(encoded);
    final isReq = decoded is IpcRequest && decoded.cmd == 'ping' && decoded.id == 'test-ping-1';
    _addResult('ipc encode/decode', isReq, isReq ? 'round-trip ok' : 'mismatch');

    print('[testmode]');
  }

  // -- extensions category --------------------------------------------------

  Future<void> _runExtensionTests(String workDir, Toolchain tc) async {
    print('[testmode] --- extensions ---');

    // Theme loading
    try {
      const loader = ThemeLoader();
      const paths = [
        'lib/kernel/src/theme/themes/clide.yaml',
        'lib/kernel/src/theme/themes/midnight.yaml',
        'lib/kernel/src/theme/themes/paper.yaml',
        'lib/kernel/src/theme/themes/terminal.yaml',
      ];
      for (final p in paths) {
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
        themes.add(await loader.fromAsset(rootBundle, 'lib/kernel/src/theme/themes/clide.yaml'));
      } catch (_) {}

      final services = await KernelServices.boot(
        appDir: appDir,
        bundledThemes: themes,
        i18nLoader: AssetCatalogLoader(bundle: rootBundle),
        preloadNamespaces: const [],
        autoStartDaemonClient: false,
        toolchain: tc,
      );

      final extensions = <ClideExtension>[
        DiffExtension(),
        FilesExtension(),
        GitExtension(),
        TerminalExtension(),
      ];

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
      try { await appDir.delete(recursive: true); } catch (_) {}
    } catch (e) {
      _addResult('ext:boot', false, '$e');
    }

    print('[testmode]');
  }

  // -- terminal category ----------------------------------------------------

  Future<void> _runTerminalTests(Toolchain tc, String workDir) async {
    print('[testmode] --- terminal ---');

    // On macOS, PtySession FFI blocks the merged thread. Test via
    // backend isolate IPC instead (same path the real app uses).
    await _testAsync('pane.spawn via backend', () async {
      print('[testmode]   spawning backend...');
      final backend = await Backend.spawn(
        hintRoot: workDir,
        clientFactory: (port) => IsolateClient(
          log: Logger(),
          events: DaemonBus(),
          backendPort: port,
        ),
      );
      print('[testmode]   backend ready, opening project...');
      await backend.openProject(workDir);
      print('[testmode]   project open, spawning pane...');

      // Spawn a pane running /bin/echo.
      // Use the shell (allowed by SBPL), not /bin/echo (not allowed).
      final spawnResp = await backend.client.request('pane.spawn', args: {
        'argv': [tc.shell, '-c', 'echo CLIDE_BACKEND_PTY_OK'],
        'kind': 'terminal',
      });
      print('[testmode]   spawn response: ok=${spawnResp.ok} ${spawnResp.ok ? spawnResp.data : spawnResp.error?.message}');
      if (!spawnResp.ok) {
        backend.dispose();
        return 'spawn failed: ${spawnResp.error?.message}';
      }
      final paneId = spawnResp.data['id'] as String;

      // Collect output events for up to 3 seconds.
      final outputParts = <String>[];
      final sub = backend.client.events.on<DaemonEvent>().listen((e) {
        if (e.subsystem == 'pane' && e.kind == 'pane.output' && e.data['id'] == paneId) {
          final b64 = e.data['bytes_b64'] as String?;
          if (b64 != null) outputParts.add(utf8.decode(base64Decode(b64), allowMalformed: true));
        }
      });
      await Future.delayed(const Duration(seconds: 3));
      await sub.cancel();
      backend.dispose();

      final output = outputParts.join();
      final ok = output.contains('CLIDE_BACKEND_PTY_OK');
      return ok ? 'output contains marker' : 'marker not found in ${output.length} chars: ${output.substring(0, output.length.clamp(0, 100))}';
    });

    if (!Platform.isMacOS) {
    // Direct PtySession tests (only on Linux where threads are separate).

    // Test 1: spawn /bin/echo via PtySession, read output
    await _testAsync('pty spawn echo', () async {
      final session = await PtySession.spawn(
        argv: ['/bin/echo', 'CLIDE_PTY_TEST_OK'],
        cwd: workDir,
        ptycPath: tc.ptyc,
      );
      final bytes = <int>[];
      final done = Completer<void>();
      session.output.listen(bytes.addAll, onDone: () => done.complete());
      await done.future.timeout(const Duration(seconds: 5));
      await session.close();
      final output = utf8.decode(bytes, allowMalformed: true);
      final ok = output.contains('CLIDE_PTY_TEST_OK');
      return ok ? 'output contains marker' : 'marker not found in ${output.length} bytes';
    });

    // Test 2: spawn shell, write a command, verify output
    await _testAsync('pty spawn shell', () async {
      final session = await PtySession.spawn(
        argv: [tc.shell, '-c', 'echo CLIDE_SHELL_TEST'],
        cwd: workDir,
        ptycPath: tc.ptyc,
      );
      final bytes = <int>[];
      final done = Completer<void>();
      session.output.listen(bytes.addAll, onDone: () => done.complete());
      await done.future.timeout(const Duration(seconds: 5));
      await session.close();
      final output = utf8.decode(bytes, allowMalformed: true);
      final ok = output.contains('CLIDE_SHELL_TEST');
      return ok ? 'shell output contains marker' : 'marker not found in ${output.length} bytes';
    });

    // Test 3: spawn interactive shell, write to stdin, verify file creation
    await _testAsync('pty write to child', () async {
      final marker = '/tmp/clide-pty-test-${DateTime.now().millisecondsSinceEpoch}';
      final session = await PtySession.spawn(
        argv: [tc.shell],
        cwd: workDir,
        ptycPath: tc.ptyc,
      );
      session.write(utf8.encode('touch $marker && exit\n'));
      final bytes = <int>[];
      final done = Completer<void>();
      session.output.listen(bytes.addAll, onDone: () => done.complete());
      await done.future.timeout(const Duration(seconds: 5));
      await session.close();
      final fileCreated = File(marker).existsSync();
      if (fileCreated) File(marker).deleteSync();
      return fileCreated ? 'file created + cleaned up' : 'file not created';
    });
    } // end !Platform.isMacOS

    print('[testmode]');
  }

  // -- helpers --------------------------------------------------------------

  void _log(String key, String value) {
    print('[testmode] $key = $value');
  }

  void _addResult(String name, bool ok, String output) {
    final r = _TestResult(name: name, detail: '', ok: ok, output: output);
    print('[testmode] ${ok ? "PASS" : "FAIL"} | $name | $output');
    setState(() => _results.add(r));
  }

  Future<void> _testExists(String name, String path) async {
    final exists = File(path).existsSync();
    final r = _TestResult(name: '$name exists', detail: path, ok: exists, output: exists ? 'yes' : 'NO');
    print('[testmode] exists | $name | path=$path | ${exists ? "yes" : "NO"}');
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
      final r = await Process.run(bin, args, workingDirectory: workDir, environment: env)
          .timeout(const Duration(seconds: 5));
      final stdout = (r.stdout as String).trim();
      final stderr = (r.stderr as String).trim();
      final firstLine = stdout.isNotEmpty ? stdout.split('\n').first : (stderr.isNotEmpty ? stderr.split('\n').first : '(empty)');
      final ok = r.exitCode == 0 || r.exitCode == 1;
      final result = _TestResult(name: label, detail: '$bin ${args.join(" ")}', ok: ok, output: 'exit=${r.exitCode} $firstLine');
      print('[testmode] exec  | $label | exit=${r.exitCode} | ${ok ? "OK" : "FAIL"} | $firstLine');
      setState(() => _results.add(result));
    } on ProcessException catch (e) {
      final result = _TestResult(name: label, detail: '$bin ${args.join(" ")}', ok: false, output: 'ProcessException: ${e.message}');
      print('[testmode] exec  | $label | EXCEPTION | ${e.message}');
      setState(() => _results.add(result));
    } on TimeoutException {
      final result = _TestResult(name: label, detail: '$bin ${args.join(" ")}', ok: false, output: 'TIMEOUT (5s)');
      print('[testmode] exec  | $label | TIMEOUT');
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
            const Text('ClideTestApp', style: TextStyle(color: Color(0xFFCDD6F4), fontSize: 20, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
            const SizedBox(height: 4),
            Text(_done ? 'Done — exiting' : 'Running tests...', style: const TextStyle(color: Color(0xFF6C7086), fontSize: 13, decoration: TextDecoration.none)),
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
                        Text(r.ok ? '●' : '●', style: TextStyle(color: r.ok ? const Color(0xFFA6E3A1) : const Color(0xFFF38BA8), fontSize: 12, decoration: TextDecoration.none)),
                        const SizedBox(width: 8),
                        SizedBox(width: 220, child: Text(r.name, style: const TextStyle(color: Color(0xFFCDD6F4), fontSize: 12, fontFamily: 'monospace', decoration: TextDecoration.none))),
                        Expanded(child: Text(r.output, style: const TextStyle(color: Color(0xFF9399B2), fontSize: 12, fontFamily: 'monospace', decoration: TextDecoration.none), overflow: TextOverflow.ellipsis)),
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

class _TestResult {
  const _TestResult({required this.name, required this.detail, required this.ok, required this.output});
  final String name;
  final String detail;
  final bool ok;
  final String output;
}
