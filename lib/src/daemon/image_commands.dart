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

/// The MessageBus channel `image.show` publishes on; the Claude extension
/// subscribes to the same literal to inject the card. Kept here next to the
/// publisher so both ends point at one name.
const imageShowChannel = 'image';

void registerImageCommands(
  DaemonDispatcher d,
  MessagePublisher? Function() publisher, {
  ImagePathResolver? resolve,
}) {
  d.register(
    'image.show',
    (req) async => _show(req, publisher, resolve),
    schema: const CommandSchema(
      positional: ['path'],
      args: {
        'path': ArgSpec(required: true, rejectLeadingDash: true),
        'caption': ArgSpec(),
      },
    ),
  );
}

IpcResponse _userErr(String id, String message, {String? hint}) => IpcResponse.err(
      id: id,
      error: IpcError(code: IpcExitCode.userError, kind: IpcErrorKind.userError, message: message, hint: hint),
    );

Future<IpcResponse> _show(
  IpcRequest req,
  MessagePublisher? Function() publisherSource,
  ImagePathResolver? resolve,
) async {
  final path = req.args['path'] as String?;
  if (path == null || path.trim().isEmpty) {
    return _userErr(req.id, 'an image path is required (e.g. `image show docs/diagram.png`)');
  }

  final ext = _extensionOf(path);
  if (!imageShowExtensions.contains(ext)) {
    return _userErr(
      req.id,
      'unsupported image format${ext.isEmpty ? '' : ' ".$ext"'}',
      hint: 'one of: ${(imageShowExtensions.toList()..sort()).join(', ')}',
    );
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

  final caption = req.args['caption'] as String?;

  final publish = publisherSource();
  if (publish == null) {
    // No live UI bus — headless / CLI-only context. Honest failure, not a hang.
    return IpcResponse.err(
      id: req.id,
      error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'no live UI to drive (clide is not running a GUI)'),
    );
  }
  publish('cli', imageShowChannel, {
    'path': resolved,
    if (caption != null && caption.trim().isNotEmpty) 'caption': caption.trim(),
  });
  return IpcResponse.ok(id: req.id, data: {'path': resolved, if (caption != null) 'caption': caption, 'shown': true});
}

/// Lower-cased extension (without the dot) of [path], or '' if none.
String _extensionOf(String path) {
  final slash = path.lastIndexOf('/');
  final dot = path.lastIndexOf('.');
  if (dot <= 0 || dot < slash || dot == path.length - 1) return '';
  return path.substring(dot + 1).toLowerCase();
}
