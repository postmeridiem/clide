/// T-621 / D-113: installing a release over an installed bundle, and moving
/// the windows onto it. The install runs the real `tar` and `sha256sum` over a
/// real tarball in a temp dir; only the download is faked. Flutter-free.
@TestOn('linux')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/src/ipc/envelope.dart';
import 'package:clide/src/update/self_update.dart';
import 'package:clide/src/update/update_check.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('clide-update-'));
  tearDown(() => tmp.deleteSync(recursive: true));

  /// A bundle dir holding a runnable `clide` (printing [version]) and a
  /// `clide-cli`, tarred up the way the release workflow does.
  Future<(File tarball, String sha)> release(String version, {bool runnable = true}) async {
    final src = Directory('${tmp.path}/src-$version')..createSync();
    final exe = File('${src.path}/clide')..writeAsStringSync('#!/bin/sh\necho $version\n');
    if (runnable) await Process.run('chmod', ['755', exe.path]);
    File('${src.path}/clide-cli').writeAsStringSync('cli $version');
    Directory('${src.path}/data').createSync();
    final tarball = File('${tmp.path}/clide-linux-x64-$version.tar.gz');
    final tar = await Process.run('tar', ['-C', src.path, '-czf', tarball.path, '.']);
    expect(tar.exitCode, 0, reason: '${tar.stderr}');
    final sum = await Process.run('sha256sum', [tarball.path]);
    return (tarball, '${sum.stdout}'.split(' ').first);
  }

  /// An installed bundle at `<tmp>/lib/clide` plus a CLI at `<tmp>/bin/clide`.
  (String installDir, String cli) installed() {
    final dir = Directory('${tmp.path}/lib/clide')..createSync(recursive: true);
    File('${dir.path}/clide').writeAsStringSync('old');
    Directory('${tmp.path}/bin').createSync();
    final cli = File('${tmp.path}/bin/clide')..writeAsStringSync('old cli');
    return (dir.path, cli.path);
  }

  BundleDownload copyFrom(File tarball) => (url, to, onChunk) async {
    await tarball.copy(to.path);
    final n = tarball.lengthSync();
    onChunk(n ~/ 2, n);
    onChunk(n, n);
  };

  ReleaseBundle bundleOf(File tarball, String sha) =>
      ReleaseBundle(name: tarball.uri.pathSegments.last, url: 'https://example.test/${tarball.uri.pathSegments.last}', sha256: sha, size: tarball.lengthSync());

  group('SelfUpdater.installDirOf', () {
    test('an installed bundle updates itself; a build tree or another OS does not', () {
      expect(SelfUpdater.installDirOf('/home/u/.local/lib/clide/clide', isLinux: true), '/home/u/.local/lib/clide');
      expect(SelfUpdater.installDirOf('/src/clide/build/linux/x64/release/bundle/clide', isLinux: true), isNull);
      expect(SelfUpdater.installDirOf('/home/u/.local/lib/clide/clide', isLinux: false), isNull);
    });
  });

  group('SelfUpdater.install', () {
    test('verifies, unpacks and swaps in the new bundle, keeping the old as .old', () async {
      final (tarball, sha) = await release('2.16.0');
      final (dir, cli) = installed();
      final phases = <UpdatePhase>[];
      await SelfUpdater(
        installDir: dir,
        cliPath: cli,
        download: copyFrom(tarball),
      ).install(bundleOf(tarball, sha), onProgress: (p, {fraction}) => phases.add(p));

      final run = await Process.run('$dir/clide', const []);
      expect('${run.stdout}'.trim(), '2.16.0', reason: 'the new binary is in place and runnable');
      expect(File('$dir.old/clide').readAsStringSync(), 'old');
      expect(File(cli).readAsStringSync(), 'cli 2.16.0', reason: 'the CLI client is replaced too');
      expect(Directory('$dir.new').existsSync(), isFalse);
      expect(tmp.listSync().whereType<File>().where((f) => f.path.contains('.clide-update-')), isEmpty, reason: 'the download is cleaned up');
      expect(phases.toSet().toList(), [UpdatePhase.downloading, UpdatePhase.verifying, UpdatePhase.unpacking, UpdatePhase.installing]);
    });

    test('a checksum mismatch aborts with the old install untouched', () async {
      final (tarball, _) = await release('2.16.0');
      final (dir, cli) = installed();
      final updater = SelfUpdater(installDir: dir, cliPath: cli, download: copyFrom(tarball));
      await expectLater(
        updater.install(bundleOf(tarball, 'deadbeef')),
        throwsA(isA<SelfUpdateException>().having((e) => e.message, 'message', contains('checksum mismatch'))),
      );
      expect(File('$dir/clide').readAsStringSync(), 'old');
      expect(File(cli).readAsStringSync(), 'old cli');
      expect(Directory('$dir.old').existsSync(), isFalse);
      expect(Directory('$dir.new').existsSync(), isFalse);
    });

    test('a bundle without a runnable clide is refused before the swap', () async {
      final (tarball, sha) = await release('2.16.0', runnable: false);
      final (dir, cli) = installed();
      await expectLater(
        SelfUpdater(installDir: dir, cliPath: cli, download: copyFrom(tarball)).install(bundleOf(tarball, sha)),
        throwsA(isA<SelfUpdateException>()),
      );
      expect(File('$dir/clide').readAsStringSync(), 'old');
      expect(Directory('$dir.new').existsSync(), isFalse);
    });

    test('a second update replaces the previous .old', () async {
      final (dir, cli) = installed();
      final (t1, s1) = await release('2.16.0');
      await SelfUpdater(installDir: dir, cliPath: cli, download: copyFrom(t1)).install(bundleOf(t1, s1));
      final (t2, s2) = await release('2.17.0');
      await SelfUpdater(installDir: dir, cliPath: cli, download: copyFrom(t2)).install(bundleOf(t2, s2));
      expect('${(await Process.run('$dir/clide', const [])).stdout}'.trim(), '2.17.0');
      expect('${(await Process.run('$dir.old/clide', const [])).stdout}'.trim(), '2.16.0');
    });

    test('no installed CLI client means nothing to replace', () async {
      final (tarball, sha) = await release('2.16.0');
      final (dir, _) = installed();
      await SelfUpdater(installDir: dir, download: copyFrom(tarball)).install(bundleOf(tarball, sha));
      expect(File('$dir/clide').existsSync(), isTrue);
    });
  });

  group('httpDownload', () {
    test('streams the body to the file with progress; a non-200 throws', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((req) {
        if (req.uri.path == '/missing') {
          req.response.statusCode = 404;
        } else {
          req.response.contentLength = 5;
          req.response.add(utf8.encode('hello'));
        }
        unawaited(req.response.close());
      });
      final to = File('${tmp.path}/out');
      final seen = <int>[];
      await httpDownload(Uri.parse('http://127.0.0.1:${server.port}/ok'), to, (got, total) => seen.add(got));
      expect(to.readAsStringSync(), 'hello');
      expect(seen.last, 5);
      await expectLater(httpDownload(Uri.parse('http://127.0.0.1:${server.port}/missing'), to, (_, _) {}), throwsA(isA<SelfUpdateException>()));
    });
  });

  group('WindowRelauncher', () {
    /// A stand-in window: answers `files.root` with [root], records the rest.
    Future<(String socket, List<String> cmds)> window(String name, String root) async {
      final path = '${tmp.path}/sockets/$name.sock';
      Directory('${tmp.path}/sockets').createSync(recursive: true);
      final server = await ServerSocket.bind(InternetAddress(path, type: InternetAddressType.unix), 0);
      addTearDown(server.close);
      final cmds = <String>[];
      server.listen((c) {
        c.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
          final req = IpcMessage.decode(line) as IpcRequest;
          cmds.add(req.cmd);
          final data = req.cmd == 'files.root' ? {'path': root} : const <String, Object?>{};
          c.write('${IpcResponse.ok(id: req.id, data: data).encode()}\n');
        });
      });
      return (path, cmds);
    }

    test('restarts every other window on the new binary, then quits the old one', () async {
      final (own, ownCmds) = await window('own', '/repo/own');
      final (_, aCmds) = await window('a', '/repo/a');
      final (_, bCmds) = await window('b', '/repo/b');
      File('${tmp.path}/sockets/dead.sock').writeAsStringSync(''); // stale node: skipped
      final started = <(String, List<String>, String, Map<String, String>)>[];
      final r = WindowRelauncher(
        executable: '/home/u/.local/lib/clide/clide',
        socketDir: '${tmp.path}/sockets',
        // CLIDE_RELAUNCH: this window was itself restarted by 2.17.0 — the
        // flag must not ride along to the windows it starts.
        environment: {'PATH': '/bin', 'CLIDE_SOCK': '/x.sock', 'CLIDE_WORKSPACE': '/x', kRelaunchEnv: '1'},
        start: (exe, args, cwd, env) async {
          started.add((exe, args, cwd, env));
          return Process.start('true', const []);
        },
      );

      expect(await r.relaunchSiblings(ownSocket: own), 2);
      expect(started.map((s) => s.$3).toSet(), {'/repo/a', '/repo/b'}, reason: 'each starts in its repo, so it reopens it');
      for (final (exe, args, _, env) in started) {
        expect(exe, '/home/u/.local/lib/clide/clide');
        expect(args, [kRelaunchArg]);
        expect(env, {'PATH': '/bin'}, reason: 'no inherited window identity or relaunch flag');
      }
      expect(aCmds, ['files.root', 'app.quit']);
      expect(bCmds, ['files.root', 'app.quit']);
      expect(ownCmds, isEmpty, reason: 'this window restarts itself last, not via its socket');
    });

    test('a relaunch is the argument, or the 2.17.0 environment variable', () {
      expect(isRelaunch(const [kRelaunchArg], const {}), isTrue);
      expect(isRelaunch(const [], const {kRelaunchEnv: '1'}), isTrue);
      expect(isRelaunch(const [], const {}), isFalse);
    });

    test('ipcOneShot returns null for a socket nobody answers', () async {
      expect(await ipcOneShot('${tmp.path}/nothing.sock', 'files.root', timeout: const Duration(milliseconds: 200)), isNull);
    });
  });
}
