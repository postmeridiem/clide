/// Sidebar panel for pql — DSL query input and markdown file listing.
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
  String? _focusedPath;
  final _focusedKey = GlobalKey();
  StreamSubscription<Message>? _focusSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final kernel = ClideKernel.of(context);
    _controller = PqlController(ipc: kernel.ipc);
    _focusSub = kernel.messages.subscribe(publisher: 'builtin.markdown', channel: 'focus').listen((msg) {
      final path = msg.data['path'] as String?;
      if (path == null || path == _focusedPath) return;
      setState(() {
        _focusedPath = path;
        if (_controller!.view != PqlView.markdown) {
          _controller!.switchView(PqlView.markdown);
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _focusedKey.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 200), alignment: 0.3);
      });
    });
  }

  @override
  void dispose() {
    _focusSub?.cancel();
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
        return Column(
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
            if (c.view == PqlView.markdown)
              ClideFilterBox(
                hint: 'Filter markdown…',
                onChanged: (v) => unawaited(c.loadMarkdownFiles(glob: v.isEmpty ? null : '**/*$v*.md')),
              ),
            if (c.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ClideText(c.error!, color: tokens.statusError, fontSize: clideFontCaption, maxLines: 3),
              ),
            if (c.loading && c.results.isEmpty)
              const Padding(padding: EdgeInsets.all(12), child: ClideText('Loading…', muted: true)),
            if (!c.loading && c.results.isEmpty && c.error == null)
              const Padding(padding: EdgeInsets.all(12), child: ClideText('No results.', muted: true)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (c.view == PqlView.markdown)
                      for (final f in c.results)
                        _FileRow(
                          entry: f,
                          focused: (f['path'] as String?) == _focusedPath,
                          focusKey: (f['path'] as String?) == _focusedPath ? _focusedKey : null,
                        ),
                    if (c.view == PqlView.query)
                      for (final r in c.results) _QueryResultRow(entry: r),
                  ],
                ),
              ),
            ),
          ],
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
              child: GestureDetector(
                onTap: () => controller.switchView(v),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ClideText(
                    _tabLabel(v),
                    fontSize: clideFontCaption,
                    color: controller.view == v ? tokens.globalForeground : tokens.globalTextMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _tabLabel(PqlView v) => switch (v) {
        PqlView.query => 'Search',
        PqlView.markdown => 'Markdown',
      };
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.entry, this.focused = false, this.focusKey});
  final Map<String, Object?> entry;
  final bool focused;
  final GlobalKey? focusKey;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final path = entry['path'] as String? ?? '';
    return Padding(
      key: focusKey,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ClideTappable(
        onTap: () => ClideKernel.of(context).messages.publish('builtin.markdown', 'selection', {'path': path}),
        builder: (context, hovered, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: hovered ? tokens.sidebarItemHover : (focused ? tokens.sidebarItemSelected : null),
            borderRadius: BorderRadius.circular(4),
            border: focused ? Border.all(color: tokens.globalFocus, width: 1) : null,
          ),
          child: ClideText(
            path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            fontSize: clideFontCaption,
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
          if (values.isNotEmpty) ClideText(values, fontSize: clideFontCaption, muted: true, maxLines: 2),
        ],
      ),
    );
  }
}
