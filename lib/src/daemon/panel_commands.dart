/// Registers panel.* command handlers on a [DaemonDispatcher].
///
/// Verb list (T-119):
///   panel.resize
///
/// Mirrors the keyboard-driven resize that landed in T-111
/// (`lib/kernel/src/panels/drag_resize.dart`): the CLI verb is the
/// other half of D-6's user/Claude parity for panel sizing.
///
/// Kept Flutter-free so test/daemon/ stays under `dart test` (not
/// `flutter test`). The kernel-side bridge that wraps
/// `LayoutArrangement` lives in
/// `lib/src/daemon/panel_resizer_kernel.dart`.
library;

import '../ipc/command_schema.dart';
import '../ipc/envelope.dart';
import '../ipc/schema_v1.dart';
import 'dispatcher.dart';

/// Pluggable backend the CLI/IPC layer drives. Kernel-side
/// implementation wraps `LayoutArrangement`; tests substitute an
/// in-memory fake.
abstract class PanelResizer {
  /// Apply an absolute pixel size to [slot]. Returns false when
  /// the slot is unknown.
  bool setSlotSize(String slot, double size);

  /// Bump [slot]'s current size by a raw delta (px). Sign convention
  /// matches the drag/keyboard handlers from T-111 — positive deltas
  /// grow the slot from its natural edge; right-edge slots flip the
  /// sign internally. Returns false when the slot is unknown or has
  /// no current size.
  bool bumpSlotSize(String slot, double rawDelta);

  /// Set the absolute editor / bottom-panel split ratio. The kernel
  /// clamps to its supported range (0.15..0.70 today).
  void setEditorRatio(double ratio);

  /// Bump the editor split ratio by [delta] (additive, post-clamp).
  void bumpEditorRatio(double delta);

  double? currentSlotSize(String slot);
  double get currentEditorRatio;
}

/// Reserved slot name that routes to [PanelResizer.setEditorRatio] /
/// [PanelResizer.bumpEditorRatio] instead of [PanelResizer.setSlotSize].
const String editorSplitSlot = 'editor';

/// Schema for `panel.resize` (D-74). The dispatcher normalises the
/// argv shape (`positional[0]` → `slot`, `--to/--by` flags) and
/// coerces `to`/`by` to numbers before the handler runs. The
/// "exactly one of to/by" rule is cross-argument semantics, so it
/// stays in the handler.
const CommandSchema _resizeSchema = CommandSchema(
  positional: ['slot'],
  args: {
    'slot': ArgSpec(required: true),
    'to': ArgSpec(type: ArgType.number),
    'by': ArgSpec(type: ArgType.number),
  },
);

void registerPanelCommands(DaemonDispatcher d, PanelResizer resizer) {
  d.register('panel.resize', (req) => _resize(req, resizer), schema: _resizeSchema);
}

Future<IpcResponse> _resize(IpcRequest req, PanelResizer r) async {
  // Args are schema-normalised + coerced by the dispatcher: `slot` is a
  // non-empty string, `to`/`by` are num? when present.
  final slot = req.args['slot'] as String;
  final hasTo = req.args['to'] != null;
  final hasBy = req.args['by'] != null;
  if (!hasTo && !hasBy) {
    return _userErr(req.id, 'one of `to` (absolute) or `by` (delta) is required');
  }
  if (hasTo && hasBy) {
    return _userErr(req.id, 'pass only one of `to` and `by`');
  }
  final value = ((hasTo ? req.args['to'] : req.args['by']) as num).toDouble();

  if (slot == editorSplitSlot) {
    if (hasTo) {
      r.setEditorRatio(value);
    } else {
      r.bumpEditorRatio(value);
    }
    return IpcResponse.ok(id: req.id, data: {
      'slot': slot,
      'ratio': r.currentEditorRatio,
    });
  }

  final ok = hasTo ? r.setSlotSize(slot, value) : r.bumpSlotSize(slot, value);
  if (!ok) {
    return _notFound(req.id, 'no such slot: $slot');
  }
  return IpcResponse.ok(id: req.id, data: {
    'slot': slot,
    'size': r.currentSlotSize(slot),
  });
}

IpcResponse _userErr(String id, String message, {String? hint}) => IpcResponse.err(
      id: id,
      error: IpcError(
        code: IpcExitCode.userError,
        kind: IpcErrorKind.userError,
        message: message,
        hint: hint,
      ),
    );

IpcResponse _notFound(String id, String message) => IpcResponse.err(
      id: id,
      error: IpcError(
        code: IpcExitCode.notFound,
        kind: IpcErrorKind.notFound,
        message: message,
      ),
    );
