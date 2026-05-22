/// File/image clipboard paste for the Claude composer (T-138).
///
/// `tmux send-keys` / `pane.write` carry text only, and Claude reads
/// files via `@path` references — so a pasted file or image is always
/// delivered as an `@/absolute/path` token, never as bytes (see the
/// T-134 spike). Flutter's built-in clipboard is text-only, so image
/// and file reads go through a native [MethodChannel] (`clide/clipboard`,
/// implemented per-OS in the GTK and macOS runners). Plain-text paste
/// stays on the Flutter clipboard and is handled by the composer.
library;

import 'dart:io';

import 'package:flutter/services.dart';

/// A pasted file or image the composer shows as a chip and sends to
/// Claude as an `@path` reference.
class ComposerAttachment {
  const ComposerAttachment({required this.path, required this.isImage});

  /// Absolute path on disk (a real file, or a temp file for a pasted
  /// raw image).
  final String path;

  /// Whether [path] is a raster image — chips render a thumbnail for
  /// these and a file icon otherwise.
  final bool isImage;

  /// The token inserted into the message Claude receives.
  String get pathToken => '@$path';

  /// Last path segment, for the chip label.
  String get fileName => path.split('/').where((s) => s.isNotEmpty).lastOrNull ?? path;
}

bool _looksLikeImage(String path) {
  final p = path.toLowerCase();
  return p.endsWith('.png') || p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.gif') || p.endsWith('.webp') || p.endsWith('.bmp');
}

/// Read side of the OS clipboard for the non-text content the composer
/// turns into `@path` tokens. Abstracted so the resolver is testable
/// without the platform channel.
abstract interface class ClipboardSource {
  /// Absolute paths of files currently on the clipboard (copied in a
  /// file manager). Empty when there are none.
  Future<List<String>> readFiles();

  /// PNG bytes of an image on the clipboard (e.g. a screenshot), or null
  /// when there is no image.
  Future<Uint8List?> readImage();
}

/// [ClipboardSource] backed by the native `clide/clipboard` channel.
/// Degrades to "nothing on the clipboard" when no platform handler is
/// registered (e.g. tests, unsupported platforms).
class NativeClipboard implements ClipboardSource {
  const NativeClipboard();

  static const _channel = MethodChannel('clide/clipboard');

  @override
  Future<List<String>> readFiles() async {
    try {
      final r = await _channel.invokeListMethod<String>('readFiles');
      return r ?? const [];
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<Uint8List?> readImage() async {
    try {
      return await _channel.invokeMethod<Uint8List>('readImage');
    } on MissingPluginException {
      return null;
    }
  }
}

/// Directory pasted-image temp files are written to. Mirrors the D-70
/// socket-path convention: macOS `~/Library/Caches/clide/pasted`, else
/// `$XDG_CACHE_HOME` (or `~/.cache`) `/clide/pasted`.
String pasteCacheDir() {
  final home = Platform.environment['HOME'] ?? '/tmp';
  if (Platform.isMacOS) {
    return '$home/Library/Caches/clide/pasted';
  }
  final xdg = Platform.environment['XDG_CACHE_HOME'];
  final base = (xdg != null && xdg.isNotEmpty) ? xdg : '$home/.cache';
  return '$base/clide/pasted';
}

/// Resolve a paste into composer attachments, or an empty list to fall
/// back to plain-text paste.
///
/// Files already on disk become attachments directly. A raw image is
/// written to [tempDir] (default [pasteCacheDir]) and attached by its
/// path. Returns an empty list when the clipboard holds neither, so the
/// composer pastes text instead.
Future<List<ComposerAttachment>> resolveClipboardAttachment(
  ClipboardSource source, {
  Directory? tempDir,
  DateTime Function() now = DateTime.now,
}) async {
  final files = await source.readFiles();
  if (files.isNotEmpty) {
    return [
      for (final p in files) ComposerAttachment(path: p, isImage: _looksLikeImage(p)),
    ];
  }

  final image = await source.readImage();
  if (image != null && image.isNotEmpty) {
    final dir = tempDir ?? Directory(pasteCacheDir());
    await dir.create(recursive: true);
    final file = File('${dir.path}/paste-${now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(image);
    return [ComposerAttachment(path: file.path, isImage: true)];
  }

  return const [];
}
