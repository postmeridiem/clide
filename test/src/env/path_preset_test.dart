/// Tests for the per-workspace PATH preset (D-106, T-511): the pure prepend /
/// capture-diff helpers, the worktree-aware preset root, and the settings-key
/// derivation. Runs under plain `dart test` (Flutter-free).
library;

import 'dart:io';

import 'package:clide/src/env/path_preset.dart';
import 'package:test/test.dart';

void main() {
  group('applyPathPreset', () {
    test('prepends preset dirs ahead of the base', () {
      expect(applyPathPreset('/usr/bin:/bin', ['/opt/go/bin', '/x']), '/opt/go/bin:/x:/usr/bin:/bin');
    });

    test('empty preset returns the base unchanged', () {
      expect(applyPathPreset('/usr/bin', const []), '/usr/bin');
      expect(applyPathPreset('/usr/bin', ['', '   ']), '/usr/bin');
    });

    test('empty base returns just the preset', () {
      expect(applyPathPreset('', ['/a', '/b']), '/a:/b');
    });

    test('de-duplicates within the preset, order kept', () {
      expect(applyPathPreset('/bin', ['/a', '/b', '/a']), '/a:/b:/bin');
    });

    test('drops base entries the preset already names (preset wins)', () {
      expect(applyPathPreset('/usr/bin:/a:/bin', ['/a']), '/a:/usr/bin:/bin');
    });

    test('honours a custom separator', () {
      expect(applyPathPreset(r'C:\bin', [r'C:\go'], sep: ';'), r'C:\go;C:\bin');
    });

    test('skips a malformed entry containing the separator (would smuggle a CWD token)', () {
      expect(applyPathPreset('/usr/bin', ['/a:', '/ok']), '/ok:/usr/bin');
      expect(applyPathPreset('/usr/bin', ['/a::/b']), '/usr/bin');
    });
  });

  group('missingLoginShellDirs', () {
    test('null or empty login PATH → nothing to suggest', () {
      expect(missingLoginShellDirs(loginPath: null, processPath: '/bin'), isEmpty);
      expect(missingLoginShellDirs(loginPath: '', processPath: '/bin'), isEmpty);
    });

    test('suggests login entries the process PATH lacks, order kept', () {
      expect(missingLoginShellDirs(loginPath: '/home/linuxbrew/.linuxbrew/bin:/usr/bin:/opt/go/bin:/bin', processPath: '/usr/bin:/bin'), [
        '/home/linuxbrew/.linuxbrew/bin',
        '/opt/go/bin',
      ]);
    });

    test('de-duplicates and skips empty segments', () {
      expect(missingLoginShellDirs(loginPath: '/a::/a:/b', processPath: '/bin'), ['/a', '/b']);
    });
  });

  group('presetRootFor (worktree resolution)', () {
    test('a normal repo (.git directory) keys off itself', () {
      expect(presetRootFor('/repo', isFile: (_) => false, readFile: (_) => fail('not read')), '/repo');
    });

    test('trailing separators are stripped', () {
      expect(presetRootFor('/repo//', isFile: (_) => false, readFile: (_) => null), '/repo');
    });

    test('an in-repo .worktrees worktree resolves to the main repo root (absolute gitdir)', () {
      expect(
        presetRootFor(
          '/repo/.worktrees/fix',
          isFile: (p) => p == '/repo/.worktrees/fix/.git',
          readFile: (p) => 'gitdir: /repo/.git/worktrees/fix\n',
          isDir: (p) => p == '/repo/.git',
        ),
        '/repo',
      );
    });

    test('a relative gitdir pointer resolves against the worktree root', () {
      expect(
        presetRootFor(
          '/repo/.worktrees/fix',
          isFile: (p) => p == '/repo/.worktrees/fix/.git',
          readFile: (p) => 'gitdir: ../../.git/worktrees/fix',
          isDir: (p) => p == '/repo/.git',
        ),
        '/repo',
      );
    });

    test('a worktree outside the repo still resolves to the main root', () {
      expect(
        presetRootFor(
          '/tmp/wt',
          isFile: (p) => p == '/tmp/wt/.git',
          readFile: (_) => 'gitdir: /srv/repos/main/.git/worktrees/wt',
          isDir: (p) => p == '/srv/repos/main/.git',
        ),
        '/srv/repos/main',
      );
    });

    test('a pointer whose target is not a real repo is ignored (repo-controlled content)', () {
      expect(
        presetRootFor('/evil', isFile: (p) => p == '/evil/.git', readFile: (_) => 'gitdir: /home/u/victim/.git/worktrees/x', isDir: (_) => false),
        '/evil',
      );
    });

    test('a gitdir pointer without the worktrees marker (submodule-style) keys off itself', () {
      expect(presetRootFor('/repo/sub', isFile: (p) => p == '/repo/sub/.git', readFile: (_) => 'gitdir: /repo/.git/modules/sub'), '/repo/sub');
    });

    test('malformed or unreadable pointer files key off the workspace itself', () {
      expect(presetRootFor('/w', isFile: (_) => true, readFile: (_) => 'not a pointer'), '/w');
      expect(presetRootFor('/w', isFile: (_) => true, readFile: (_) => null), '/w');
    });

    test('backslashed gitdir (Windows-written pointer) still matches', () {
      expect(
        presetRootFor(
          '/repo/.worktrees/x',
          isFile: (p) => p == '/repo/.worktrees/x/.git',
          readFile: (_) => r'gitdir: /repo/.git\worktrees\x',
          isDir: (p) => p == '/repo/.git',
        ),
        '/repo',
      );
    });

    test('resolves a REAL worktree layout on disk (no injected probes)', () {
      final tmp = Directory.systemTemp.createTempSync('preset-root');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final repo = Directory('${tmp.path}/repo')..createSync();
      Directory('${repo.path}/.git/worktrees/fix').createSync(recursive: true);
      final wt = Directory('${repo.path}/.worktrees/fix')..createSync(recursive: true);
      File('${wt.path}/.git').writeAsStringSync('gitdir: ${repo.path}/.git/worktrees/fix\n');
      expect(presetRootFor(wt.path), repo.path);
      expect(presetRootFor(repo.path), repo.path);
    });
  });

  group('pathPresetKey', () {
    test('is an app-layer key under the preset prefix', () {
      final key = pathPresetKey('/repo', isFile: (_) => false, readFile: (_) => null);
      expect(key, startsWith(pathPresetKeyPrefix));
      expect(key.length, pathPresetKeyPrefix.length + 16, reason: '16-hex FNV-1a suffix');
    });

    test('a worktree and its main repo share one key; trailing slash is unified', () {
      final main = pathPresetKey('/repo', isFile: (_) => false, readFile: (_) => null);
      final slash = pathPresetKey('/repo/', isFile: (_) => false, readFile: (_) => null);
      final wt = pathPresetKey(
        '/repo/.worktrees/fix',
        isFile: (p) => p == '/repo/.worktrees/fix/.git',
        readFile: (_) => 'gitdir: /repo/.git/worktrees/fix',
        isDir: (p) => p == '/repo/.git',
      );
      expect(slash, main);
      expect(wt, main);
      expect(pathPresetKey('/other', isFile: (_) => false, readFile: (_) => null), isNot(main));
    });
  });

  group('presetLookupRoot', () {
    test('a cwd at or below the workspace keys off the workspace', () {
      expect(presetLookupRoot('/repo', '/repo'), '/repo');
      expect(presetLookupRoot('/repo/', '/repo'), '/repo');
      expect(presetLookupRoot('/repo/lib/src', '/repo'), '/repo');
      expect(presetLookupRoot(null, '/repo'), '/repo');
      expect(presetLookupRoot('', '/repo'), '/repo');
    });

    test('an unrelated cwd keys off itself; sibling-prefix dirs are not confused', () {
      expect(presetLookupRoot('/elsewhere', '/repo'), '/elsewhere');
      expect(presetLookupRoot('/repo-other/x', '/repo'), '/repo-other/x');
    });
  });

  group('presetDirsFrom', () {
    List<String> read(Object? stored) => presetDirsFrom((_) => stored, '/repo', isFile: (_) => false, readFile: (_) => null);

    test('reads a stored list of dirs', () {
      expect(read(['/a', '/b']), ['/a', '/b']);
    });

    test('tolerates malformed values', () {
      expect(read(null), isEmpty);
      expect(read('nonsense'), isEmpty);
      expect(read([1, '', '  ', '/ok', true]), ['/ok']);
    });
  });
}
