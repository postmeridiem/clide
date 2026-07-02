/// The vault link-graph context panel (T-323): loads the whole vault's link
/// graph from pql via [GraphController] and renders the filtered [GraphView],
/// wiring a node click to open that note in the editor.
///
/// Above the graph sits a filter bar — a path glob (re-queries pql on submit),
/// a depth-from-active selector (the local graph around the open note), and
/// tri-state tag pills (neutral → include → exclude). Loading / error / empty
/// states show until there's a graph; a debounced refresh keeps the existing
/// graph on screen rather than flashing back to the spinner.
library;

import 'dart:async';

import 'package:clide/builtin/graph/src/graph_controller.dart';
import 'package:clide/builtin/graph/src/graph_view.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/graph/graph_filter.dart';
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

  String _t(String key, String fallback) => ClideSettings.i18n.string(context, key, namespace: 'builtin.graph', placeholder: fallback);

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        // Before we have any graph, the pre-load states own the whole panel.
        if (c.graph.isEmpty) {
          if (c.loading) return const Center(child: ClideSpinner(size: 20, semanticLabel: 'Loading graph'));
          if (c.error != null) return _message(ClideSettings.theme.of(context).surface.statusError, c.error!);
          return _message(null, _t('graph.empty', 'No linked notes in this vault.'));
        }
        final visible = c.visibleGraph;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GraphFilterBar(controller: c, t: _t),
            Expanded(
              child: visible.isEmpty
                  ? _message(
                      null,
                      c.filter.depth != null && c.activePath == null
                          ? _t('graph.empty.nolocal', 'Open a note to see its local graph.')
                          : _t('graph.empty.filtered', 'No notes match the filter.'),
                    )
                  : GraphView(graph: visible, onOpen: _open),
            ),
          ],
        );
      },
    );
  }

  Widget _message(Color? color, String text) => Padding(
    padding: const EdgeInsets.all(16),
    child: ClideText(text, color: color, muted: color == null, fontSize: clideFontCaption, textAlign: TextAlign.center),
  );
}

/// The glob + depth + tag controls above the graph. Reads/writes the
/// controller's glob and [GraphFilter]; keeps no state of its own.
class _GraphFilterBar extends StatelessWidget {
  const _GraphFilterBar({required this.controller, required this.t});

  final GraphController controller;
  final String Function(String key, String fallback) t;

  static const _depths = <(String, int?)>[('All', null), ('1', 1), ('2', 2), ('3', 3)];

  void _setDepth(int? depth) => controller.setFilter(controller.filter.copyWith(depth: depth, clearDepth: depth == null));

  void _cycleTag(String tag) {
    final f = controller.filter;
    final inc = {...f.includeTags}, exc = {...f.excludeTags};
    if (inc.contains(tag)) {
      inc.remove(tag);
      exc.add(tag); // include → exclude
    } else if (exc.contains(tag)) {
      exc.remove(tag); // exclude → neutral
    } else {
      inc.add(tag); // neutral → include
    }
    controller.setFilter(f.copyWith(includeTags: inc, excludeTags: exc));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final f = controller.filter;
    final tags = controller.availableTags;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.dividerColor)),
      ),
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClideFilterBox(
            hint: t('graph.filter.glob', 'Path glob, e.g. notes/**'),
            showIcon: true,
            icon: PhosphorIcons.byName('funnel'),
            onChanged: (_) {}, // reload is heavy (1+N pql calls) — apply on submit only
            onSubmitted: controller.setGlob,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                ClideText(t('graph.filter.depth', 'Local'), fontSize: clideFontCaption, color: tokens.globalTextMuted),
                const SizedBox(width: 8),
                for (final (label, depth) in _depths)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _pill(
                      tokens,
                      label: label == 'All' ? t('graph.filter.all', 'All') : label,
                      selected: f.depth == depth,
                      onTap: () => _setDepth(depth),
                    ),
                  ),
              ],
            ),
          ),
          if (tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 10, right: 10, top: 6),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final tag in tags)
                    _pill(
                      tokens,
                      label: f.excludeTags.contains(tag) ? '−$tag' : (f.includeTags.contains(tag) ? '+$tag' : tag),
                      selected: f.includeTags.contains(tag),
                      danger: f.excludeTags.contains(tag),
                      onTap: () => _cycleTag(tag),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _pill(SurfaceTokens tokens, {required String label, required bool selected, bool danger = false, required VoidCallback onTap}) {
    final accent = danger ? tokens.statusError : tokens.globalFocus;
    final active = selected || danger;
    return ClideTappable(
      onTap: onTap,
      builder: (context, hovered, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.16) : (hovered ? tokens.sidebarItemHover : null),
          border: Border.all(color: active ? accent : tokens.globalBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ClideText(label, fontSize: clideFontCaption, color: active ? accent : tokens.globalForeground),
      ),
    );
  }
}
