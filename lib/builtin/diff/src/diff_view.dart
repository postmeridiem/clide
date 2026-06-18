/// Workspace tab rendering unified diffs with hunk-level
/// stage/unstage actions.
library;

import 'dart:async';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'diff_controller.dart';

class DiffView extends StatefulWidget {
  const DiffView({super.key, this.controller});

  /// When supplied, render this controller instead of creating one. The diff
  /// extension passes an app-scoped controller it retains so a `ui open diff`
  /// focus survives the tab being revealed/remounted (T-233); the view then
  /// neither owns nor disposes it. Null → self-owned, as before.
  final DiffController? controller;

  @override
  State<DiffView> createState() => _DiffViewState();
}

class _DiffViewState extends State<DiffView> {
  DiffController? _controller;
  bool _ownsController = false;
  final ScrollController _scroll = ScrollController();

  /// One key per file path in the current diff, so [focus] can scroll the
  /// matching section into view. Rebuilt lazily as paths appear.
  final Map<String, GlobalKey> _fileKeys = {};

  /// The focus we last scrolled to, so a repeat build doesn't re-scroll.
  String? _scrolledTo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final injected = widget.controller;
    if (injected != null) {
      _controller = injected;
      _ownsController = false;
    } else {
      final kernel = ClideKernel.of(context);
      _controller = DiffController(ipc: kernel.ipc, events: kernel.events);
      _ownsController = true;
      unawaited(_controller!.load());
    }
    _controller!.addListener(_onControllerChanged);
  }

  /// When the controller's focus changes, scroll that file into view after the
  /// frame it lays out in. Keeps the highlight (paint) to [build].
  void _onControllerChanged() {
    final path = _controller?.focusPath;
    if (path == null || path == _scrolledTo) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _fileKeys[path]?.currentContext;
      if (ctx == null) return; // file not in the diff (no changes) → nothing to scroll to
      _scrolledTo = path;
      unawaited(Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 200), alignment: 0.05));
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    if (_ownsController) _controller?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) return const SizedBox.shrink();
    // Forget keys for files no longer in the diff so the map can't grow without
    // bound across reloads.
    _fileKeys.removeWhere((path, _) => !c.diffs.any((d) => d['path'] == path));
    if (c.focusPath != _scrolledTo && !c.diffs.any((d) => d['path'] == c.focusPath)) {
      _scrolledTo = null; // focus left the diff; allow re-scroll if it returns
    }
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final tokens = ClideSettings.theme.of(context).surface;
        return Semantics(
          label: ClideSettings.i18n.string(context, 'view.semantics', namespace: 'builtin.diff', placeholder: 'diff view'),
          container: true,
          explicitChildNodes: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DiffToolbar(controller: c),
              if (c.error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClideText(c.error!, color: tokens.statusError),
                ),
              if (c.loading && c.diffs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClideText(ClideSettings.i18n.string(context, 'status.loading', namespace: 'builtin.diff', placeholder: 'Loading…'), muted: true),
                ),
              if (!c.loading && c.diffs.isEmpty && c.error == null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClideText(
                    c.showStaged
                        ? ClideSettings.i18n.string(context, 'empty.staged', namespace: 'builtin.diff', placeholder: 'No staged changes.')
                        : ClideSettings.i18n.string(context, 'empty.unstaged', namespace: 'builtin.diff', placeholder: 'No unstaged changes.'),
                    muted: true,
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final diff in c.diffs)
                        _FileDiff(
                          key: _fileKeys[diff['path'] as String? ?? ''] ??= GlobalKey(),
                          diff: diff,
                          controller: c,
                          focused: (diff['path'] as String?) == c.focusPath,
                        ),
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

class _DiffToolbar extends StatelessWidget {
  const _DiffToolbar({required this.controller});
  final DiffController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.panelBorder)),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            toggled: !controller.showStaged,
            label: ClideSettings.i18n.string(context, 'toolbar.unstaged.semantics', namespace: 'builtin.diff', placeholder: 'show unstaged changes'),
            child: GestureDetector(
              onTap: controller.showStaged ? controller.toggleStaged : null,
              child: ClideText(
                ClideSettings.i18n.string(context, 'toolbar.unstaged', namespace: 'builtin.diff', placeholder: 'Unstaged'),
                fontSize: clideFontCaption,
                color: controller.showStaged ? tokens.globalTextMuted : tokens.globalForeground,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            toggled: controller.showStaged,
            label: ClideSettings.i18n.string(context, 'toolbar.staged.semantics', namespace: 'builtin.diff', placeholder: 'show staged changes'),
            child: GestureDetector(
              onTap: controller.showStaged ? null : controller.toggleStaged,
              child: ClideText(
                ClideSettings.i18n.string(context, 'toolbar.staged', namespace: 'builtin.diff', placeholder: 'Staged'),
                fontSize: clideFontCaption,
                color: controller.showStaged ? tokens.globalForeground : tokens.globalTextMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileDiff extends StatelessWidget {
  const _FileDiff({super.key, required this.diff, required this.controller, this.focused = false});
  final Map<String, Object?> diff;
  final DiffController controller;

  /// This file is the current focus target (T-233) — its header gets a focus
  /// accent so the eye lands on it after the scroll.
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final path = diff['path'] as String? ?? '';
    final isBinary = diff['binary'] as bool? ?? false;
    final isNew = diff['new'] as bool? ?? false;
    final isDeleted = diff['deleted'] as bool? ?? false;
    final isRenamed = diff['renamed'] as bool? ?? false;
    final additions = (diff['additions'] as num?)?.toInt() ?? 0;
    final removals = (diff['removals'] as num?)?.toInt() ?? 0;
    final hunks = (diff['hunks'] as List?) ?? const [];

    final meta = <String>[];
    if (isNew) meta.add(ClideSettings.i18n.string(context, 'meta.newFile', namespace: 'builtin.diff', placeholder: 'new file'));
    if (isDeleted) meta.add(ClideSettings.i18n.string(context, 'meta.deleted', namespace: 'builtin.diff', placeholder: 'deleted'));
    if (isRenamed) {
      final oldPath = diff['oldPath'] as String?;
      if (oldPath != null) {
        meta.add(
          ClideSettings.i18n.interpolated(
            context,
            'meta.renamedFrom',
            namespace: 'builtin.diff',
            placeholder: 'renamed from {path}',
            replacers: [I18nReplacer(from: '{path}', replace: oldPath)],
          ),
        );
      }
    }
    if (isBinary) meta.add(ClideSettings.i18n.string(context, 'meta.binary', namespace: 'builtin.diff', placeholder: 'binary'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: tokens.panelHeader,
            border: focused ? Border(left: BorderSide(color: tokens.globalFocus, width: 2)) : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: ClideText(path, fontSize: clideFontCaption, color: focused ? tokens.globalFocus : tokens.panelHeaderForeground),
              ),
              if (additions > 0) ClideText('+$additions ', fontSize: clideFontCaption, color: tokens.statusSuccess),
              if (removals > 0) ClideText('-$removals', fontSize: clideFontCaption, color: tokens.statusError),
            ],
          ),
        ),
        if (meta.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: ClideText(meta.join(' · '), fontSize: clideFontCaption, muted: true),
          ),
        if (!isBinary)
          for (final hunk in hunks) _HunkView(hunk: (hunk as Map).cast<String, Object?>(), filePath: path, controller: controller),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _HunkView extends StatelessWidget {
  const _HunkView({required this.hunk, required this.filePath, required this.controller});

  final Map<String, Object?> hunk;
  final String filePath;
  final DiffController controller;

  @override
  Widget build(BuildContext context) {
    final header = hunk['header'] as String? ?? '';
    final lines = (hunk['lines'] as List?) ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: ClideText(header, fontSize: clideFontMono, muted: true, fontFamily: ClideSettings.fonts.monoOf(context)),
        ),
        for (final lineObj in lines) _DiffLineRow(line: (lineObj as Map).cast<String, Object?>()),
      ],
    );
  }
}

class _DiffLineRow extends StatelessWidget {
  const _DiffLineRow({required this.line});
  final Map<String, Object?> line;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final kind = line['kind'] as String? ?? 'context';
    final text = line['text'] as String? ?? '';
    final oldLineNo = line['oldLineNo'] as num?;
    final newLineNo = line['newLineNo'] as num?;

    final (Color bg, Color fg) = switch (kind) {
      'addition' => (tokens.statusSuccess.withValues(alpha: 0.15), tokens.statusSuccess),
      'removal' => (tokens.statusError.withValues(alpha: 0.15), tokens.statusError),
      _ => (const Color(0x00000000), tokens.globalForeground),
    };

    final prefix = switch (kind) {
      'addition' => '+',
      'removal' => '-',
      'header' => '',
      _ => ' ',
    };

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: ClideText(
              oldLineNo != null ? '${oldLineNo.toInt()}' : '',
              fontSize: clideFontMono,
              muted: true,
              fontFamily: ClideSettings.fonts.monoOf(context),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 2),
          SizedBox(
            width: 36,
            child: ClideText(
              newLineNo != null ? '${newLineNo.toInt()}' : '',
              fontSize: clideFontMono,
              muted: true,
              fontFamily: ClideSettings.fonts.monoOf(context),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 4),
          ClideText(prefix, fontSize: clideFontMono, color: fg, fontFamily: ClideSettings.fonts.monoOf(context)),
          const SizedBox(width: 2),
          Expanded(
            child: ClideText(
              text,
              fontSize: clideFontMono,
              color: fg,
              fontFamily: ClideSettings.fonts.monoOf(context),
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ),
        ],
      ),
    );
  }
}
