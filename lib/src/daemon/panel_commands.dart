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

void registerPanelCommands(DaemonDispatcher d, PanelResizer resizer) {
  d.register('panel.resize', (req) => _resize(req, resizer));
}

Future<IpcResponse> _resize(IpcRequest req, PanelResizer r) async {
  final view = _ResizeArgs.from(req.args);
  if (view.slot == null || view.slot!.isEmpty) {
    return _userErr(req.id, 'slot is required (e.g. "sidebar", "context", "$editorSplitSlot")');
  }
  if (!view.hasTo && !view.hasBy) {
    return _userErr(req.id, 'one of `to` (absolute) or `by` (delta) is required');
  }
  if (view.hasTo && view.hasBy) {
    return _userErr(req.id, 'pass only one of `to` and `by`');
  }
  final value = view.value;
  if (value == null) {
    return _userErr(req.id, '${view.hasTo ? "to" : "by"} must be numeric');
  }
  final slot = view.slot!;

  if (slot == editorSplitSlot) {
    if (view.hasTo) {
      r.setEditorRatio(value);
    } else {
      r.bumpEditorRatio(value);
    }
    return IpcResponse.ok(id: req.id, data: {
      'slot': slot,
      'ratio': r.currentEditorRatio,
    });
  }

  final ok = view.hasTo ? r.setSlotSize(slot, value) : r.bumpSlotSize(slot, value);
  if (!ok) {
    return _notFound(req.id, 'no such slot: $slot');
  }
  return IpcResponse.ok(id: req.id, data: {
    'slot': slot,
    'size': r.currentSlotSize(slot),
  });
}

/// Tiny adapter that lifts `panel.resize` arguments out of either
/// the direct call shape (`{slot: ..., to: ...}`) or the argv-
/// translator shape (`{positional: [slot], flags: {to: '...'}}`).
/// Until T-120 formalises a shared schema, individual commands carry
/// the lift themselves.
class _ResizeArgs {
  _ResizeArgs._({
    required this.slot,
    required this.hasTo,
    required this.hasBy,
    required this.value,
  });

  final String? slot;
  final bool hasTo;
  final bool hasBy;
  final double? value;

  factory _ResizeArgs.from(Map<String, Object?> args) {
    String? slot;
    final rawSlot = args['slot'];
    if (rawSlot is String) slot = rawSlot;
    final positional = args['positional'];
    if (slot == null && positional is List && positional.isNotEmpty) {
      slot = positional.first.toString();
    }
    final flags = args['flags'];
    final flagsMap = flags is Map ? flags : const <Object?, Object?>{};
    final hasTo = args.containsKey('to') || flagsMap.containsKey('to');
    final hasBy = args.containsKey('by') || flagsMap.containsKey('by');
    final raw = args.containsKey('to')
        ? args['to']
        : args.containsKey('by')
            ? args['by']
            : flagsMap.containsKey('to')
                ? flagsMap['to']
                : flagsMap['by'];
    return _ResizeArgs._(
      slot: slot,
      hasTo: hasTo,
      hasBy: hasBy,
      value: _coerceNum(raw),
    );
  }

  static double? _coerceNum(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
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
