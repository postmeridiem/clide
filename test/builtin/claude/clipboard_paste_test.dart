/// Tests for clipboard paste resolution (T-138): files become `@path`
/// tokens, a raw image is written to a temp file and referenced by
/// `@path`, and an empty clipboard falls back to text (null). Also
/// covers the NativeClipboard channel client's decode + missing-handler
/// guard.
library;

import 'dart:io';

import 'package:clide/builtin/claude/src/clipboard_paste.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSource implements ClipboardSource {
  _FakeSource({this.files = const [], this.image});
  final List<String> files;
  final Uint8List? image;
  @override
  Future<List<String>> readFiles() async => files;
  @override
  Future<Uint8List?> readImage() async => image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolveClipboardAttachment', () {
    test('files become attachments with isImage by extension', () async {
      final source = _FakeSource(files: ['/home/u/a.txt', '/home/u/b.png']);
      final result = await resolveClipboardAttachment(source);
      expect(result.map((a) => a.path), ['/home/u/a.txt', '/home/u/b.png']);
      expect(result.map((a) => a.isImage), [false, true]);
      expect(result.map((a) => a.pathToken), ['@/home/u/a.txt', '@/home/u/b.png']);
    });

    test('a raw image is written to a temp file and attached', () async {
      final dir = await Directory.systemTemp.createTemp('clide-paste-test-');
      addTearDown(() => dir.delete(recursive: true));
      final bytes = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 1, 2, 3]);
      final fixedNow = DateTime.fromMillisecondsSinceEpoch(1700000000000);

      final result = await resolveClipboardAttachment(
        _FakeSource(image: bytes),
        tempDir: dir,
        now: () => fixedNow,
      );

      final expectedPath = '${dir.path}/paste-1700000000000.png';
      expect(result, hasLength(1));
      expect(result.single.isImage, isTrue);
      expect(result.single.path, expectedPath);
      expect(await File(expectedPath).readAsBytes(), bytes);
    });

    test('files take precedence over an image', () async {
      final result = await resolveClipboardAttachment(_FakeSource(files: ['/x/y'], image: Uint8List.fromList([1, 2])));
      expect(result.map((a) => a.path), ['/x/y']);
    });

    test('empty clipboard returns no attachments (fall back to text)', () async {
      expect(await resolveClipboardAttachment(_FakeSource()), isEmpty);
    });
  });

  group('ComposerAttachment', () {
    test('fileName is the last path segment', () {
      expect(const ComposerAttachment(path: '/a/b/c.png', isImage: true).fileName, 'c.png');
      expect(const ComposerAttachment(path: 'bare.txt', isImage: false).fileName, 'bare.txt');
    });
  });

  group('NativeClipboard', () {
    const channel = MethodChannel('clide/clipboard');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('readFiles decodes the native string list', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'readFiles');
        return <String>['/a/b', '/c/d'];
      });
      expect(await const NativeClipboard().readFiles(), ['/a/b', '/c/d']);
    });

    test('readImage decodes native bytes', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'readImage');
        return bytes;
      });
      expect(await const NativeClipboard().readImage(), bytes);
    });

    test('missing platform handler degrades to empty / null', () async {
      // No mock handler registered -> MissingPluginException, swallowed.
      expect(await const NativeClipboard().readFiles(), isEmpty);
      expect(await const NativeClipboard().readImage(), isNull);
    });
  });
}
