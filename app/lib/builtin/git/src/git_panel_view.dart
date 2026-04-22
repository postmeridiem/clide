/// Sidebar panel for git status — staged, unstaged, untracked,
/// conflicted file groups with stage/unstage/discard actions and an
/// inline commit message field.
library;

import 'dart:async';

import 'package:clide_app/kernel/kernel.dart';
import 'package:clide_app/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'git_controller.dart';

class GitPanelView extends StatefulWidget {
  const GitPanelView({super.key});

  @override
  State<GitPanelView> createState() => _GitPanelViewState();
}

class _GitPanelViewState extends State<GitPanelView> {
  GitController? _controller;
  final TextEditingController _commitMsg = TextEditingController();
  final FocusNode _commitFocus = FocusNode();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final kernel = ClideKernel.of(context);
    _controller = GitController(ipc: kernel.ipc, events: kernel.events);
    unawaited(_controller!.load());
  }

  @override
  void dispose() {
    _controller?.dispose();
    _commitMsg.dispose();
    _commitFocus.dispose();
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
          label: 'git panel',
          container: true,
          explicitChildNodes: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _BranchHeader(controller: c),
                if (c.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    child: ClideText(
                      c.error!,
                      color: tokens.statusError,
                      fontSize: 11,
                      maxLines: 3,
                    ),
                  ),
                if (c.loading && c.isClean)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: ClideText('Loading…', muted: true, fontSize: 12),
                  ),
                if (!c.loading && c.isClean && c.error == null)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: ClideText('Nothing to commit, working tree clean.',
                        muted: true, fontSize: 12),
                  ),
                if (c.conflicted.isNotEmpty)
                  _FileGroup(
                    label: 'Merge conflicts',
                    entries: c.conflicted,
                    actions: const [],
                  ),
                if (c.staged.isNotEmpty) ...[
                  _FileGroup(
                    label: 'Staged',
                    entries: c.staged,
                    actions: [
                      _GroupAction(
                        label: 'Unstage all',
                        onTap: () => unawaited(c.unstage(const [])),
                      ),
                    ],
                    onUnstage: (path) => unawaited(c.unstage([path])),
                  ),
                  _CommitInput(
                    commitMsg: _commitMsg,
                    commitFocus: _commitFocus,
                    controller: c,
                  ),
                ],
                if (c.unstaged.isNotEmpty)
                  _FileGroup(
                    label: 'Changes',
                    entries: c.unstaged,
                    actions: [
                      _GroupAction(
                        label: 'Stage all',
                        onTap: () => unawaited(c.stageAll()),
                      ),
                    ],
                    onStage: (path) => unawaited(c.stage([path])),
                    onDiscard: (path) => unawaited(c.discard([path])),
                  ),
                if (c.untracked.isNotEmpty)
                  _FileGroup(
                    label: 'Untracked',
                    entries: c.untracked,
                    actions: [
                      _GroupAction(
                        label: 'Stage all',
                        onTap: () {
                          final paths = [
                            for (final e in c.untracked) e['path'] as String,
                          ];
                          unawaited(c.stage(paths));
                        },
                      ),
                    ],
                    onStage: (path) => unawaited(c.stage([path])),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BranchHeader extends StatelessWidget {
  const _BranchHeader({required this.controller});
  final GitController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final branch = controller.branch ?? '(detached)';
    final parts = <String>[branch];
    if (controller.ahead > 0) parts.add('↑${controller.ahead}');
    if (controller.behind > 0) parts.add('↓${controller.behind}');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: ClideText(
              parts.join(' '),
              fontSize: 12,
              color: tokens.sidebarForeground,
            ),
          ),
          _SmallAction(
            label: 'Pull',
            semanticsLabel: 'git pull',
            onTap: () => unawaited(controller.pull()),
          ),
          const SizedBox(width: 4),
          _SmallAction(
            label: 'Push',
            semanticsLabel: 'git push',
            onTap: () => unawaited(controller.push()),
          ),
        ],
      ),
    );
  }
}

class _CommitInput extends StatelessWidget {
  const _CommitInput({
    required this.commitMsg,
    required this.commitFocus,
    required this.controller,
  });

  final TextEditingController commitMsg;
  final FocusNode commitFocus;
  final GitController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: 'commit message',
            textField: true,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: tokens.globalBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: EditableText(
                controller: commitMsg,
                focusNode: commitFocus,
                style: TextStyle(
                  fontFamily: clideUiFamily,
                  fontWeight: clideUiDefaultWeight,
                  fontSize: 12,
                  color: tokens.globalForeground,
                ),
                cursorColor: tokens.globalFocus,
                backgroundCursorColor: tokens.globalFocus,
                maxLines: 3,
                onSubmitted: (_) => _doCommit(),
                inputFormatters: const [],
              ),
            ),
          ),
          const SizedBox(height: 4),
          ClideButton(
            label: 'Commit',
            onPressed: _doCommit,
            semanticLabel: 'commit staged changes',
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ],
      ),
    );
  }

  void _doCommit() {
    final msg = commitMsg.text.trim();
    if (msg.isEmpty) return;
    unawaited(controller.commit(msg).then((hash) {
      if (hash != null) commitMsg.clear();
    }));
  }
}

class _GroupAction {
  const _GroupAction({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
}

class _FileGroup extends StatelessWidget {
  const _FileGroup({
    required this.label,
    required this.entries,
    this.actions = const [],
    this.onStage,
    this.onUnstage,
    this.onDiscard,
  });

  final String label;
  final List<Map<String, Object?>> entries;
  final List<_GroupAction> actions;
  final void Function(String path)? onStage;
  final void Function(String path)? onUnstage;
  final void Function(String path)? onDiscard;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 8, top: 8, bottom: 2),
          child: Row(
            children: [
              Expanded(
                child: ClideText(
                  '$label (${entries.length})',
                  fontSize: 11,
                  muted: true,
                  color: tokens.sidebarForeground,
                ),
              ),
              for (final a in actions) ...[
                _SmallAction(label: a.label, onTap: a.onTap),
                const SizedBox(width: 4),
              ],
            ],
          ),
        ),
        for (final entry in entries)
          _GitFileRow(
            entry: entry,
            onStage: onStage,
            onUnstage: onUnstage,
            onDiscard: onDiscard,
          ),
      ],
    );
  }
}

class _GitFileRow extends StatefulWidget {
  const _GitFileRow({
    required this.entry,
    this.onStage,
    this.onUnstage,
    this.onDiscard,
  });

  final Map<String, Object?> entry;
  final void Function(String path)? onStage;
  final void Function(String path)? onUnstage;
  final void Function(String path)? onDiscard;

  @override
  State<_GitFileRow> createState() => _GitFileRowState();
}

class _GitFileRowState extends State<_GitFileRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final path = widget.entry['path'] as String? ?? '';
    final name = path.split('/').last;
    final indexState = widget.entry['indexState'] as String?;
    final workTreeState = widget.entry['workTreeState'] as String?;
    final state = indexState ?? workTreeState ?? '';
    final stateLabel = _stateLabel(state);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final kernel = ClideKernel.of(context);
          unawaited(kernel.ipc.request('editor.open', args: {'path': path}));
        },
        child: Semantics(
          button: true,
          label: '$name $stateLabel',
          child: Container(
            color: _hover ? tokens.sidebarItemHover : null,
            padding: const EdgeInsets.only(
                left: 20, right: 8, top: 2, bottom: 2),
            child: Row(
              children: [
                ClideText(
                  _stateIndicator(state),
                  fontSize: 11,
                  color: _stateColor(state, tokens),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ClideText(
                    name,
                    fontSize: 12,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    color: tokens.sidebarForeground,
                  ),
                ),
                if (_hover) ...[
                  if (widget.onStage != null)
                    _SmallAction(
                      label: '+',
                      semanticsLabel: 'stage $name',
                      onTap: () => widget.onStage!(path),
                    ),
                  if (widget.onUnstage != null)
                    _SmallAction(
                      label: '-',
                      semanticsLabel: 'unstage $name',
                      onTap: () => widget.onUnstage!(path),
                    ),
                  if (widget.onDiscard != null)
                    _SmallAction(
                      label: 'x',
                      semanticsLabel: 'discard changes to $name',
                      onTap: () => widget.onDiscard!(path),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _stateIndicator(String state) {
    return switch (state) {
      'added' => 'A',
      'modified' => 'M',
      'deleted' => 'D',
      'renamed' => 'R',
      'copied' => 'C',
      'untracked' => '?',
      _ => ' ',
    };
  }

  static String _stateLabel(String state) {
    return switch (state) {
      'added' => 'added',
      'modified' => 'modified',
      'deleted' => 'deleted',
      'renamed' => 'renamed',
      'copied' => 'copied',
      'untracked' => 'untracked',
      _ => '',
    };
  }

  static Color _stateColor(String state, SurfaceTokens tokens) {
    return switch (state) {
      'added' || 'untracked' => tokens.statusSuccess,
      'modified' || 'renamed' || 'copied' => tokens.statusInfo,
      'deleted' => tokens.statusError,
      _ => tokens.sidebarForeground,
    };
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.label,
    required this.onTap,
    this.semanticsLabel,
  });

  final String label;
  final String? semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: ClideText(
            label,
            fontSize: 10,
            color: tokens.sidebarForeground,
          ),
        ),
      ),
    );
  }
}
