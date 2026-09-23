/// Unit tests for the POSIX backend's PATH resolution (T-81 #29). No PTY is
/// opened — the libc bindings in native_pty.dart are lazily initialized
/// top-level finals and are never touched here — so this is NOT tagged `pty`.
@TestOn('!windows')
library;

import 'dart:io';

import 'package:clide/src/pty/native_pty.dart';
import 'package:test/test.dart';

void main() {
  group('NativePty.resolveExecutable', () {
    test('takes the first executable candidate on PATH', () {
      final probed = <String>[];
      final r = NativePty.resolveExecutable('tool', const {'PATH': '/a:/b:/c'}, isExecutable: (p) => (probed..add(p)).last == '/b/tool');
      expect(r, '/b/tool');
      expect(probed, ['/a/tool', '/b/tool'], reason: 'stops at the first hit');
    });

    test('skips empty PATH segments', () {
      final probed = <String>[];
      NativePty.resolveExecutable('tool', const {'PATH': ':/a::'}, isExecutable: (p) => (probed..add(p)).isEmpty);
      expect(probed, ['/a/tool']);
    });

    test('a name with a slash is used as given', () {
      expect(NativePty.resolveExecutable('./tool', const {'PATH': '/a'}, isExecutable: (_) => fail('must not probe')), './tool');
    });

    test('a name found nowhere comes back unchanged', () {
      expect(NativePty.resolveExecutable('tool', const {'PATH': '/a:/b'}, isExecutable: (_) => false), 'tool');
    });

    group('on disk', () {
      late Directory dir;
      setUp(() => dir = Directory.systemTemp.createTempSync('clide-path-'));
      tearDown(() => dir.deleteSync(recursive: true));

      test('a non-executable file earlier on PATH does not shadow the real binary', () {
        final shadow = Directory('${dir.path}/shadow')..createSync();
        final real = Directory('${dir.path}/real')..createSync();
        File('${shadow.path}/tool').writeAsStringSync('not a program');
        File('${real.path}/tool').writeAsStringSync('#!/bin/sh\n');
        Process.runSync('chmod', ['755', '${real.path}/tool']);

        final r = NativePty.resolveExecutable('tool', {'PATH': '${shadow.path}:${real.path}'});
        expect(r, '${real.path}/tool');
      });

      test('a directory with the command name is skipped too', () {
        final shadow = Directory('${dir.path}/shadow')..createSync();
        Directory('${shadow.path}/tool').createSync();
        final real = Directory('${dir.path}/real')..createSync();
        File('${real.path}/tool').writeAsStringSync('#!/bin/sh\n');
        Process.runSync('chmod', ['700', '${real.path}/tool']);

        expect(NativePty.resolveExecutable('tool', {'PATH': '${shadow.path}:${real.path}'}), '${real.path}/tool');
      });
    });
  });
}
