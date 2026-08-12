/// The canvas workspace pane body (T-322): renders the extension-owned
/// [MultitabController] of open `.canvas` documents as real sub-tabs.
/// The controller lives app-scoped on [CanvasExtension] (the diff/T-233
/// pattern) so open documents survive the pane being torn down while the
/// user works in another workspace tab.
library;

import 'dart:async';

import 'package:clide/builtin/canvas/src/canvas_view.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/canvas/json_canvas.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class CanvasPaneHost extends StatelessWidget {
  const CanvasPaneHost({super.key, this.tabs});

  /// Open documents, keyed by workspace path. Null until the extension
  /// activates (the contribution builder captures the field lazily).
  final MultitabController<String>? tabs;

  @override
  Widget build(BuildContext context) {
    final controller = tabs;
    if (controller == null) return const _EmptyHint();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isEmpty) return const _EmptyHint();
        return MultitabPane<String>(
          controller: controller,
          // Keep every document's State (parsed doc, pan/zoom, selection)
          // alive across sub-tab switches.
          keepAlive: true,
          bodyBuilder: (_, entry) => CanvasDocumentTab(path: entry.payload),
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClideText(
        ClideSettings.i18n.string(context, 'empty', namespace: 'builtin.canvas', placeholder: 'Open a .canvas file to view it here.'),
        muted: true,
      ),
    );
  }
}

/// One open `.canvas` document: fetches [path] through `files.read`, parses
/// the JSONCanvas model, hands it to the interactive [CanvasView], and
/// writes edits back through `files.write`.
class CanvasDocumentTab extends StatefulWidget {
  const CanvasDocumentTab({super.key, required this.path});

  final String path;

  @override
  State<CanvasDocumentTab> createState() => _CanvasDocumentTabState();
}

class _CanvasDocumentTabState extends State<CanvasDocumentTab> {
  CanvasDoc? _doc;
  String? _error;
  bool _requested = false;

  /// One write at a time. [CanvasView] reports once per gesture, but a fast
  /// sequence of drags would otherwise overlap writes to the same file and
  /// land in completion order rather than edit order.
  bool _writing = false;
  CanvasDoc? _queued;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    unawaited(_load(ClideKernel.of(context)));
  }

  Future<void> _load(KernelServices kernel) async {
    final resp = await kernel.ipc.request('files.read', args: {'path': widget.path});
    if (!mounted) return;
    if (!resp.ok) {
      setState(() => _error = resp.error?.message ?? widget.path);
      return;
    }
    try {
      final doc = CanvasDoc.parse(resp.data['content'] as String? ?? '');
      setState(() => _doc = doc);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  void _onChanged(CanvasDoc doc) {
    setState(() => _doc = doc);
    unawaited(_save(ClideKernel.of(context), doc));
  }

  /// Persist [doc], coalescing anything that arrives mid-write down to the
  /// latest — an intermediate drag position isn't worth a second round trip.
  Future<void> _save(KernelServices kernel, CanvasDoc doc) async {
    if (_writing) {
      _queued = doc;
      return;
    }
    _writing = true;
    try {
      var pending = doc;
      while (true) {
        final resp = await kernel.ipc.request('files.write', args: {'path': widget.path, 'text': pending.encode()});
        if (!resp.ok) _reportSaveFailure(kernel, resp.error?.message ?? '');
        final next = _queued;
        _queued = null;
        if (next == null) return;
        pending = next;
      }
    } finally {
      _writing = false;
    }
  }

  /// A failed save is a toast, not a pane replacement: the canvas on screen
  /// is still the user's work and blanking it would lose the edit they were
  /// trying to keep.
  void _reportSaveFailure(KernelServices kernel, String reason) {
    if (!mounted) return;
    publishToast(
      kernel.messages,
      'builtin.canvas',
      ClideSettings.i18n.interpolated(
        context,
        'save.failed',
        namespace: 'builtin.canvas',
        placeholder: 'Could not save {path}: {reason}',
        replacers: [
          I18nReplacer(from: '{path}', replace: widget.path),
          I18nReplacer(from: '{reason}', replace: reason),
        ],
      ),
      severity: ToastSeverity.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Padding(padding: const EdgeInsets.all(12), child: ClideText(error, muted: true));
    }
    final doc = _doc;
    if (doc == null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: ClideText(ClideSettings.i18n.string(context, 'status.loading', namespace: 'builtin.canvas', placeholder: 'Loading…'), muted: true),
      );
    }
    return CanvasView(doc: doc, onChanged: _onChanged);
  }
}
