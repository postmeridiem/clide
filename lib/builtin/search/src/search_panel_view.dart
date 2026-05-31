/// The find-in-files sidebar panel (T-52, per D-79). A search input
/// with regex/case toggles + include/exclude glob fields, and a results
/// list grouped by file. Clicking a match opens the editor at its line.
library;

import 'package:clide/builtin/search/src/find_in_files_controller.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/search/match.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class SearchPanelView extends StatefulWidget {
  const SearchPanelView({super.key});

  @override
  State<SearchPanelView> createState() => _SearchPanelViewState();
}

class _SearchPanelViewState extends State<SearchPanelView> {
  FindInFilesController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final kernel = ClideKernel.of(context);
    _controller = FindInFilesController(ipc: kernel.ipc, events: kernel.events);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final c = _controller!;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final groups = c.grouped();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClideFilterBox(hint: 'Search', onChanged: c.run, onSubmitted: c.run),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Toggle(
                        label: '.*',
                        tooltip: 'Regular expression',
                        active: c.regex,
                        tokens: tokens,
                        onTap: () {
                          c.setRegex(!c.regex);
                          c.run(c.pattern);
                        },
                      ),
                      const SizedBox(width: 6),
                      _Toggle(
                        label: 'Aa',
                        tooltip: 'Case insensitive',
                        active: c.ignoreCase,
                        tokens: tokens,
                        onTap: () {
                          c.setIgnoreCase(!c.ignoreCase);
                          c.run(c.pattern);
                        },
                      ),
                      const Spacer(),
                      _StatusText(c, tokens),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClideFilterBox(hint: 'files to include (e.g. *.dart)', debounce: Duration.zero, onChanged: (v) => c.include = v),
                  const SizedBox(height: 4),
                  ClideFilterBox(hint: 'files to exclude', debounce: Duration.zero, onChanged: (v) => c.exclude = v),
                ],
              ),
            ),
            if (c.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ClideText(c.error!, color: tokens.globalTextMuted, fontSize: clideFontCaption),
              ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final entry in groups.entries) _FileGroup(path: entry.key, matches: entry.value, tokens: tokens, onTap: c.openMatch),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.tooltip,
    required this.active,
    required this.tokens,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final bool active;
  final SurfaceTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      toggled: active,
      child: ClideTappable(
        onTap: onTap,
        builder: (context, hovered, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: active ? tokens.listItemSelectedBackground : (hovered ? tokens.sidebarItemHover : null),
            border: Border.all(color: active ? tokens.globalFocus : tokens.buttonBorder),
            borderRadius: BorderRadius.circular(3),
          ),
          child: ClideText(
            label,
            fontFamily: clideMonoFamily,
            fontSize: clideFontCaption,
            color: active ? tokens.listItemSelectedForeground : tokens.sidebarForeground,
          ),
        ),
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText(this.c, this.tokens);
  final FindInFilesController c;
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    final String text;
    if (c.running) {
      text = 'Searching…';
    } else if (c.matchCount == 0 && c.done) {
      text = 'No results';
    } else if (c.matchCount > 0) {
      text = '${c.matchCount} in ${c.fileCount}';
    } else {
      text = '';
    }
    return ClideText(text, color: tokens.globalTextMuted, fontSize: clideFontCaption);
  }
}

class _FileGroup extends StatelessWidget {
  const _FileGroup({required this.path, required this.matches, required this.tokens, required this.onTap});

  final String path;
  final List<SearchMatch> matches;
  final SurfaceTokens tokens;
  final void Function(SearchMatch) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: tokens.panelHeader,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: ClideText(path, maxLines: 1, overflow: TextOverflow.ellipsis, color: tokens.panelHeaderForeground),
              ),
              ClideText('${matches.length}', fontSize: clideFontCaption, color: tokens.globalTextMuted),
            ],
          ),
        ),
        for (final m in matches) _MatchRow(match: m, tokens: tokens, onTap: () => onTap(m)),
      ],
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.match, required this.tokens, required this.onTap});

  final SearchMatch match;
  final SurfaceTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open ${match.path} line ${match.line}',
      onTap: onTap,
      child: ClideTappable(
        onTap: onTap,
        builder: (context, hovered, _) => Container(
          color: hovered ? tokens.listItemHoverBackground : null,
          padding: const EdgeInsets.only(left: 18, right: 8, top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 36,
                child: ClideText('${match.line}', fontSize: clideFontCaption, fontFamily: clideMonoFamily, color: tokens.globalTextMuted),
              ),
              Expanded(child: _highlighted()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _highlighted() {
    final line = match.preview;
    final start = match.matchStart.clamp(0, line.length);
    final end = match.matchEnd.clamp(start, line.length);
    final base = TextStyle(fontFamily: clideMonoFamily, fontSize: clideFontCaption, color: tokens.sidebarForeground);
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: base, children: [
        TextSpan(text: line.substring(0, start)),
        TextSpan(text: line.substring(start, end), style: base.copyWith(color: tokens.globalFocus, fontWeight: FontWeight.bold)),
        TextSpan(text: line.substring(end)),
      ]),
    );
  }
}
