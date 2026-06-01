/// The unified Search sidebar tab (T-52 / T-201). A mode switch selects
/// among: Find (content grep, per D-79), Vault (pql ranked search),
/// Query (PQL DSL), and Markdown (the synced markdown-file listing).
/// The find modes own a [FindInFilesController]; the pql modes a
/// [PqlController] rendered by [PqlSearchBody].
library;

import 'package:clide/builtin/pql/src/pql_controller.dart';
import 'package:clide/builtin/pql/src/pql_search_body.dart';
import 'package:clide/builtin/search/src/find_in_files_controller.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/search/match.dart';
import 'package:clide/src/search/replace_engine.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// The Search tab's top-level mode.
enum SearchTabMode { find, vault, query, markdown }

class SearchPanelView extends StatefulWidget {
  const SearchPanelView({super.key});

  @override
  State<SearchPanelView> createState() => _SearchPanelViewState();
}

class _SearchPanelViewState extends State<SearchPanelView> {
  FindInFilesController? _controller;
  PqlController? _pql;
  SearchTabMode _mode = SearchTabMode.find;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final kernel = ClideKernel.of(context);
    _controller = FindInFilesController(ipc: kernel.ipc, events: kernel.events);
    _pql = PqlController(ipc: kernel.ipc);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _pql?.dispose();
    super.dispose();
  }

  Future<void> _replaceAll() async {
    final c = _controller!;
    if (c.replacement.isEmpty || c.matchCount == 0) return;
    final dialog = ClideKernel.of(context).dialog;
    if (!await c.isWorkingTreeClean()) {
      await dialog.show<Object>((ctx, dismiss) => _MessageDialog(
            title: 'Working tree not clean',
            body: 'Commit or stash your changes before replacing — git is the only undo.',
            dismiss: dismiss,
          ));
      return;
    }
    final confirmed = await dialog.show<bool>((ctx, dismiss) => _ConfirmDialog(
          body: 'Replace ${c.matchCount} match(es) across ${c.fileCount} file(s)? This cannot be undone in clide.',
          dismiss: dismiss,
        ));
    if (confirmed != true) return;
    await c.applyReplace();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModeSwitcher(mode: _mode, tokens: tokens, onSelect: (m) => setState(() => _mode = m)),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    switch (_mode) {
      case SearchTabMode.find:
        return _findBody();
      case SearchTabMode.vault:
        return PqlSearchBody(controller: _pql!, mode: PqlPaneMode.vault);
      case SearchTabMode.query:
        return PqlSearchBody(controller: _pql!, mode: PqlPaneMode.query);
      case SearchTabMode.markdown:
        return PqlSearchBody(controller: _pql!, mode: PqlPaneMode.markdown);
    }
  }

  Widget _findBody() {
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
                  Row(
                    children: [
                      Expanded(child: ClideFilterBox(hint: 'Replace', icon: null, debounce: Duration.zero, onChanged: c.setReplacement)),
                      const SizedBox(width: 6),
                      _ReplaceAllButton(
                        enabled: c.replacement.isNotEmpty && c.matchCount > 0,
                        tokens: tokens,
                        onTap: _replaceAll,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClideFilterBox(hint: 'files to include (e.g. *.dart)', icon: null, debounce: Duration.zero, onChanged: (v) => c.include = v),
                  const SizedBox(height: 4),
                  ClideFilterBox(hint: 'files to exclude', icon: null, debounce: Duration.zero, onChanged: (v) => c.exclude = v),
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
                  for (final entry in groups.entries)
                    _FileGroup(
                      path: entry.key,
                      matches: entry.value,
                      tokens: tokens,
                      onTap: c.openMatch,
                      query: c.query,
                      replacement: c.replacement,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({required this.mode, required this.tokens, required this.onSelect});

  final SearchTabMode mode;
  final SurfaceTokens tokens;
  final ValueChanged<SearchTabMode> onSelect;

  static const _labels = {
    SearchTabMode.find: 'Find',
    SearchTabMode.vault: 'Vault',
    SearchTabMode.query: 'Query',
    SearchTabMode.markdown: 'Markdown',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.panelBorder))),
      child: Row(
        children: [
          for (final m in SearchTabMode.values) ...[
            Semantics(
              button: true,
              selected: m == mode,
              label: _labels[m]!,
              child: ClideTappable(
                onTap: () => onSelect(m),
                builder: (ctx, hovered, _) => ClideText(
                  _labels[m]!,
                  fontSize: clideFontCaption,
                  color: m == mode ? tokens.globalForeground : (hovered ? tokens.sidebarForeground : tokens.globalTextMuted),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
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
  const _FileGroup({
    required this.path,
    required this.matches,
    required this.tokens,
    required this.onTap,
    required this.query,
    required this.replacement,
  });

  final String path;
  final List<SearchMatch> matches;
  final SurfaceTokens tokens;
  final void Function(SearchMatch) onTap;
  final SearchQuery query;
  final String replacement;

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
        for (final m in matches) _MatchRow(match: m, tokens: tokens, onTap: () => onTap(m), query: query, replacement: replacement),
      ],
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({
    required this.match,
    required this.tokens,
    required this.onTap,
    required this.query,
    required this.replacement,
  });

  final SearchMatch match;
  final SurfaceTokens tokens;
  final VoidCallback onTap;
  final SearchQuery query;
  final String replacement;

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
              Expanded(child: replacement.isEmpty ? _highlighted() : _preview()),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle get _base => TextStyle(fontFamily: clideMonoFamily, fontSize: clideFontCaption, color: tokens.sidebarForeground);

  Widget _highlighted() {
    final line = match.preview;
    final start = match.matchStart.clamp(0, line.length);
    final end = match.matchEnd.clamp(start, line.length);
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: _base, children: [
        TextSpan(text: line.substring(0, start)),
        TextSpan(text: line.substring(start, end), style: _base.copyWith(color: tokens.globalFocus, fontWeight: FontWeight.bold)),
        TextSpan(text: line.substring(end)),
      ]),
    );
  }

  /// Replace-preview: the original line struck through, then the
  /// rewritten line (computed with the same engine the apply uses).
  Widget _preview() {
    final after = applyToText(match.preview, query, replacement).text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(text: match.preview, style: _base.copyWith(decoration: TextDecoration.lineThrough, color: tokens.globalTextMuted)),
        ),
        RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(text: after, style: _base.copyWith(color: tokens.globalFocus)),
        ),
      ],
    );
  }
}

class _ReplaceAllButton extends StatelessWidget {
  const _ReplaceAllButton({required this.enabled, required this.tokens, required this.onTap});

  final bool enabled;
  final SurfaceTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Replace all',
      child: ClideTappable(
        onTap: enabled ? onTap : () {},
        builder: (context, hovered, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: enabled && hovered ? tokens.listItemHoverBackground : null,
            border: Border.all(color: tokens.buttonBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClideText(
            'Replace all',
            fontSize: clideFontCaption,
            color: enabled ? tokens.sidebarForeground : tokens.globalTextMuted,
          ),
        ),
      ),
    );
  }
}

class _MessageDialog extends StatelessWidget {
  const _MessageDialog({required this.title, required this.body, required this.dismiss});

  final String title;
  final String body;
  final void Function([Object?]) dismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return _DialogFrame(
      tokens: tokens,
      children: [
        ClideText(title, color: tokens.dropdownForeground),
        const SizedBox(height: 8),
        ClideText(body, fontSize: clideFontCaption, color: tokens.globalTextMuted),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: _DialogButton(label: 'OK', tokens: tokens, onTap: () => dismiss()),
        ),
      ],
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({required this.body, required this.dismiss});

  final String body;
  final void Function([bool?]) dismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return _DialogFrame(
      tokens: tokens,
      children: [
        ClideText(body, color: tokens.dropdownForeground),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _DialogButton(label: 'Cancel', tokens: tokens, onTap: () => dismiss(false)),
            const SizedBox(width: 8),
            _DialogButton(label: 'Confirm', tokens: tokens, onTap: () => dismiss(true)),
          ],
        ),
      ],
    );
  }
}

class _DialogFrame extends StatelessWidget {
  const _DialogFrame({required this.tokens, required this.children});
  final SurfaceTokens tokens;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.dropdownBackground,
        border: Border.all(color: tokens.modalSurfaceBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({required this.label, required this.tokens, required this.onTap});
  final String label;
  final SurfaceTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ClideTappable(
        onTap: onTap,
        builder: (context, hovered, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: hovered ? tokens.listItemHoverBackground : null,
            border: Border.all(color: tokens.buttonBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClideText(label, fontSize: clideFontCaption, color: tokens.sidebarForeground),
        ),
      ),
    );
  }
}
