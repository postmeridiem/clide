/// Registers `draw` — drive a drawing card into the Claude conversation from
/// the CLI (T-318, D-91 / D-103, D-6 parity).
///
///   clide draw --file card.json
///
/// The card is clide-owned rendering (the SVG engine + the [DrawingCard]
/// widget); this is its CLI counterpart. Mirroring `image.show`, the handler is
/// decoupled from the live UI: it reads + parses the JSON document (via an
/// injected [DrawingFileReader]), lowers it to an SVG string through the
/// template [DrawingRegistry], then publishes a `draw` message on the kernel
/// MessageBus. A consumer in the Claude extension builds the SvgDocument and
/// injects the card into the primary session. Flutter-free so it runs under
/// `dart test`.
library;

import 'dart:convert';

import '../draw/draw_dispatch.dart';
import '../draw/draw_doc.dart';

export '../draw/draw_dispatch.dart' show DrawErr, DrawOk, DrawResult, DrawingFileReader, DrawingRegistry, DrawingTemplateHandler;
import '../ipc/command_schema.dart';
import '../ipc/envelope.dart';
import '../ipc/schema_v1.dart';
import 'dispatcher.dart';
import 'ui_command.dart' show MessagePublisher;

/// The MessageBus channel `draw` publishes on; the Claude extension subscribes
/// to the same literal to inject the card.
const drawShowChannel = 'draw';

void registerDrawCommands(
  DaemonDispatcher d,
  MessagePublisher? Function() publisher, {
  required DrawingRegistry registry,
  required DrawingFileReader readFile,
}) {
  d.register(
    'draw',
    (req) async => _draw(req, publisher, registry, readFile),
    schema: const CommandSchema(args: {'file': ArgSpec(required: true, rejectLeadingDash: true)}),
  );
}

IpcResponse _userErr(String id, String message, {String? hint}) => IpcResponse.err(
  id: id,
  error: IpcError(code: IpcExitCode.userError, kind: IpcErrorKind.userError, message: message, hint: hint),
);

Future<IpcResponse> _draw(IpcRequest req, MessagePublisher? Function() publisherSource, DrawingRegistry registry, DrawingFileReader readFile) async {
  final file = req.args['file'] as String?;
  if (file == null || file.trim().isEmpty) {
    return _userErr(req.id, 'a drawing-card document is required (e.g. `draw --file card.json`)');
  }

  final raw = await readFile(file);
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

  // Type inference from the extension (T-494): a `.d2`/`.svg` file is the raw
  // source, not a JSON envelope — wrap it in the matching doc. Everything else
  // is a drawing-card JSON document.
  final lower = file.toLowerCase();
  final DrawingCardDoc? doc;
  if (lower.endsWith('.d2')) {
    doc = DrawingCardDoc(template: 'd2', fields: {'template': 'd2', 'source': raw});
  } else if (lower.endsWith('.svg')) {
    doc = DrawingCardDoc(svg: raw);
  } else {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      return _userErr(req.id, 'invalid JSON in $file: ${e.message}');
    }
    doc = parseDrawingCardDoc(decoded);
    if (doc == null) return _userErr(req.id, 'a drawing-card document must be a JSON object');
  }

  final result = await resolveDrawingSvg(doc, registry, readFile: readFile);
  if (result is DrawErr) return _userErr(req.id, result.message);
  final svg = (result as DrawOk).svg;

  final publish = publisherSource();
  if (publish == null) {
    return IpcResponse.err(
      id: req.id,
      error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'no live UI to drive (clide is not running a GUI)'),
    );
  }

  publish('cli', drawShowChannel, {
    'svg': svg,
    if (doc.label != null) 'label': doc.label,
    if (doc.description != null) 'description': doc.description,
    // d2 cards carry their source so the card can offer a "view source" peek.
    if (doc.template == 'd2' && doc.fields['source'] is String) 'source': doc.fields['source'],
  });
  return IpcResponse.ok(id: req.id, data: {'shown': true, if (doc.template != null) 'template': doc.template});
}
