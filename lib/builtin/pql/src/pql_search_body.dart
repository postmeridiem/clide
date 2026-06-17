/// The pql search/query/markdown body, embedded inside the unified
/// Search tab for the Vault / Query / Markdown modes (T-201). Drives a
/// parent-owned [PqlController]; the parent picks the [PqlPaneMode].
///
/// Vault = ranked text search, Query = PQL DSL, Markdown = the synced
/// markdown-file listing (highlights the open doc, live-refreshes on
/// `.md` changes).
library;

import 'dart:async';

import 'package:clide/builtin/pql/src/pql_controller.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// Which pql sub-surface the Search tab is showing.
enum PqlPaneMode { vault, query, markdown }

class PqlSearchBody extends StatefulWidget {
  const PqlSearchBody({super.key, required this.controller, required this.mode});

  final PqlController controller;
  final PqlPaneMode mode;

  @override
  State<PqlSearchBody> createState() => _PqlSearchBodyState();
}

class _PqlSearchBodyState extends State<PqlSearchBody> {
  String? _focusedPath;
  final _focusedKey = GlobalKey();
  StreamSubscription<Message>? _focusSub;
  StreamSubscription<DaemonEvent>? _fileSub;

  @override
  void initState() {
    super.initState();
    _applyMode();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_focusSub != null) return;
    final kernel = ClideKernel.of(context);
    _focusSub = kernel.messages.subscribe(publisher: 'builtin.markdown', channel: 'focus').listen((msg) {
      final path = msg.data['path'] as String?;
      if (path == null || path == _focusedPath) return;
      setState(() => _focusedPath = path);
      if (widget.controller.view == PqlView.markdown) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _focusedKey.currentContext;
          if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 200), alignment: 0.3);
        });
      }
    });
    _fileSub = kernel.events
        .on<DaemonEvent>()
        .where((e) => e.subsystem == 'files' && e.kind == 'files.changed' && (e.data['path'] as String? ?? '').endsWith('.md'))
        .listen((_) {
          if (widget.controller.view == PqlView.markdown) unawaited(widget.controller.loadMarkdownFiles());
        });
  }

  @override
  void didUpdateWidget(PqlSearchBody old) {
    super.didUpdateWidget(old);
    if (old.mode != widget.mode) _applyMode();
  }

  /// Map the flat pane mode onto the controller's (view, searchMode).
  void _applyMode() {
    final c = widget.controller;
    switch (widget.mode) {
      case PqlPaneMode.vault:
        c.setSearchMode(SearchMode.search);
        c.switchView(PqlView.query);
      case PqlPaneMode.query:
        c.setSearchMode(SearchMode.dsl);
        c.switchView(PqlView.query);
      case PqlPaneMode.markdown:
        c.switchView(PqlView.markdown);
    }
  }

  @override
  void dispose() {
    _focusSub?.cancel();
    _fileSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final tokens = ClideSettings.theme.of(context).surface;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.mode == PqlPaneMode.markdown)
              ClideFilterBox(
                address: 'search.pql.markdown',
                hint: 'Filter markdown…',
                onChanged: (v) => unawaited(c.loadMarkdownFiles(glob: v.isEmpty ? null : '**/*$v*.md')),
              )
            else
              _PqlSearchInput(
                controller: c,
                dsl: widget.mode == PqlPaneMode.query,
                address: widget.mode == PqlPaneMode.query ? 'search.pql.query' : 'search.pql.vault',
              ),
            if (c.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ClideText(c.error!, color: tokens.statusError, fontSize: clideFontCaption, maxLines: 3),
              ),
            if (c.loading && c.results.isEmpty) const Padding(padding: EdgeInsets.all(12), child: ClideText('Loading…', muted: true)),
            if (!c.loading && c.results.isEmpty && c.error == null && widget.mode == PqlPaneMode.markdown)
              const Padding(padding: EdgeInsets.all(12), child: ClideText('No markdown files found.', muted: true)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.mode == PqlPaneMode.markdown)
                      for (final f in c.results)
                        _FileRow(
                          entry: f,
                          focused: (f['path'] as String?) == _focusedPath,
                          focusKey: (f['path'] as String?) == _focusedPath ? _focusedKey : null,
                        ),
                    if (widget.mode == PqlPaneMode.vault)
                      for (final r in c.results) _SearchResultRow(entry: r),
                    if (widget.mode == PqlPaneMode.query)
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

class _PqlSearchInput extends StatelessWidget {
  const _PqlSearchInput({required this.controller, required this.dsl, this.address});
  final PqlController controller;
  final bool dsl;
  final String? address;

  @override
  Widget build(BuildContext context) {
    return ClideFilterBox(
      address: address,
      hint: dsl ? 'PQL query…' : 'Search vault…',
      debounce: dsl ? Duration.zero : const Duration(milliseconds: 300),
      onChanged: dsl ? (_) {} : (v) => unawaited(controller.search(v)),
      onSubmitted: dsl ? (v) => unawaited(controller.runQuery(v)) : (v) => unawaited(controller.search(v)),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({required this.entry});
  final Map<String, Object?> entry;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
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
          decoration: BoxDecoration(color: hovered ? tokens.sidebarItemHover : null, borderRadius: BorderRadius.circular(4)),
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
        ClideText('${(score * 100).round()}%', fontSize: clideFontBadge, muted: true, fontFamily: ClideSettings.fonts.monoOf(context)),
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
    final tokens = ClideSettings.theme.of(context).surface;
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
          child: ClideText(path, maxLines: 1, overflow: TextOverflow.ellipsis, fontSize: clideFontCaption, color: tokens.sidebarForeground),
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
    final tokens = ClideSettings.theme.of(context).surface;
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
