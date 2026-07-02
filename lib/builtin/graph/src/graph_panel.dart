/// The vault link-graph context panel (T-323): loads the whole vault's link
/// graph from pql via [GraphController] and renders it with [GraphView],
/// wiring a node click to open that note in the editor. Shows loading / error
/// / empty states until there's a graph to draw; a debounced refresh keeps the
/// existing graph on screen rather than flashing back to the spinner.
library;

import 'dart:async';

import 'package:clide/builtin/graph/src/graph_controller.dart';
import 'package:clide/builtin/graph/src/graph_view.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class GraphPanel extends StatefulWidget {
  const GraphPanel({super.key});

  @override
  State<GraphPanel> createState() => _GraphPanelState();
}

class _GraphPanelState extends State<GraphPanel> {
  GraphController? _controller;
  DaemonClient? _ipc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final kernel = ClideKernel.of(context);
    _ipc = kernel.ipc;
    _controller = GraphController(ipc: kernel.ipc, events: kernel.events);
    unawaited(_controller!.load());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _open(String nodeId) => unawaited(_ipc?.request('editor.open', args: {'path': nodeId}));

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        // Once we have a graph, keep drawing it through a debounced refresh —
        // only the very first load (or a load that cleared it) falls back to
        // the spinner / empty / error states.
        if (!c.graph.isEmpty) return GraphView(graph: c.graph, onOpen: _open);
        if (c.loading) return const Center(child: ClideSpinner(size: 20, semanticLabel: 'Loading graph'));
        if (c.error != null) {
          return _message(ClideSettings.theme.of(context).surface.statusError, c.error!);
        }
        return _message(null, ClideSettings.i18n.string(context, 'graph.empty', namespace: 'builtin.graph', placeholder: 'No linked notes in this vault.'));
      },
    );
  }

  Widget _message(Color? color, String text) => Padding(
    padding: const EdgeInsets.all(16),
    child: ClideText(text, color: color, muted: color == null, fontSize: clideFontCaption, textAlign: TextAlign.center),
  );
}
