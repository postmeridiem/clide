import 'dart:async';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'claude_pane.dart';

/// Hosts the primary Claude pane plus N user-spawned secondary
/// sessions per D-41. Uses [MultitabPane] for the tab strip
/// (drag-reorder, close ×, + button) and [IndexedStack]-mode
/// keep-alive so switching tabs doesn't tear down the underlying
/// PTY-backed terminal.
class ClaudeSessionHost extends StatefulWidget {
  const ClaudeSessionHost({super.key});

  @override
  State<ClaudeSessionHost> createState() => ClaudeSessionHostState();
}

class ClaudeSessionHostState extends State<ClaudeSessionHost> {
  static const _primaryId = 'primary';

  late final MultitabController<_Session> _controller;
  int _nextSecondary = 1;

  StreamSubscription<ProjectOpened>? _projectSub;
  String? _projectRoot;

  @override
  void initState() {
    super.initState();
    _controller = MultitabController<_Session>(
      initial: [
        MultitabEntry<_Session>(
          id: _primaryId,
          title: 'primary',
          payload: const _Session(isPrimary: true),
          // Primary persists across clide restarts and never gets a
          // close affordance (D-41).
          closeable: false,
          reorderable: false,
        ),
      ],
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _projectSub ??= ClideKernel.of(context).events.on<ProjectOpened>().listen(_onProjectChanged);
  }

  /// Reset to a lone primary tab when the workspace is switched in place
  /// (T-269): the old repo's secondaries/forks don't belong in the new
  /// workspace. Removing them disposes their panes, which close their sessions
  /// through the orchestrator. The primary tab stays and rebinds itself.
  void _onProjectChanged(ProjectOpened e) {
    final prev = _projectRoot;
    _projectRoot = e.path;
    if (prev == null || prev == e.path) return; // initial open / no change
    if (!mounted) return;
    final stale = _controller.entries.where((x) => x.id != _primaryId).map((x) => x.id).toList();
    if (stale.isEmpty) return;
    setState(() {
      for (final id in stale) {
        _controller.remove(id);
      }
      _nextSecondary = 1;
    });
  }

  @override
  void dispose() {
    _projectSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Public entry point used by the `claude.new-secondary` command.
  void addSecondary() {
    final index = _nextSecondary++;
    _controller.add(MultitabEntry<_Session>(
      id: 'secondary-$index',
      title: 'session $index',
      payload: _Session(isPrimary: false, secondaryIndex: index),
    ));
  }

  /// Open a new pane as a fork of [sourceClaudeSessionId] (T-172).
  ///
  /// The fork pane is a secondary tab seeded with `--resume <source>
  /// --fork-session` so the branch diverges into its own claude session
  /// without touching the original.
  void addFork(String sourceClaudeSessionId) {
    final index = _nextSecondary++;
    _controller.add(MultitabEntry<_Session>(
      id: 'secondary-$index',
      title: 'fork $index',
      payload: _Session(isPrimary: false, secondaryIndex: index, forkSourceId: sourceClaudeSessionId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return MultitabPane<_Session>(
      controller: _controller,
      keepAlive: true,
      onAddRequested: addSecondary,
      bodyBuilder: (ctx, entry) {
        final s = entry.payload;
        return ClaudePane(
          isPrimary: s.isPrimary,
          secondaryIndex: s.secondaryIndex,
          forkSourceId: s.forkSourceId,
          onFork: addFork,
          // The MultitabPane already provides the tab strip header;
          // suppressing the ClaudePane's own chrome avoids a double row.
          showChrome: false,
          // Only the visible sub-tab publishes to the status-bar slot.
          active: entry.id == _controller.activeId,
        );
      },
    );
  }
}

class _Session {
  const _Session({required this.isPrimary, this.secondaryIndex, this.forkSourceId});
  final bool isPrimary;
  final int? secondaryIndex;

  /// When non-null, spawn this pane as a fork of the given claude session id
  /// (T-172). Forwarded to [ClaudePane.forkSourceId].
  final String? forkSourceId;
}
