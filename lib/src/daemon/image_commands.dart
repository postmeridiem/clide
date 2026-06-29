/// Registers `image.show` — drive an image card into the Claude conversation
/// log from the CLI (T-249, D-6 parity).
///
///   clide image show docs/wireframes/hud.png
///   clide image show /abs/path/shot.jpg --caption "before the fix"
///
/// The card itself is clide-owned rendering in the conversation view; this is
/// its CLI counterpart. Like `ui.open` / `ui.toast`, the handler is decoupled
/// from the live UI: it validates the request, resolves the path to a real
/// on-disk file via an injected [ImagePathResolver], then publishes an `image`
/// message on the kernel MessageBus (captured post-boot in main.dart). A
/// consumer in the Claude extension injects the matching [ImageMessage] into
/// the primary session's conversation. Flutter-free so it runs under
/// `dart test`.
library;

import 'dart:convert';

import '../ipc/command_schema.dart';
import '../ipc/envelope.dart';
import '../ipc/schema_v1.dart';
import 'dispatcher.dart';
import 'ui_command.dart' show MessagePublisher;

/// Image formats `image.show` accepts, matched on the path's extension. Mirrors
/// the composer's attachment sniff so what you can paste in, you can show.
const imageShowExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};

/// Resolves a user-supplied image path (absolute or workspace-relative) to an
/// absolute path to an existing file, or null when no such file exists.
/// Injected so this file stays Flutter-free and unit-testable without touching
/// the real filesystem; main.dart wires it to the workspace root + `File`.
typedef ImagePathResolver = String? Function(String path);

/// Reads a metadata JSON file's contents, or null if unreadable. Injected so
/// this file stays Flutter-free and unit-testable (T-316).
typedef ImageFileReader = Future<String?> Function(String path);

/// The MessageBus channel `image.show` publishes on; the Claude extension
/// subscribes to the same literal to inject the card. Kept here next to the
/// publisher so both ends point at one name.
const imageShowChannel = 'image';

void registerImageCommands(DaemonDispatcher d, MessagePublisher? Function() publisher, {ImagePathResolver? resolve, ImageFileReader? readFile}) {
  d.register(
    'image.show',
    (req) async => _show(req, publisher, resolve, readFile),
    schema: const CommandSchema(
      positional: ['path'],
      args: {
        // Not required — the path may instead come from a --file payload (T-316).
        'path': ArgSpec(rejectLeadingDash: true),
        'caption': ArgSpec(),
        'file': ArgSpec(rejectLeadingDash: true),
        'fullscreen': ArgSpec(type: ArgType.boolean),
      },
    ),
  );
}

IpcResponse _userErr(String id, String message, {String? hint}) => IpcResponse.err(
  id: id,
  error: IpcError(code: IpcExitCode.userError, kind: IpcErrorKind.userError, message: message, hint: hint),
);

Future<IpcResponse> _show(IpcRequest req, MessagePublisher? Function() publisherSource, ImagePathResolver? resolve, ImageFileReader? readFile) async {
  String? path = req.args['path'] as String?;
  String? label, description;
  String? caption = req.args['caption'] as String?;

  // --file <json>: an annotation payload {path,label,description,caption}
  // (T-316). Additive — the bare `image show <path> [--caption]` form is
  // unchanged; label/description are the new richer metadata.
  final file = req.args['file'] as String?;
  if (file != null && file.trim().isNotEmpty) {
    final raw = readFile == null ? null : await readFile(file);
    if (raw == null) {
      return IpcResponse.err(
        id: req.id,
        error: IpcError(
          code: IpcExitCode.notFound,
          kind: IpcErrorKind.notFound,
          message: 'no such file: $file',
          hint: 'path is resolved relative to the workspace root',
        ),
      );
    }
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      return _userErr(req.id, 'invalid JSON in $file: ${e.message}');
    }
    if (decoded is! Map) return _userErr(req.id, 'image metadata must be a JSON object');
    path = _str(decoded['path']) ?? path;
    label = _str(decoded['label']);
    description = _str(decoded['description']);
    caption = _str(decoded['caption']) ?? caption;
  }

  if (path == null || path.trim().isEmpty) {
    return _userErr(req.id, 'an image path is required (e.g. `image show docs/diagram.png` or `image show --file meta.json`)');
  }

  final ext = _extensionOf(path);
  if (!imageShowExtensions.contains(ext)) {
    return _userErr(req.id, 'unsupported image format${ext.isEmpty ? '' : ' ".$ext"'}', hint: 'one of: ${(imageShowExtensions.toList()..sort()).join(', ')}');
  }

  // Resolve to a concrete file before publishing, so the CLI fails honestly on
  // a typo instead of silently showing a broken card. A null resolver (headless
  // tests) passes the path through unverified.
  String resolved = path;
  if (resolve != null) {
    final abs = resolve(path);
    if (abs == null) {
      return IpcResponse.err(
        id: req.id,
        error: IpcError(
          code: IpcExitCode.notFound,
          kind: IpcErrorKind.notFound,
          message: 'no such image: $path',
          hint: 'path is resolved relative to the workspace root',
        ),
      );
    }
    resolved = abs;
  }

  final publish = publisherSource();
  if (publish == null) {
    // No live UI bus — headless / CLI-only context. Honest failure, not a hang.
    return IpcResponse.err(
      id: req.id,
      error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'no live UI to drive (clide is not running a GUI)'),
    );
  }
  final fullscreen = req.args['fullscreen'] == true;
  publish('cli', imageShowChannel, {
    'path': resolved,
    if (caption != null && caption.trim().isNotEmpty) 'caption': caption.trim(),
    'label': ?label,
    'description': ?description,
    if (fullscreen) 'fullscreen': true,
  });
  return IpcResponse.ok(
    id: req.id,
    data: {'path': resolved, 'caption': ?caption, 'label': ?label, 'description': ?description, 'fullscreen': fullscreen, 'shown': true},
  );
}

/// Trimmed non-empty string, or null — for tolerant JSON field reads.
String? _str(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

/// Lower-cased extension (without the dot) of [path], or '' if none.
String _extensionOf(String path) {
  final slash = path.lastIndexOf('/');
  final dot = path.lastIndexOf('.');
  if (dot <= 0 || dot < slash || dot == path.length - 1) return '';
  return path.substring(dot + 1).toLowerCase();
}
