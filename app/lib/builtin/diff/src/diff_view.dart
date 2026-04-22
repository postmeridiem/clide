/// Workspace tab rendering unified diffs with hunk-level
/// stage/unstage actions.
library;

import 'dart:async';

import 'package:clide_app/kernel/kernel.dart';
import 'package:clide_app/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'diff_controller.dart';

class DiffView extends StatefulWidget {
  const DiffView({super.key});

  @override
  State<DiffView> createState() => _DiffViewState();
}

class _DiffViewState extends State<DiffView> {
  DiffController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final kernel = ClideKernel.of(context);
    _controller = DiffController(ipc: kernel.ipc, events: kernel.events);
    unawaited(_controller!.load());
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
          label: 'diff view',
          container: true,
          explicitChildNodes: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DiffToolbar(controller: c),
              if (c.error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClideText(
                    c.error!,
                    color: tokens.statusError,
                    fontSize: 12,
                  ),
                ),
              if (c.loading && c.diffs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: ClideText('Loading…', muted: true, fontSize: 12),
                ),
              if (!c.loading && c.diffs.isEmpty && c.error == null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClideText(
                    c.showStaged
                        ? 'No staged changes.'
                        : 'No unstaged changes.',
                    muted: true,
                    fontSize: 12,
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final diff in c.diffs)
                        _FileDiff(diff: diff, controller: c),
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
    final tokens = ClideTheme.of(context).surface;
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
            label: 'show unstaged changes',
            child: GestureDetector(
              onTap: controller.showStaged ? controller.toggleStaged : null,
              child: ClideText(
                'Unstaged',
                fontSize: 12,
                color: controller.showStaged
                    ? tokens.globalTextMuted
                    : tokens.globalForeground,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            toggled: controller.showStaged,
            label: 'show staged changes',
            child: GestureDetector(
              onTap: controller.showStaged ? null : controller.toggleStaged,
              child: ClideText(
                'Staged',
                fontSize: 12,
                color: controller.showStaged
                    ? tokens.globalForeground
                    : tokens.globalTextMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileDiff extends StatelessWidget {
  const _FileDiff({required this.diff, required this.controller});
  final Map<String, Object?> diff;
  final DiffController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final path = diff['path'] as String? ?? '';
    final isBinary = diff['binary'] as bool? ?? false;
    final isNew = diff['new'] as bool? ?? false;
    final isDeleted = diff['deleted'] as bool? ?? false;
    final isRenamed = diff['renamed'] as bool? ?? false;
    final additions = (diff['additions'] as num?)?.toInt() ?? 0;
    final removals = (diff['removals'] as num?)?.toInt() ?? 0;
    final hunks = (diff['hunks'] as List?) ?? const [];

    final meta = <String>[];
    if (isNew) meta.add('new file');
    if (isDeleted) meta.add('deleted');
    if (isRenamed) {
      final oldPath = diff['oldPath'] as String?;
      if (oldPath != null) meta.add('renamed from $oldPath');
    }
    if (isBinary) meta.add('binary');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: tokens.panelHeader,
          child: Row(
            children: [
              Expanded(
                child: ClideText(
                  path,
                  fontSize: 12,
                  color: tokens.panelHeaderForeground,
                ),
              ),
              if (additions > 0)
                ClideText('+$additions ', fontSize: 11,
                    color: tokens.statusSuccess),
              if (removals > 0)
                ClideText('-$removals', fontSize: 11,
                    color: tokens.statusError),
            ],
          ),
        ),
        if (meta.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: ClideText(meta.join(' · '), fontSize: 11, muted: true),
          ),
        if (!isBinary)
          for (final hunk in hunks)
            _HunkView(
              hunk: (hunk as Map).cast<String, Object?>(),
              filePath: path,
              controller: controller,
            ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _HunkView extends StatelessWidget {
  const _HunkView({
    required this.hunk,
    required this.filePath,
    required this.controller,
  });

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
          child: ClideText(
            header,
            fontSize: 11,
            muted: true,
            fontFamily: clideMonoFamily,
          ),
        ),
        for (final lineObj in lines)
          _DiffLineRow(
            line: (lineObj as Map).cast<String, Object?>(),
          ),
      ],
    );
  }
}

class _DiffLineRow extends StatelessWidget {
  const _DiffLineRow({required this.line});
  final Map<String, Object?> line;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final kind = line['kind'] as String? ?? 'context';
    final text = line['text'] as String? ?? '';
    final oldLineNo = line['oldLineNo'] as num?;
    final newLineNo = line['newLineNo'] as num?;

    final (Color bg, Color fg) = switch (kind) {
      'addition' => (
          tokens.statusSuccess.withValues(alpha: 0.15),
          tokens.statusSuccess,
        ),
      'removal' => (
          tokens.statusError.withValues(alpha: 0.15),
          tokens.statusError,
        ),
      _ => (
          const Color(0x00000000),
          tokens.globalForeground,
        ),
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
              fontSize: 11,
              muted: true,
              fontFamily: clideMonoFamily,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 2),
          SizedBox(
            width: 36,
            child: ClideText(
              newLineNo != null ? '${newLineNo.toInt()}' : '',
              fontSize: 11,
              muted: true,
              fontFamily: clideMonoFamily,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 4),
          ClideText(
            prefix,
            fontSize: 11,
            color: fg,
            fontFamily: clideMonoFamily,
          ),
          const SizedBox(width: 2),
          Expanded(
            child: ClideText(
              text,
              fontSize: 11,
              color: fg,
              fontFamily: clideMonoFamily,
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ),
        ],
      ),
    );
  }
}
