/// Sidebar panel for pql — file listing, DSL query input,
/// decisions list, and ticket board views.
library;

import 'dart:async';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'pql_controller.dart';

class PqlPanelView extends StatefulWidget {
  const PqlPanelView({super.key});

  @override
  State<PqlPanelView> createState() => _PqlPanelViewState();
}

class _PqlPanelViewState extends State<PqlPanelView> {
  PqlController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final kernel = ClideKernel.of(context);
    _controller = PqlController(ipc: kernel.ipc);
    unawaited(_controller!.loadFiles());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final tokens = ClideTheme.of(context).surface;
        return Semantics(
          label: 'pql panel',
          container: true,
          explicitChildNodes: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ViewTabs(controller: c),
              if (c.view == PqlView.query)
                ClideFilterBox(
                  hint: 'PQL query…',
                  debounce: Duration.zero,
                  onChanged: (_) {},
                  onSubmitted: (v) => unawaited(c.runQuery(v)),
                ),
              if (c.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  child: ClideText(
                    c.error!,
                    color: tokens.statusError,
                    fontSize: clideFontCaption,
                    maxLines: 3,
                  ),
                ),
              if (c.loading && c.results.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: ClideText('Loading…', muted: true),
                ),
              if (!c.loading && c.results.isEmpty && c.error == null)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: ClideText('No results.', muted: true),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (c.view == PqlView.files)
                        for (final f in c.results) _FileRow(entry: f),
                      if (c.view == PqlView.query)
                        for (final r in c.results) _QueryResultRow(entry: r),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ViewTabs extends StatelessWidget {
  const _ViewTabs({required this.controller});
  final PqlController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.panelBorder)),
      ),
      child: Row(
        children: [
          for (final v in PqlView.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                button: true,
                toggled: controller.view == v,
                label: v.name,
                child: GestureDetector(
                  onTap: () => controller.switchView(v),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ClideText(
                      _tabLabel(v),
                      fontSize: clideFontCaption,
                      color: controller.view == v
                          ? tokens.globalForeground
                          : tokens.globalTextMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _tabLabel(PqlView v) => switch (v) {
        PqlView.files => 'Files',
        PqlView.query => 'Query',
      };
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.entry});
  final Map<String, Object?> entry;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final path = entry['path'] as String? ?? '';
    final name = entry['name'] as String? ?? path.split('/').last;
    return Semantics(
      button: true,
      label: 'Open $name',
      child: ClideTappable(
        onTap: () {
          final kernel = ClideKernel.of(context);
          unawaited(
              kernel.ipc.request('editor.open', args: {'path': path}));
        },
        builder: (context, hovered, _) => Container(
          color: hovered ? tokens.sidebarItemHover : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: ClideText(
            path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            color: tokens.sidebarForeground,
          ),
        ),
      ),
    );
  }
}

class _QueryResultRow extends StatelessWidget {
  const _QueryResultRow({required this.entry});
  final Map<String, Object?> entry;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final name = entry['name'] as String? ?? entry['path'] as String? ?? '';
    final values = entry.entries
        .where((e) => e.key != 'name' && e.key != 'path')
        .map((e) => '${e.key}: ${e.value}')
        .join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClideText(name, color: tokens.sidebarForeground),
          if (values.isNotEmpty)
            ClideText(values, fontSize: clideFontCaption, muted: true, maxLines: 2),
        ],
      ),
    );
  }
}
