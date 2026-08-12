/// The canvas workspace pane body (T-322): renders the extension-owned
/// [MultitabController] of open `.canvas` documents as real sub-tabs.
/// The controller lives app-scoped on [CanvasExtension] (the diff/T-233
/// pattern) so open documents survive the pane being torn down while the
/// user works in another workspace tab.
library;

import 'dart:async';

import 'package:clide/builtin/canvas/src/canvas_store.dart';
import 'package:clide/builtin/canvas/src/canvas_view.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class CanvasPaneHost extends StatelessWidget {
  const CanvasPaneHost({super.key, this.tabs, this.store});

  /// Open documents, keyed by workspace path. Null until the extension
  /// activates (the contribution builder captures the field lazily).
  final MultitabController<String>? tabs;

  /// The extension's document store — the same state the `canvas.*` verbs
  /// drive. Null until activation, like [tabs].
  final CanvasDocumentStore? store;

  @override
  Widget build(BuildContext context) {
    final controller = tabs;
    final docs = store;
    if (controller == null || docs == null) return const _EmptyHint();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isEmpty) return const _EmptyHint();
        return MultitabPane<String>(
          controller: controller,
          // Keep every document's view state (pan/zoom, selection) alive
          // across sub-tab switches. The document itself now lives in the
          // store, so it survives regardless.
          keepAlive: true,
          bodyBuilder: (_, entry) => CanvasDocumentTab(path: entry.payload, store: docs),
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

/// One open `.canvas` document. The document itself lives in the
/// [CanvasDocumentStore]; this widget asks the store to load it, renders
/// whatever the store currently holds, and hands edits back to it — so a
/// `canvas.*` verb and a drag both land in one place.
class CanvasDocumentTab extends StatefulWidget {
  const CanvasDocumentTab({super.key, required this.path, required this.store});

  final String path;
  final CanvasDocumentStore store;

  @override
  State<CanvasDocumentTab> createState() => _CanvasDocumentTabState();
}

class _CanvasDocumentTabState extends State<CanvasDocumentTab> {
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    unawaited(widget.store.open(widget.path));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final entry = widget.store.entry(widget.path);
        final error = entry?.error;
        if (error != null) {
          return Padding(padding: const EdgeInsets.all(12), child: ClideText(error, muted: true));
        }
        final doc = entry?.doc;
        if (doc == null) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: ClideText(ClideSettings.i18n.string(context, 'status.loading', namespace: 'builtin.canvas', placeholder: 'Loading…'), muted: true),
          );
        }
        return CanvasView(
          // Keyed by path: a store update for THIS document is an external
          // edit that must not reset the user's pan/zoom, whereas a
          // different document genuinely is a fresh view.
          documentKey: widget.path,
          doc: doc,
          onChanged: (next) => unawaited(widget.store.apply(widget.path, next)),
        );
      },
    );
  }
}
