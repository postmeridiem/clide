/// Registers `icon.show` — drive a Phosphor glyph card into the Claude
/// conversation from the CLI (T-313, D-6 parity).
///
///   clide icon show gear folder gauge
///   clide icon show --file icons.json   # entries with label/description/color
///
/// Mirrors `image.show` end to end: a Flutter-free handler validates + resolves
/// each glyph (via an injected [IconResolver], so dart-test needs no font),
/// validates any colors (reusing [parseSvgColor] — hex or CSS name), then
/// publishes on the `icon` MessageBus channel. The Claude extension injects the
/// matching card. Honest userError on an unknown glyph, a malformed/missing
/// `--file`, or an unparseable color; toolError when there is no live UI.
///
/// Flutter-free: pure Dart, runs under `dart test`.
library;

import 'dart:convert';

import '../ipc/command_schema.dart';
import '../ipc/envelope.dart';
import '../ipc/schema_v1.dart';
import '../svg/svg_color.dart' show parseSvgColor;
import 'dispatcher.dart';
import 'ui_command.dart' show MessagePublisher;

/// Resolves a Phosphor glyph name to its codepoint, or null if unknown. Injected
/// (wired to `kPhosphorGlyphs` in main.dart) so this file stays Flutter-free.
typedef IconResolver = int? Function(String name);

/// Reads a metadata JSON file's contents, or null if unreadable. Injected for
/// testability.
typedef IconFileReader = Future<String?> Function(String path);

/// The MessageBus channel `icon.show` publishes on; the Claude extension
/// subscribes to the same literal to inject the card.
const iconShowChannel = 'icon';

void registerIconCommands(DaemonDispatcher d, MessagePublisher? Function() publisher, {required IconResolver resolve, IconFileReader? readFile}) {
  d.register(
    'icon.show',
    (req) async => _show(req, publisher, resolve, readFile),
    schema: const CommandSchema(
      positional: ['icons'],
      args: {
        'icons': ArgSpec(type: ArgType.stringList, rejectLeadingDash: true),
        'file': ArgSpec(rejectLeadingDash: true),
        'color': ArgSpec(),
      },
    ),
  );
}

IpcResponse _userErr(String id, String message, {String? hint}) => IpcResponse.err(
  id: id,
  error: IpcError(code: IpcExitCode.userError, kind: IpcErrorKind.userError, message: message, hint: hint),
);

Future<IpcResponse> _show(IpcRequest req, MessagePublisher? Function() publisherSource, IconResolver resolve, IconFileReader? readFile) async {
  final defaultColor = _str(req.args['color']);
  if (defaultColor != null && parseSvgColor(defaultColor) == null) {
    return _userErr(req.id, 'invalid color: $defaultColor', hint: '#rrggbb, #rrggbbaa, or a CSS color name');
  }

  final entries = <Map<String, Object?>>[];
  // The entry payload comes from a piped --stdin (T-315) or a --file; --stdin
  // wins. Either is a JSON array of {icon,label,description,color}.
  final stdin = _str(req.args['stdin']);
  final file = _str(req.args['file']);
  String? payload = stdin;
  if (payload == null && file != null) {
    payload = readFile == null ? null : await readFile(file);
    if (payload == null) {
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
  }

  if (payload != null) {
    Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException catch (e) {
      return _userErr(req.id, 'invalid JSON in the icon payload: ${e.message}');
    }
    if (decoded is! List) return _userErr(req.id, 'icon metadata must be a JSON array of entries');
    for (final item in decoded) {
      if (item is! Map) return _userErr(req.id, 'each icon entry must be a JSON object');
      final token = _str(item['icon']);
      if (token == null) return _userErr(req.id, 'each entry needs an "icon" name or 0x codepoint');
      final cp = _resolveIcon(token, resolve);
      if (cp == null) return _userErr(req.id, 'unknown icon: $token', hint: 'a kebab-case Phosphor name (e.g. gear) or a 0xNNNN codepoint');
      final color = _str(item['color']);
      if (color != null && parseSvgColor(color) == null) return _userErr(req.id, 'invalid color: $color', hint: '#rrggbb, #rrggbbaa, or a CSS color name');
      entries.add({'codepoint': cp, 'name': token, 'label': ?_str(item['label']), 'description': ?_str(item['description']), 'color': ?color});
    }
  } else {
    final icons = (req.args['icons'] as List?)?.whereType<String>() ?? const <String>[];
    for (final token in icons) {
      final cp = _resolveIcon(token, resolve);
      if (cp == null) return _userErr(req.id, 'unknown icon: $token', hint: 'a kebab-case Phosphor name (e.g. gear) or a 0xNNNN codepoint');
      entries.add({'codepoint': cp, 'name': token});
    }
  }

  if (entries.isEmpty) {
    return _userErr(req.id, 'at least one icon is required (e.g. `icon show gear folder` or `icon show --file icons.json`)');
  }

  final publish = publisherSource();
  if (publish == null) {
    return IpcResponse.err(
      id: req.id,
      error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'no live UI to drive (clide is not running a GUI)'),
    );
  }
  publish('cli', iconShowChannel, {'entries': entries, 'color': ?defaultColor});
  return IpcResponse.ok(id: req.id, data: {'shown': true, 'count': entries.length});
}

/// Resolve an icon [token] — a `0xNNNN` codepoint or a glyph name — to a
/// codepoint, or null if it doesn't parse / resolve.
int? _resolveIcon(String token, IconResolver resolve) {
  final t = token.trim();
  if (t.startsWith('0x') || t.startsWith('0X')) return int.tryParse(t.substring(2), radix: 16);
  return resolve(t);
}

/// Trimmed non-empty string, or null — for tolerant arg/JSON reads.
String? _str(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
