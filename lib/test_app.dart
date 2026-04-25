/// ClideTestApp — standalone test harness for platform integration.
///
/// Launched via `make run-testmode`. Runs a table of exec tests against
/// external binaries, prints results to stdout (captured by the make
/// target), then exits after 15 seconds. Add test cases here whenever
/// you need to isolate a platform issue without the full app.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'kernel/src/toolchain.dart';
import 'src/pty/env.dart' show expandedPath;

const _timeout = Duration(seconds: 15);

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
      exit(0);
    });
  }

  Future<void> _runTests() async {
    const workspace = String.fromEnvironment('CLIDE_WORKSPACE');
    final workDir = workspace.isNotEmpty ? workspace : Directory.current.path;

    print('[testmode] === ClideTestApp starting ===');
    print('[testmode] workspace=$workDir');
    print('[testmode] cwd=${Directory.current.path}');
    print('[testmode] expandedPath=$expandedPath');
    print('[testmode]');

    // Resolve toolchain
    final tc = Toolchain();
    tc.applyResolved(Toolchain.resolvePaths(workspaceRoot: workDir));
    _log('toolchain.git', tc.git);
    _log('toolchain.pql', tc.pql);
    _log('toolchain.tmux', tc.tmux);
    _log('toolchain.ptyc', tc.ptyc);
    _log('toolchain.shell', tc.shell);
    _log('toolchain.missing', tc.missing.isEmpty ? 'none' : tc.missing.join(', '));
    print('[testmode]');

    // Existence checks
    await _testExists('git', tc.git);
    await _testExists('pql', tc.pql);
    await _testExists('tmux', tc.tmux);
    await _testExists('ptyc', tc.ptyc);
    await _testExists('zsh', tc.shell);
    print('[testmode]');

    // Direct exec tests
    await _testExec('git --version', tc.git, ['--version'], workDir);
    await _testExec('pql --version', tc.pql, ['--version'], workDir);
    await _testExec('tmux -V', tc.tmux, ['-V'], workDir);
    await _testExec('ptyc (no args)', tc.ptyc, [], workDir);
    await _testExec('zsh --version', tc.shell, ['--version'], workDir);
    print('[testmode]');

    // zsh passthrough tests
    await _testExec('zsh -c git', '/bin/zsh', ['-c', '${tc.git} --version'], workDir);
    await _testExec('zsh -c pql', '/bin/zsh', ['-c', '${tc.pql} --version'], workDir);
    await _testExec('zsh -c tmux', '/bin/zsh', ['-c', '${tc.tmux} -V'], workDir);
    await _testExec('zsh -c git (bare)', '/bin/zsh', ['-c', 'git --version'], workDir);
    print('[testmode]');

    // git with env (dugite needs GIT_EXEC_PATH)
    await _testExec('git --version (with env)', tc.git, ['--version'], workDir, env: tc.gitEnv);
    await _testExec('git status (with env)', tc.git, ['status', '--porcelain'], workDir, env: tc.gitEnv);
    await _testExec('git rev-parse (with env)', tc.git, ['rev-parse', '--show-toplevel'], workDir, env: tc.gitEnv);
    print('[testmode]');

    print('[testmode] gitEnv = ${tc.gitEnv}');
    print('[testmode]');

    print('[testmode] === done (${_results.length} tests) ===');
    setState(() => _done = true);

    // Give the UI a moment to render, then exit.
    await Future<void>.delayed(const Duration(seconds: 3));
    exit(0);
  }

  void _log(String key, String value) {
    print('[testmode] $key = $value');
  }

  Future<void> _testExists(String name, String path) async {
    final exists = File(path).existsSync();
    final r = _TestResult(name: '$name exists', detail: path, ok: exists, output: exists ? 'yes' : 'NO');
    print('[testmode] exists | $name | path=$path | ${exists ? "yes" : "NO"}');
    setState(() => _results.add(r));
  }

  Future<void> _testExec(String label, String bin, List<String> args, String workDir, {Map<String, String>? env}) async {
    try {
      final r = await Process.run(bin, args, workingDirectory: workDir, environment: env)
          .timeout(const Duration(seconds: 5));
      final stdout = (r.stdout as String).trim();
      final stderr = (r.stderr as String).trim();
      final firstLine = stdout.isNotEmpty ? stdout.split('\n').first : (stderr.isNotEmpty ? stderr.split('\n').first : '(empty)');
      final ok = r.exitCode == 0 || r.exitCode == 1; // exit 1 is acceptable for some tools
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
            Text(_done ? 'Done — exiting in 3s' : 'Running tests...', style: const TextStyle(color: Color(0xFF6C7086), fontSize: 13, decoration: TextDecoration.none)),
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
                        SizedBox(width: 200, child: Text(r.name, style: const TextStyle(color: Color(0xFFCDD6F4), fontSize: 12, fontFamily: 'monospace', decoration: TextDecoration.none))),
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
