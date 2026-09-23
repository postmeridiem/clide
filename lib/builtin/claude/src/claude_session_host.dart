import 'dart:async';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/update/self_update.dart' show startedByRelaunch;
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'claude_pane.dart';
import 'session_orchestrator.dart';
import 'session_restore.dart';

/// Hosts the primary Claude pane plus N user-spawned secondary
/// sessions per D-41. Uses [MultitabPane] for the tab strip
/// (drag-reorder, close ×, + button) and [IndexedStack]-mode
/// keep-alive so switching tabs doesn't tear down the underlying
/// PTY-backed terminal.
///
/// The secondary tabs are remembered per workspace as they change and come
/// back after a restart (T-589, D-114): automatically when an update restarted
/// the window, on the user's say-so otherwise.
class ClaudeSessionHost extends StatefulWidget {
  const ClaudeSessionHost({super.key, this.transcriptExists});

  /// Whether a session's transcript is on disk — faked by tests, which must
  /// not touch `~/.claude`.
  @visibleForTesting
  final bool Function(String root, String id)? transcriptExists;

  @override
  State<ClaudeSessionHost> createState() => ClaudeSessionHostState();
}

class ClaudeSessionHostState extends State<ClaudeSessionHost> {
  static const _primaryId = 'primary';

  late final MultitabController<_Session> _controller;
  int _nextSecondary = 1;

  StreamSubscription<ProjectOpened>? _projectSub;
  String? _projectRoot;

  SecondarySessionStore? _store;
  ClaudeSessionOrchestrator? _orch;

  /// The secondary session ids last seen in the tabs — writes happen only when
  /// this changes, so a restart's lone primary never overwrites what is
  /// remembered before the user has answered the restore offer.
  List<String> _seen = const [];

  /// Remembered sessions offered back, awaiting Restore / Not now.
  List<String> _offered = const [];

  /// Whether this process's first workspace has been offered its sessions:
  /// only that one comes back unasked after an update restart.
  bool _firstOffer = true;

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
    )..addListener(_onTabsChanged);
    _syncActiveSession();
  }

  /// Tell the orchestrator which tab the user is in, so `clide image show` and
  /// friends land there rather than always in primary (T-295). Tab ids double
  /// as orchestrator ids (`primary`, `secondary-N`), so no mapping is needed.
  void _syncActiveSession() => activeSessionOrchestrator?.activeSessionId = _controller.activeId;

  void _onTabsChanged() {
    _syncActiveSession();
    _remember();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final kernel = ClideKernel.of(context);
    _store ??= SecondarySessionStore(kernel.settings, transcriptExists: widget.transcriptExists);
    if (_orch == null && activeSessionOrchestrator != null) {
      // A fork's real session id arrives after spawn, and /clear or /resume
      // rebinds a tab to another one: both surface as orchestrator changes.
      _orch = activeSessionOrchestrator?..addListener(_remember);
    }
    if (_projectSub == null) {
      _projectSub = kernel.events.on<ProjectOpened>().listen(_onProjectChanged);
      // The startup project opens before this widget exists — its
      // ProjectOpened has already gone by.
      final current = kernel.project.current?.path;
      if (current != null) {
        _projectRoot = current;
        _offerRestore(current, building: true);
      }
    }
  }

  /// Reset to a lone primary tab when the workspace is switched in place
  /// (T-269): the old repo's secondaries/forks don't belong in the new
  /// workspace. Removing them disposes their panes, which close their sessions
  /// through the orchestrator. The primary tab stays and rebinds itself. The
  /// new workspace's remembered sessions are then offered back.
  void _onProjectChanged(ProjectOpened e) {
    final prev = _projectRoot;
    _projectRoot = e.path;
    if (!mounted || prev == e.path) return;
    if (prev == null) {
      _offerRestore(e.path);
      return;
    }
    final stale = _controller.entries.where((x) => x.id != _primaryId).map((x) => x.id).toList();
    // Not a user closing tabs: keep the old workspace's list as it was.
    _seen = const [];
    setState(() {
      for (final id in stale) {
        _controller.remove(id);
      }
      _nextSecondary = 1;
      _offered = const [];
    });
    _offerRestore(e.path);
  }

  /// Offer [root]'s remembered secondary sessions back — or, in the window
  /// an update just restarted, bring them straight back.
  ///
  /// [building]: called from [didChangeDependencies], where the coming build
  /// picks the state up without a setState.
  void _offerRestore(String root, {bool building = false}) {
    final ids = _store?.restorable(root) ?? const [];
    final auto = _firstOffer && startedByRelaunch;
    _firstOffer = false;
    if (ids.isEmpty) return;
    if (auto) {
      restoreSessions(ids);
    } else if (building) {
      _offered = ids;
    } else {
      setState(() => _offered = ids);
    }
  }

  /// The secondary session ids in tab order: the live session's id once it
  /// has spawned (a fork's resolved id, a /resume target), the id the tab
  /// was restored with until then.
  List<String> _currentIds() => [
    for (final e in _controller.entries)
      if (!e.payload.isPrimary) ?(_orch?.byId(e.id)?.sessionId ?? e.payload.resumeSessionId),
  ];

  void _remember() {
    final root = _projectRoot;
    final store = _store;
    if (root == null || store == null) return;
    final ids = _currentIds();
    if (_listEquals(ids, _seen)) return;
    _seen = ids;
    unawaited(store.save(root, ids));
  }

  @override
  void dispose() {
    _projectSub?.cancel();
    _orch?.removeListener(_remember);
    _controller.dispose();
    super.dispose();
  }

  /// Ids of the open tabs, oldest-first. Exposed for tests that assert the
  /// host resets to a lone primary on an in-place workspace switch (T-269).
  @visibleForTesting
  List<String> get tabIds => _controller.entries.map((e) => e.id).toList();

  /// The remembered sessions currently offered back, if any.
  List<String> get offeredSessions => _offered;

  /// Public entry point used by the `claude.new-secondary` command.
  void addSecondary() {
    final index = _nextSecondary++;
    _controller.add(
      MultitabEntry<_Session>(
        id: 'secondary-$index',
        title: 'session $index',
        payload: _Session(isPrimary: false, secondaryIndex: index),
      ),
    );
  }

  /// Open a new pane as a fork of [sourceClaudeSessionId] (T-172).
  ///
  /// The fork pane is a secondary tab seeded with `--resume <source>
  /// --fork-session` so the branch diverges into its own claude session
  /// without touching the original.
  void addFork(String sourceClaudeSessionId) {
    final index = _nextSecondary++;
    _controller.add(
      MultitabEntry<_Session>(
        id: 'secondary-$index',
        title: 'fork $index',
        payload: _Session(isPrimary: false, secondaryIndex: index, forkSourceId: sourceClaudeSessionId),
      ),
    );
  }

  /// Reopen [ids] — or the sessions on offer — as secondary tabs, each
  /// resuming its own conversation, in their old order, the primary staying
  /// in front. Returns how many came back (`claude.restore`, D-6).
  int restoreSessions([List<String>? ids]) {
    final open = _currentIds().toSet();
    final wanted = [
      for (final id in ids ?? _offered)
        if (!open.contains(id)) id,
    ];
    for (final id in wanted) {
      final index = _nextSecondary++;
      _controller.add(
        MultitabEntry<_Session>(
          id: 'secondary-$index',
          title: 'session $index',
          payload: _Session(isPrimary: false, secondaryIndex: index, resumeSessionId: id),
        ),
        activate: false,
      );
    }
    if (_offered.isNotEmpty) {
      if (mounted) {
        setState(() => _offered = const []);
      } else {
        _offered = const [];
      }
    }
    return wanted.length;
  }

  /// "Not now": the offer goes away; what's remembered stays until the tabs
  /// next change.
  void dismissRestore() => setState(() => _offered = const []);

  @override
  Widget build(BuildContext context) {
    final pane = MultitabPane<_Session>(
      controller: _controller,
      keepAlive: true,
      onAddRequested: addSecondary,
      bodyBuilder: (ctx, entry) {
        final s = entry.payload;
        return ClaudePane(
          isPrimary: s.isPrimary,
          secondaryIndex: s.secondaryIndex,
          forkSourceId: s.forkSourceId,
          resumeSessionId: s.resumeSessionId,
          onFork: addFork,
          // The MultitabPane already provides the tab strip header;
          // suppressing the ClaudePane's own chrome avoids a double row.
          showChrome: false,
          // Only the visible sub-tab publishes to the status-bar slot.
          active: entry.id == _controller.activeId,
        );
      },
    );
    if (_offered.isEmpty) return pane;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RestoreOffer(count: _offered.length, onRestore: restoreSessions, onDismiss: dismissRestore),
        Expanded(child: pane),
      ],
    );
  }
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// "Restore N Claude sessions from last time?" — a strip above the tabs, not
/// a conversation item (D-78): it is about the tabs, not any one session.
class _RestoreOffer extends StatelessWidget {
  const _RestoreOffer({required this.count, required this.onRestore, required this.onDismiss});
  final int count;
  final VoidCallback onRestore;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    String t(String key, String fallback) => ClideSettings.i18n.string(context, key, namespace: 'builtin.claude', placeholder: fallback);
    return Container(
      key: const Key('claude-restore-offer'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.panelBackground,
        border: Border(bottom: BorderSide(color: tokens.globalBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ClideText(
              count == 1
                  ? t('restore.offer.one', 'Restore the Claude session from last time?')
                  : ClideSettings.i18n.interpolated(
                      context,
                      'restore.offer',
                      namespace: 'builtin.claude',
                      placeholder: 'Restore {count} Claude sessions from last time?',
                      replacers: [I18nReplacer(from: '{count}', replace: '$count')],
                    ),
              fontSize: clideFontSmall,
            ),
          ),
          const SizedBox(width: 8),
          ClideButton(key: const Key('claude-restore-yes'), label: t('restore.yes', 'Restore'), variant: ClideButtonVariant.primary, onPressed: onRestore),
          const SizedBox(width: 6),
          ClideButton(key: const Key('claude-restore-no'), label: t('restore.no', 'Not now'), variant: ClideButtonVariant.subtle, onPressed: onDismiss),
        ],
      ),
    );
  }
}

class _Session {
  const _Session({required this.isPrimary, this.secondaryIndex, this.forkSourceId, this.resumeSessionId});
  final bool isPrimary;
  final int? secondaryIndex;

  /// When non-null, spawn this pane as a fork of the given claude session id
  /// (T-172). Forwarded to [ClaudePane.forkSourceId].
  final String? forkSourceId;

  /// When non-null, this tab was restored: it resumes that claude session
  /// (T-589). Forwarded to [ClaudePane.resumeSessionId].
  final String? resumeSessionId;
}
