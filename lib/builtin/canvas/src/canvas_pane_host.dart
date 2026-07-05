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
/// the JSONCanvas model, and hands it to the interactive [CanvasView].
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
    return CanvasView(doc: doc);
  }
}
