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
      await dialog.show<Object>(
        (ctx, dismiss) => _MessageDialog(
          title: ClideSettings.i18n.string(ctx, 'dialog.dirty.title', namespace: 'builtin.search', placeholder: 'Working tree not clean'),
          body: ClideSettings.i18n.string(
            ctx,
            'dialog.dirty.body',
            namespace: 'builtin.search',
            placeholder: 'Commit or stash your changes before replacing — git is the only undo.',
          ),
          dismiss: dismiss,
        ),
      );
      return;
    }
    final confirmed = await dialog.show<bool>(
      (ctx, dismiss) => _ConfirmDialog(
        body: ClideSettings.i18n.interpolated(
          ctx,
          'dialog.confirm.body',
          namespace: 'builtin.search',
          placeholder: 'Replace {matches} match(es) across {files} file(s)? This cannot be undone in clide.',
          replacers: [
            I18nReplacer(from: '{matches}', replace: '${c.matchCount}'),
            I18nReplacer(from: '{files}', replace: '${c.fileCount}'),
          ],
        ),
        dismiss: dismiss,
      ),
    );
    if (confirmed != true) return;
    await c.applyReplace();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
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
    final tokens = ClideSettings.theme.of(context).surface;
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
                  ClideFilterBox(
                    address: 'search.findInFiles',
                    hint: ClideSettings.i18n.string(context, 'find.hint', namespace: 'builtin.search', placeholder: 'Search'),
                    onChanged: c.run,
                    onSubmitted: c.run,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Toggle(
                        label: '.*',
                        tooltip: ClideSettings.i18n.string(context, 'toggle.regex', namespace: 'builtin.search', placeholder: 'Regular expression'),
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
                        tooltip: ClideSettings.i18n.string(context, 'toggle.caseInsensitive', namespace: 'builtin.search', placeholder: 'Case insensitive'),
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
                      Expanded(
                        child: ClideFilterBox(
                          address: 'search.findInFiles.replace',
                          hint: ClideSettings.i18n.string(context, 'replace.hint', namespace: 'builtin.search', placeholder: 'Replace'),
                          icon: null,
                          debounce: Duration.zero,
                          onChanged: c.setReplacement,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _ReplaceAllButton(enabled: c.replacement.isNotEmpty && c.matchCount > 0, tokens: tokens, onTap: _replaceAll),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClideFilterBox(
                    address: 'search.findInFiles.include',
                    hint: ClideSettings.i18n.string(context, 'include.hint', namespace: 'builtin.search', placeholder: 'files to include (e.g. *.dart)'),
                    icon: null,
                    debounce: Duration.zero,
                    onChanged: (v) => c.include = v,
                  ),
                  const SizedBox(height: 4),
                  ClideFilterBox(
                    address: 'search.findInFiles.exclude',
                    hint: ClideSettings.i18n.string(context, 'exclude.hint', namespace: 'builtin.search', placeholder: 'files to exclude'),
                    icon: null,
                    debounce: Duration.zero,
                    onChanged: (v) => c.exclude = v,
                  ),
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
                    _FileGroup(path: entry.key, matches: entry.value, tokens: tokens, onTap: c.openMatch, query: c.query, replacement: c.replacement),
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

  // (catalog key, English label) per mode. The key/English pair resolves
  // through the i18n catalog at render (D-21).
  static const _labels = {
    SearchTabMode.find: ('mode.find', 'Find'),
    SearchTabMode.vault: ('mode.vault', 'Vault'),
    SearchTabMode.query: ('mode.query', 'Query'),
    SearchTabMode.markdown: ('mode.markdown', 'Markdown'),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.panelBorder)),
      ),
      child: Row(
        children: [
          for (final m in SearchTabMode.values) ...[_modeButton(context, m), const SizedBox(width: 10)],
        ],
      ),
    );
  }

  Widget _modeButton(BuildContext context, SearchTabMode m) {
    final label = ClideSettings.i18n.string(context, _labels[m]!.$1, namespace: 'builtin.search', placeholder: _labels[m]!.$2);
    return Semantics(
      button: true,
      selected: m == mode,
      label: label,
      child: ClideTappable(
        onTap: () => onSelect(m),
        builder: (ctx, hovered, _) => ClideText(
          label,
          fontSize: clideFontCaption,
          color: m == mode ? tokens.globalForeground : (hovered ? tokens.sidebarForeground : tokens.globalTextMuted),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.tooltip, required this.active, required this.tokens, required this.onTap});

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
            fontFamily: ClideSettings.fonts.monoOf(context),
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
      text = ClideSettings.i18n.string(context, 'status.searching', namespace: 'builtin.search', placeholder: 'Searching…');
    } else if (c.matchCount == 0 && c.done) {
      text = ClideSettings.i18n.string(context, 'status.noResults', namespace: 'builtin.search', placeholder: 'No results');
    } else if (c.matchCount > 0) {
      text = ClideSettings.i18n.interpolated(
        context,
        'status.counts',
        namespace: 'builtin.search',
        placeholder: '{matches} in {files}',
        replacers: [
          I18nReplacer(from: '{matches}', replace: '${c.matchCount}'),
          I18nReplacer(from: '{files}', replace: '${c.fileCount}'),
        ],
      );
    } else {
      text = '';
    }
    return ClideText(text, color: tokens.globalTextMuted, fontSize: clideFontCaption);
  }
}

class _FileGroup extends StatelessWidget {
  const _FileGroup({required this.path, required this.matches, required this.tokens, required this.onTap, required this.query, required this.replacement});

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
  const _MatchRow({required this.match, required this.tokens, required this.onTap, required this.query, required this.replacement});

  final SearchMatch match;
  final SurfaceTokens tokens;
  final VoidCallback onTap;
  final SearchQuery query;
  final String replacement;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: ClideSettings.i18n.interpolated(
        context,
        'a11y.openMatch',
        namespace: 'builtin.search',
        placeholder: 'Open {path} line {line}',
        replacers: [
          I18nReplacer(from: '{path}', replace: match.path),
          I18nReplacer(from: '{line}', replace: '${match.line}'),
        ],
      ),
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
                child: ClideText('${match.line}', fontSize: clideFontCaption, fontFamily: ClideSettings.fonts.monoOf(context), color: tokens.globalTextMuted),
              ),
              Expanded(child: replacement.isEmpty ? _highlighted(ClideSettings.fonts.monoOf(context)) : _preview(ClideSettings.fonts.monoOf(context))),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _base(String mono) => TextStyle(fontFamily: mono, fontSize: clideFontCaption, color: tokens.sidebarForeground);

  Widget _highlighted(String mono) {
    final line = match.preview;
    final start = match.matchStart.clamp(0, line.length);
    final end = match.matchEnd.clamp(start, line.length);
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: _base(mono),
        children: [
          TextSpan(text: line.substring(0, start)),
          TextSpan(
            text: line.substring(start, end),
            style: _base(mono).copyWith(color: tokens.globalFocus, fontWeight: FontWeight.bold),
          ),
          TextSpan(text: line.substring(end)),
        ],
      ),
    );
  }

  /// Replace-preview: the original line struck through, then the
  /// rewritten line (computed with the same engine the apply uses).
  Widget _preview(String mono) {
    final after = applyToText(match.preview, query, replacement).text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            text: match.preview,
            style: _base(mono).copyWith(decoration: TextDecoration.lineThrough, color: tokens.globalTextMuted),
          ),
        ),
        RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            text: after,
            style: _base(mono).copyWith(color: tokens.globalFocus),
          ),
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
    final label = ClideSettings.i18n.string(context, 'button.replaceAll', namespace: 'builtin.search', placeholder: 'Replace all');
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ClideTappable(
        onTap: enabled ? onTap : () {},
        builder: (context, hovered, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: enabled && hovered ? tokens.listItemHoverBackground : null,
            border: Border.all(color: tokens.buttonBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClideText(label, fontSize: clideFontCaption, color: enabled ? tokens.sidebarForeground : tokens.globalTextMuted),
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
    final tokens = ClideSettings.theme.of(context).surface;
    return _DialogFrame(
      tokens: tokens,
      children: [
        ClideText(title, color: tokens.dropdownForeground),
        const SizedBox(height: 8),
        ClideText(body, fontSize: clideFontCaption, color: tokens.globalTextMuted),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: _DialogButton(
            label: ClideSettings.i18n.string(context, 'button.ok', namespace: 'builtin.search', placeholder: 'OK'),
            tokens: tokens,
            onTap: () => dismiss(),
          ),
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
    final tokens = ClideSettings.theme.of(context).surface;
    return _DialogFrame(
      tokens: tokens,
      children: [
        ClideText(body, color: tokens.dropdownForeground),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _DialogButton(
              label: ClideSettings.i18n.string(context, 'button.cancel', namespace: 'builtin.search', placeholder: 'Cancel'),
              tokens: tokens,
              onTap: () => dismiss(false),
            ),
            const SizedBox(width: 8),
            _DialogButton(
              label: ClideSettings.i18n.string(context, 'button.confirm', namespace: 'builtin.search', placeholder: 'Confirm'),
              tokens: tokens,
              onTap: () => dismiss(true),
            ),
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
