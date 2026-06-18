/// Sidebar panel for git status — staged, unstaged, untracked,
/// conflicted file groups with stage/unstage/discard actions and an
/// inline commit message field.
library;

import 'dart:async';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
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
  String _filter = '';

  List<Map<String, Object?>> _applyFilter(List<Map<String, Object?>> entries) {
    if (_filter.isEmpty) return entries;
    final lf = _filter.toLowerCase();
    return entries.where((e) => ((e['path'] as String?) ?? '').toLowerCase().contains(lf)).toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final kernel = ClideKernel.of(context);
    _controller = GitController(ipc: kernel.ipc, events: kernel.events, messages: kernel.messages);
    unawaited(_controller!.load());
  }

  @override
  void dispose() {
    _controller?.dispose();
    _commitMsg.dispose();
    _commitFocus.dispose();
    super.dispose();
  }

  void _confirmDiscard(BuildContext ctx, GitController c, String path) {
    final kernel = ClideKernel.of(ctx);
    kernel.dialog.show<String>(
      (dialogCtx, dismiss) => _DiscardConfirmDialog(
        path: path,
        onConfirm: () {
          unawaited(c.discard([path]));
          dismiss();
        },
        onCancel: () => dismiss(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final tokens = ClideSettings.theme.of(context).surface;
        return Semantics(
          label: ClideSettings.i18n.string(context, 'panel.semantics', namespace: 'builtin.git', placeholder: 'git panel'),
          container: true,
          explicitChildNodes: true,
          child: Column(
            children: [
              ClideFilterBox(
                address: 'git.panel',
                hint: ClideSettings.i18n.string(context, 'filter.hint', namespace: 'builtin.git', placeholder: 'Filter changes…'),
                onChanged: (v) => setState(() => _filter = v),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BranchHeader(controller: c),
                      if (c.error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ClideText(c.error!, color: tokens.statusError, fontSize: clideFontCaption, maxLines: 3),
                        ),
                      if (c.loading && c.isClean)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: ClideText(
                            ClideSettings.i18n.string(context, 'status.loading', namespace: 'builtin.git', placeholder: 'Loading…'),
                            muted: true,
                          ),
                        ),
                      if (!c.loading && c.isClean && c.error == null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: ClideText(
                            ClideSettings.i18n.string(context, 'status.clean', namespace: 'builtin.git', placeholder: 'Nothing to commit, working tree clean.'),
                            muted: true,
                          ),
                        ),
                      if (c.conflicted.isNotEmpty)
                        _FileGroup(
                          label: ClideSettings.i18n.string(context, 'group.conflicts', namespace: 'builtin.git', placeholder: 'Merge conflicts'),
                          entries: _applyFilter(c.conflicted),
                          actions: const [],
                        ),
                      if (c.staged.isNotEmpty) ...[
                        _FileGroup(
                          label: ClideSettings.i18n.string(context, 'group.staged', namespace: 'builtin.git', placeholder: 'Staged'),
                          entries: _applyFilter(c.staged),
                          actions: [
                            _GroupAction(
                              label: ClideSettings.i18n.string(context, 'action.unstageAll', namespace: 'builtin.git', placeholder: 'Unstage all'),
                              onTap: () => unawaited(c.unstage(const [])),
                            ),
                          ],
                          onUnstage: (path) => unawaited(c.unstage([path])),
                        ),
                        _CommitInput(commitMsg: _commitMsg, commitFocus: _commitFocus, controller: c),
                      ],
                      if (c.unstaged.isNotEmpty)
                        _FileGroup(
                          label: ClideSettings.i18n.string(context, 'group.changes', namespace: 'builtin.git', placeholder: 'Changes'),
                          entries: _applyFilter(c.unstaged),
                          actions: [
                            _GroupAction(
                              label: ClideSettings.i18n.string(context, 'action.stageAll', namespace: 'builtin.git', placeholder: 'Stage all'),
                              onTap: () => unawaited(c.stageAll()),
                            ),
                          ],
                          onStage: (path) => unawaited(c.stage([path])),
                          onDiscard: (path) => _confirmDiscard(context, c, path),
                        ),
                      if (c.untracked.isNotEmpty)
                        _FileGroup(
                          label: ClideSettings.i18n.string(context, 'group.untracked', namespace: 'builtin.git', placeholder: 'Untracked'),
                          entries: _applyFilter(c.untracked),
                          actions: [
                            _GroupAction(
                              label: ClideSettings.i18n.string(context, 'action.stageAll', namespace: 'builtin.git', placeholder: 'Stage all'),
                              onTap: () {
                                final paths = [for (final e in c.untracked) e['path'] as String];
                                unawaited(c.stage(paths));
                              },
                            ),
                          ],
                          onStage: (path) => unawaited(c.stage([path])),
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

class _BranchHeader extends StatelessWidget {
  const _BranchHeader({required this.controller});
  final GitController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final branch = controller.branch ?? ClideSettings.i18n.string(context, 'branch.detached', namespace: 'builtin.git', placeholder: '(detached)');
    final parts = <String>[branch];
    if (controller.ahead > 0) parts.add('↑${controller.ahead}');
    if (controller.behind > 0) parts.add('↓${controller.behind}');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: ClideText(parts.join(' '), fontSize: clideFontCaption, color: tokens.sidebarForeground),
          ),
          _SmallAction(
            label: ClideSettings.i18n.string(context, 'action.pull', namespace: 'builtin.git', placeholder: 'Pull'),
            semanticsLabel: ClideSettings.i18n.string(context, 'action.pull.semantics', namespace: 'builtin.git', placeholder: 'git pull'),
            onTap: () => unawaited(controller.pull()),
          ),
          const SizedBox(width: 4),
          _SmallAction(
            label: ClideSettings.i18n.string(context, 'action.push', namespace: 'builtin.git', placeholder: 'Push'),
            semanticsLabel: ClideSettings.i18n.string(context, 'action.push.semantics', namespace: 'builtin.git', placeholder: 'git push'),
            onTap: () => unawaited(controller.push()),
          ),
        ],
      ),
    );
  }
}

class _CommitInput extends StatelessWidget {
  const _CommitInput({required this.commitMsg, required this.commitFocus, required this.controller});

  final TextEditingController commitMsg;
  final FocusNode commitFocus;
  final GitController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: ClideSettings.i18n.string(context, 'commit.message.semantics', namespace: 'builtin.git', placeholder: 'commit message'),
            textField: true,
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: tokens.globalBorder)),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: EditableText(
                controller: commitMsg,
                focusNode: commitFocus,
                style: TextStyle(fontFamily: clideUiFamily, fontWeight: clideUiDefaultWeight, fontSize: clideFontCaption, color: tokens.globalForeground),
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
            label: ClideSettings.i18n.string(context, 'commit.button', namespace: 'builtin.git', placeholder: 'Commit'),
            onPressed: _doCommit,
            semanticLabel: ClideSettings.i18n.string(context, 'commit.button.semantics', namespace: 'builtin.git', placeholder: 'commit staged changes'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ],
      ),
    );
  }

  void _doCommit() {
    final msg = commitMsg.text.trim();
    if (msg.isEmpty) return;
    unawaited(
      controller.commit(msg).then((hash) {
        if (hash != null) commitMsg.clear();
      }),
    );
  }
}

class _GroupAction {
  const _GroupAction({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
}

class _FileGroup extends StatelessWidget {
  const _FileGroup({required this.label, required this.entries, this.actions = const [], this.onStage, this.onUnstage, this.onDiscard});

  final String label;
  final List<Map<String, Object?>> entries;
  final List<_GroupAction> actions;
  final void Function(String path)? onStage;
  final void Function(String path)? onUnstage;
  final void Function(String path)? onDiscard;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 8, top: 8, bottom: 2),
          child: Row(
            children: [
              Expanded(
                child: ClideText('$label (${entries.length})', fontSize: clideFontCaption, muted: true, color: tokens.sidebarForeground),
              ),
              for (final a in actions) ...[_SmallAction(label: a.label, onTap: a.onTap), const SizedBox(width: 4)],
            ],
          ),
        ),
        for (final entry in entries) _GitFileRow(entry: entry, onStage: onStage, onUnstage: onUnstage, onDiscard: onDiscard),
      ],
    );
  }
}

class _GitFileRow extends StatelessWidget {
  const _GitFileRow({required this.entry, this.onStage, this.onUnstage, this.onDiscard});

  final Map<String, Object?> entry;
  final void Function(String path)? onStage;
  final void Function(String path)? onUnstage;
  final void Function(String path)? onDiscard;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final path = entry['path'] as String? ?? '';
    final name = path.split('/').last;
    final indexState = entry['indexState'] as String?;
    final workTreeState = entry['workTreeState'] as String?;
    final state = indexState ?? workTreeState ?? '';
    final stateLabel = _stateLabel(context, state);

    return Semantics(
      button: true,
      label: '$name $stateLabel',
      child: ClideTappable(
        onTap: () {
          final kernel = ClideKernel.of(context);
          unawaited(kernel.ipc.request('editor.open', args: {'path': path}));
        },
        builder: (context, hovered, _) => Container(
          color: hovered ? tokens.sidebarItemHover : null,
          padding: const EdgeInsets.only(left: 20, right: 8, top: 2, bottom: 2),
          child: Row(
            children: [
              ClideText(_stateIndicator(state), fontSize: clideFontCaption, color: _stateColor(state, tokens)),
              const SizedBox(width: 6),
              Expanded(
                child: ClideText(name, maxLines: 1, overflow: TextOverflow.ellipsis, color: tokens.sidebarForeground),
              ),
              if (hovered) ...[
                if (onStage != null)
                  _SmallAction(
                    label: '+',
                    semanticsLabel: ClideSettings.i18n.interpolated(
                      context,
                      'row.stage.semantics',
                      namespace: 'builtin.git',
                      placeholder: 'stage {name}',
                      replacers: [I18nReplacer(from: '{name}', replace: name)],
                    ),
                    onTap: () => onStage!(path),
                  ),
                if (onUnstage != null)
                  _SmallAction(
                    label: '-',
                    semanticsLabel: ClideSettings.i18n.interpolated(
                      context,
                      'row.unstage.semantics',
                      namespace: 'builtin.git',
                      placeholder: 'unstage {name}',
                      replacers: [I18nReplacer(from: '{name}', replace: name)],
                    ),
                    onTap: () => onUnstage!(path),
                  ),
                if (onDiscard != null)
                  _SmallAction(
                    label: 'x',
                    semanticsLabel: ClideSettings.i18n.interpolated(
                      context,
                      'row.discard.semantics',
                      namespace: 'builtin.git',
                      placeholder: 'discard changes to {name}',
                      replacers: [I18nReplacer(from: '{name}', replace: name)],
                    ),
                    onTap: () => onDiscard!(path),
                  ),
              ],
            ],
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

  static String _stateLabel(BuildContext context, String state) {
    String t(String key, String english) => ClideSettings.i18n.string(context, key, namespace: 'builtin.git', placeholder: english);
    return switch (state) {
      'added' => t('state.added', 'added'),
      'modified' => t('state.modified', 'modified'),
      'deleted' => t('state.deleted', 'deleted'),
      'renamed' => t('state.renamed', 'renamed'),
      'copied' => t('state.copied', 'copied'),
      'untracked' => t('state.untracked', 'untracked'),
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
  const _SmallAction({required this.label, required this.onTap, this.semanticsLabel});

  final String label;
  final String? semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: ClideText(label, fontSize: clideFontCaption, color: tokens.sidebarForeground),
        ),
      ),
    );
  }
}

class _DiscardConfirmDialog extends StatelessWidget {
  const _DiscardConfirmDialog({required this.path, required this.onConfirm, required this.onCancel});

  final String path;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final name = path.split('/').last;
    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: tokens.modalSurfaceBackground,
        border: Border.all(color: tokens.modalSurfaceBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClideText(
            ClideSettings.i18n.string(context, 'discard.title', namespace: 'builtin.git', placeholder: 'Discard changes?'),
            color: tokens.globalForeground,
          ),
          const SizedBox(height: 8),
          ClideText(
            ClideSettings.i18n.interpolated(
              context,
              'discard.body',
              namespace: 'builtin.git',
              placeholder: 'Unstaged changes to {name} will be permanently lost.',
              replacers: [I18nReplacer(from: '{name}', replace: name)],
            ),
            fontSize: clideFontCaption,
            color: tokens.statusError,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ClideButton(
                label: ClideSettings.i18n.string(context, 'button.cancel', namespace: 'builtin.git', placeholder: 'Cancel'),
                variant: ClideButtonVariant.subtle,
                onPressed: onCancel,
              ),
              const SizedBox(width: 8),
              ClideButton(
                label: ClideSettings.i18n.string(context, 'button.discard', namespace: 'builtin.git', placeholder: 'Discard'),
                onPressed: onConfirm,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
