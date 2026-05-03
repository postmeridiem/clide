/// Sidebar panel for pql — ranked search, DSL query, and markdown file listing.
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
  StreamSubscription<DaemonEvent>? _fileSub;

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
    _fileSub = kernel.events
        .on<DaemonEvent>()
        .where((e) => e.subsystem == 'files' && e.kind == 'files.changed' && (e.data['path'] as String? ?? '').endsWith('.md'))
        .listen((_) {
      if (_controller?.view == PqlView.markdown) {
        unawaited(_controller!.loadMarkdownFiles());
      }
    });
  }

  @override
  void dispose() {
    _focusSub?.cancel();
    _fileSub?.cancel();
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
            if (c.view == PqlView.query) ...[
              _SearchInput(controller: c),
            ],
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
            if (c.loading && c.results.isEmpty) const Padding(padding: EdgeInsets.all(12), child: ClideText('Loading…', muted: true)),
            if (!c.loading && c.results.isEmpty && c.error == null && c.view == PqlView.markdown)
              const Padding(padding: EdgeInsets.all(12), child: ClideText('No markdown files found.', muted: true)),
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
                    if (c.view == PqlView.query && c.searchMode == SearchMode.search)
                      for (final r in c.results) _SearchResultRow(entry: r),
                    if (c.view == PqlView.query && c.searchMode == SearchMode.dsl)
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

class _SearchInput extends StatelessWidget {
  const _SearchInput({required this.controller});
  final PqlController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final isDsl = controller.searchMode == SearchMode.dsl;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClideFilterBox(
          hint: isDsl ? 'PQL query…' : 'Search vault…',
          debounce: isDsl ? Duration.zero : const Duration(milliseconds: 300),
          onChanged: isDsl ? (_) {} : (v) => unawaited(controller.search(v)),
          onSubmitted: isDsl ? (v) => unawaited(controller.runQuery(v)) : (v) => unawaited(controller.search(v)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            children: [
              GestureDetector(
                onTap: controller.toggleSearchMode,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDsl ? tokens.globalFocus.withAlpha(0x30) : null,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: isDsl ? tokens.globalFocus : tokens.panelBorder),
                    ),
                    child: ClideText('DSL', fontSize: clideFontBadge, color: isDsl ? tokens.globalFocus : tokens.globalTextMuted, fontFamily: clideMonoFamily),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ClideText(
                isDsl ? 'SQL-like query mode' : 'ranked text search',
                fontSize: clideFontBadge,
                muted: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({required this.entry});
  final Map<String, Object?> entry;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final path = entry['path'] as String? ?? '';
    final score = (entry['score'] as num?)?.toDouble() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ClideTappable(
        onTap: () {
          if (path.endsWith('.md')) {
            ClideKernel.of(context).messages.publish('builtin.markdown', 'selection', {'path': path});
          }
        },
        builder: (context, hovered, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: hovered ? tokens.sidebarItemHover : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClideText(path, fontSize: clideFontCaption, color: tokens.sidebarForeground, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              _ScoreBar(score: score, tokens: tokens),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.score, required this.tokens});
  final double score;
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          height: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(1.5),
            child: ColoredBox(
              color: tokens.panelBorder,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: score.clamp(0, 1),
                child: ColoredBox(color: tokens.globalFocus),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        ClideText('${(score * 100).round()}%', fontSize: clideFontBadge, muted: true, fontFamily: clideMonoFamily),
      ],
    );
  }
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
    final values = entry.entries.where((e) => e.key != 'name' && e.key != 'path').map((e) => '${e.key}: ${e.value}').join(' · ');
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
