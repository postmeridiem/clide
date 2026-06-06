import 'dart:io';

import 'package:clide/kernel/src/cli_install.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure-logic tests for the "Install clide command in PATH" affordance
/// (T-212). All I/O is synchronous against temp dirs — every external
/// dependency of [CliInstaller] is injected, so no real install is touched.
///
/// Linux-only assertions: the resolver mirrors `toolchain_paths.dart`, whose
/// macOS branch injects homebrew/local bins into PATH; gating to Linux keeps
/// the expanded-PATH behaviour deterministic. The CI host is Linux.
void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('clide_cli_install_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  /// A stand-in executable file at [path], created with the given [contents].
  File touchExec(String path, {String contents = '#!/bin/sh\n'}) {
    final f = File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(contents);
    if (!Platform.isWindows) Process.runSync('chmod', ['755', path]);
    return f;
  }

  CliInstaller installer({
    required String resolvedExecutable,
    required Map<String, String> env,
    List<String>? candidates,
    String? installDir,
  }) =>
      CliInstaller(
        resolvedExecutable: resolvedExecutable,
        env: env,
        bundledClientCandidates: candidates,
        installDir: installDir,
      );

  group('findBundledClient', () {
    test('returns the first candidate that exists', () {
      final present = '${tmp.path}/clide-cli';
      touchExec(present);
      final i = installer(
        resolvedExecutable: '${tmp.path}/clide',
        env: {'PATH': ''},
        candidates: ['${tmp.path}/missing', present],
      );
      expect(i.findBundledClient(), present);
    });

    test('returns null when no candidate exists', () {
      final i = installer(
        resolvedExecutable: '${tmp.path}/clide',
        env: {'PATH': ''},
        candidates: ['${tmp.path}/nope'],
      );
      expect(i.findBundledClient(), isNull);
    });
  });

  group('inspect', () {
    test('missing when no clide on PATH', () {
      final binDir = Directory('${tmp.path}/bin')..createSync();
      final i = installer(
        resolvedExecutable: '${tmp.path}/gui/clide',
        env: {'PATH': binDir.path},
      );
      expect(i.inspect().state, CliInstallState.missing);
    });

    test('installed when clide is a plain non-GUI binary', () {
      final binDir = Directory('${tmp.path}/bin')..createSync();
      touchExec('${binDir.path}/clide');
      final i = installer(
        resolvedExecutable: '${tmp.path}/gui/clide',
        env: {'PATH': binDir.path},
      );
      final s = i.inspect();
      expect(s.state, CliInstallState.installed);
      expect(s.pathEntry, '${binDir.path}/clide');
    });

    test('staleGui when clide symlinks to the running GUI executable', () {
      final gui = touchExec('${tmp.path}/gui/clide').path;
      final binDir = Directory('${tmp.path}/bin')..createSync();
      Link('${binDir.path}/clide').createSync(gui);
      final i = installer(
        resolvedExecutable: gui,
        env: {'PATH': binDir.path},
      );
      final s = i.inspect();
      expect(s.state, CliInstallState.staleGui);
      expect(s.needsInstall, isTrue);
    });

    test('staleGui when clide sits beside a flutter_assets payload', () {
      // A GUI bundle: runner next to data/flutter_assets/.
      final bundle = Directory('${tmp.path}/bundle')..createSync();
      Directory('${bundle.path}/data/flutter_assets').createSync(recursive: true);
      touchExec('${bundle.path}/clide');
      final binDir = Directory('${tmp.path}/bin')..createSync();
      Link('${binDir.path}/clide').createSync('${bundle.path}/clide');
      final i = installer(
        resolvedExecutable: '${tmp.path}/other/clide', // unrelated GUI path
        env: {'PATH': binDir.path},
      );
      expect(i.inspect().state, CliInstallState.staleGui);
    });
  });

  group('defaults', () {
    test('install dir and bundled candidates derive from env + exe dir', () {
      final i = CliInstaller(
        resolvedExecutable: '/opt/clide/bundle/clide',
        env: const {'HOME': '/home/dev', 'CLIDE_CLI_BIN': '/dev/tree/clide'},
      );
      expect(i.installDir, '/home/dev/.local/bin');
      // CLIDE_CLI_BIN override first, then the in-bundle path.
      expect(i.bundledClientCandidates, ['/dev/tree/clide', '/opt/clide/bundle/clide-cli']);
    });

    test('omits the CLIDE_CLI_BIN candidate when unset', () {
      final i = CliInstaller(
        resolvedExecutable: '/opt/clide/bundle/clide',
        env: const {'HOME': '/home/dev'},
      );
      expect(i.bundledClientCandidates, ['/opt/clide/bundle/clide-cli']);
    });

    test('falls back to the process environment when no env is passed', () {
      // No env → uses Platform.environment; the in-bundle candidate still
      // derives from the exe dir and the install dir from $HOME.
      final i = CliInstaller(resolvedExecutable: '/opt/clide/bundle/clide');
      expect(i.bundledClientCandidates, contains('/opt/clide/bundle/clide-cli'));
      expect(i.installDir, endsWith('/.local/bin'));
    });
  });

  group('expandedPath', () {
    test('non-macOS returns PATH unchanged', () {
      expect(expandedPath('/a:/b', macOS: false, home: '/home/x'), '/a:/b');
    });

    test('macOS prepends missing user + homebrew bins', () {
      final out = expandedPath('/usr/bin', macOS: true, home: '/home/x').split(':');
      expect(out, contains('/home/x/.local/bin'));
      expect(out, contains('/opt/homebrew/bin'));
      expect(out.last, '/usr/bin');
    });

    test('macOS does not duplicate entries already on PATH', () {
      final out = expandedPath('/opt/homebrew/bin:/usr/bin', macOS: true, home: '');
      expect('/opt/homebrew/bin'.allMatches(out).length, 1);
    });
  });

  group('install', () {
    test('fails clearly when no bundled client is present', () {
      final i = installer(
        resolvedExecutable: '${tmp.path}/gui/clide',
        env: {'PATH': ''},
        candidates: ['${tmp.path}/none'],
        installDir: '${tmp.path}/bin',
      );
      final r = i.install();
      expect(r.ok, isFalse);
      expect(r.message, contains('No bundled clide client'));
    });

    test('copies the client, marks it executable, reports onPath', () {
      final src = touchExec('${tmp.path}/bundle/clide-cli', contents: '#!/bin/sh\necho hi\n');
      final binDir = '${tmp.path}/bin';
      final i = installer(
        resolvedExecutable: '${tmp.path}/gui/clide',
        env: {'PATH': binDir},
        candidates: [src.path],
        installDir: binDir,
      );
      final r = i.install();
      expect(r.ok, isTrue);
      expect(r.onPath, isTrue);
      expect(r.installedPath, '$binDir/clide');
      final dest = File('$binDir/clide');
      expect(dest.existsSync(), isTrue);
      expect(dest.readAsStringSync(), src.readAsStringSync());
      if (!Platform.isWindows) {
        final mode = dest.statSync().mode;
        expect(mode & 0x49, 0x49, reason: 'owner/group/other +x bits set');
      }
    });

    test('overwrites a stale symlink rather than following it', () {
      final src = touchExec('${tmp.path}/bundle/clide-cli', contents: 'NEW');
      final gui = touchExec('${tmp.path}/gui/clide', contents: 'GUI').path;
      final binDir = '${tmp.path}/bin';
      Directory(binDir).createSync();
      Link('$binDir/clide').createSync(gui); // stale symlink into the GUI
      final i = installer(
        resolvedExecutable: gui,
        env: {'PATH': binDir},
        candidates: [src.path],
        installDir: binDir,
      );
      expect(i.install().ok, isTrue);
      // The GUI binary must be untouched; the bin entry is now a real file.
      expect(File(gui).readAsStringSync(), 'GUI');
      expect(FileSystemEntity.isLinkSync('$binDir/clide'), isFalse);
      expect(File('$binDir/clide').readAsStringSync(), 'NEW');
    });

    test('reports a FileSystemException as a failed result', () {
      final src = touchExec('${tmp.path}/bundle/clide-cli');
      // installDir path is occupied by a regular file → createSync throws.
      final blocker = '${tmp.path}/blocked';
      File(blocker).writeAsStringSync('not a dir');
      final i = installer(
        resolvedExecutable: '${tmp.path}/gui/clide',
        env: {'PATH': ''},
        candidates: [src.path],
        installDir: blocker,
      );
      final r = i.install();
      expect(r.ok, isFalse);
      expect(r.message, contains('Install failed'));
    });

    test('reports onPath:false when the install dir is not on PATH', () {
      final src = touchExec('${tmp.path}/bundle/clide-cli');
      final installDir = '${tmp.path}/elsewhere';
      final i = installer(
        resolvedExecutable: '${tmp.path}/gui/clide',
        env: {'PATH': '${tmp.path}/somewhere-else'},
        candidates: [src.path],
        installDir: installDir,
      );
      final r = i.install();
      expect(r.ok, isTrue);
      expect(r.onPath, isFalse);
      expect(r.message, contains('add $installDir to your PATH'));
    });
  });
}
