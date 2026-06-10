import 'dart:async';

import 'package:clide/builtin/tickets/src/pick_up_prompt.dart';
import 'package:clide/builtin/tickets/src/ticket_colors.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class TicketsView extends StatefulWidget {
  const TicketsView({super.key});

  @override
  State<TicketsView> createState() => _TicketsViewState();
}

class _TicketsViewState extends State<TicketsView> {
  List<_TicketEntry> _tickets = [];
  String? _error;
  bool _loading = true;
  String _filter = '';
  String? _focusedId;
  final _focusedKey = GlobalKey();
  final Set<String> _pinned = {'in_progress', 'ready', 'backlog'};

  /// Type-filter chips (T-343), ordered large→small. Each maps 1:1 to a pql
  /// ticket type; all on by default. An empty set never persists — toggling off
  /// the last one snaps all back on, so the list is never mysteriously blank.
  static const _allTypes = {'initiative', 'epic', 'story', 'task', 'bug'};
  static const _typeOrder = [
    ('initiative', 'Initiative'),
    ('epic', 'Epic'),
    ('story', 'Story'),
    ('task', 'Task'),
    ('bug', 'Bug'),
  ];
  final Set<String> _enabledTypes = {..._allTypes};
  StreamSubscription<Message>? _focusSub;
  StreamSubscription<SchedulerTick>? _schedulerSub;
  StreamSubscription<Message>? _changedSub;
  StreamSubscription<ProjectOpened>? _projectSub;
  bool _refreshing = false;
  bool _pendingRefresh = false;

  bool _isSectionExpanded(String status) {
    if (_pinned.contains(status)) return true;
    if (_focusedId == null) return false;
    final entry = _tickets.where((t) => t.id == _focusedId).firstOrNull;
    return _sectionForStatus(entry?.status) == status;
  }

  void _toggle(String key) {
    setState(() {
      if (_pinned.contains(key)) {
        _pinned.remove(key);
      } else {
        _pinned.add(key);
      }
    });
  }

  /// Single-click a chip: toggle that type in/out. Removing the last enabled
  /// type resets all back on (T-343).
  void _toggleType(String type) {
    setState(() {
      if (_enabledTypes.contains(type)) {
        _enabledTypes.remove(type);
        if (_enabledTypes.isEmpty) _enabledTypes.addAll(_allTypes);
      } else {
        _enabledTypes.add(type);
      }
    });
  }

  /// Double-click a chip: isolate (solo) that type — it on, all others off.
  /// Double-clicking the already-soloed chip restores all-on (chart-legend
  /// solo pattern, T-343).
  void _soloType(String type) {
    setState(() {
      final soloed = _enabledTypes.length == 1 && _enabledTypes.contains(type);
      _enabledTypes
        ..clear()
        ..addAll(soloed ? _allTypes : {type});
    });
  }

  static String _sectionForStatus(String? status) => status ?? 'backlog';

  void _onFocus(Message msg) {
    final id = msg.data['id'] as String?;
    if (id == null || id == _focusedId) return;
    _scrollToFocused(id);
  }

  void _scrollToFocused(String id) {
    setState(() => _focusedId = id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _focusedKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 200), alignment: 0.3);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_focusSub == null) {
      final kernel = ClideKernel.of(context);
      _focusSub = kernel.messages.subscribe(publisher: 'builtin.tickets', channel: 'focus').listen(_onFocus);
      _changedSub = kernel.messages.subscribe(publisher: 'builtin.tickets', channel: 'changed').listen((msg) {
        final id = msg.data['id'] as String?;
        unawaited(_refresh().then((_) {
          if (id != null && mounted) _scrollToFocused(id);
        }));
      });
      _schedulerSub = kernel.events.on<SchedulerTick>().where((e) => e.tier == SchedulerTier.oneMinute).listen((_) => _refresh());
      // The first load can fire before the project's workspace is wired into
      // the daemon (the boot workDir is the launch CWD, not the repo), so pql
      // runs against the wrong/old DB and the list errors. Re-fetch once the
      // workspace is actually open — the daemon's pql workDir is correct by
      // then (ProjectOpened fires after the IPC server swaps). (T-352)
      _projectSub = kernel.events.on<ProjectOpened>().listen((_) => _refresh());
    }
    if (!_loading || _tickets.isNotEmpty) return;
    unawaited(_load());
  }

  @override
  void dispose() {
    _focusSub?.cancel();
    _changedSub?.cancel();
    _schedulerSub?.cancel();
    _projectSub?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    if (_refreshing) {
      _pendingRefresh = true;
      return;
    }
    _refreshing = true;
    _pendingRefresh = false;
    await _load();
    _refreshing = false;
    if (_pendingRefresh && mounted) {
      _pendingRefresh = false;
      unawaited(_refresh());
    }
  }

  Future<void> _load() async {
    final kernel = ClideKernel.of(context);
    final resp = await kernel.ipc.request('pql.tickets.list');
    if (!mounted) return;
    if (!resp.ok) {
      setState(() {
        _error = resp.error?.message ?? 'failed to load tickets';
        _loading = false;
      });
      return;
    }
    final raw = resp.data['tickets'];
    if (raw is List) {
      setState(() {
        _tickets = [for (final e in raw) _TicketEntry.fromJson((e as Map).cast<String, dynamic>())];
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    if (_loading) return const Center(child: ClideText('Loading tickets...', muted: true));
    if (_error != null) return Padding(padding: const EdgeInsets.all(12), child: ClideText(_error!, muted: true));
    if (_tickets.isEmpty) return const Padding(padding: EdgeInsets.all(12), child: ClideText('No tickets.\nRun `pql ticket new` to create one.', muted: true));

    final lf = _filter.toLowerCase();
    final hasTextFilter = lf.isNotEmpty;
    // All-on = "no type filter" (so a full set never hides null-type tickets).
    final allTypesOn = _enabledTypes.length == _allTypes.length;
    final filtering = hasTextFilter || !allTypesOn;
    bool textMatch(_TicketEntry t) =>
        t.id.toLowerCase().contains(lf) || t.title.toLowerCase().contains(lf) || (t.status ?? '').contains(lf) || (t.type ?? '').contains(lf);
    bool typeMatch(_TicketEntry t) => allTypesOn || _enabledTypes.contains(t.type);
    final filtered = _tickets.where((t) => (!hasTextFilter || textMatch(t)) && typeMatch(t)).toList();

    const sections = [
      ('in_progress', 'IN PROGRESS'),
      ('review', 'REVIEW'),
      ('ready', 'READY'),
      ('backlog', 'BACKLOG'),
      ('done', 'DONE'),
      ('cancelled', 'CANCELLED'),
    ];

    final byStatus = <String, List<_TicketEntry>>{};
    for (final t in filtered) {
      (byStatus[t.status ?? 'backlog'] ??= []).add(t);
    }

    final isDark = ClideTheme.of(context).dark;
    final typeColors = TicketTypeColors.forTheme(dark: isDark);

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: ClideFilterBox(address: 'tickets.panel', hint: 'Filter tickets…', onChanged: (v) => setState(() => _filter = v))),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ClideTappable(
                onTap: _refreshing ? null : _refresh,
                tooltip: 'Refresh tickets',
                builder: (ctx, hovered, _) =>
                    ClideIcon(PhosphorIcons.byName('arrow-clockwise'), size: 13, color: hovered ? tokens.globalForeground : tokens.globalTextMuted),
              ),
            ),
          ],
        ),
        // Per-type filter chips (T-343): large→small, all on by default.
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final (type, label) in _typeOrder)
                _TypeChip(
                  label: label,
                  color: typeColors.forType(type),
                  active: _enabledTypes.contains(type),
                  onToggle: () => _toggleType(type),
                  onSolo: () => _soloType(type),
                  tokens: tokens,
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (status, label) in sections)
                  if (byStatus[status] case final items? when items.isNotEmpty)
                    ClideAccordion(
                      label: label,
                      count: items.length,
                      expanded: filtering || _isSectionExpanded(status),
                      onToggle: () => _toggle(status),
                      children: [
                        for (final t in items)
                          _TicketCard(
                            entry: t,
                            tokens: tokens,
                            typeColors: typeColors,
                            focused: t.id == _focusedId,
                            focusKey: t.id == _focusedId ? _focusedKey : null,
                          ),
                      ],
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A type-filter chip (T-343): a type-colored dot + label. Active = filled
/// tint + colored border; inactive = muted, no fill. Single-click toggles the
/// type; double-click isolates it (chart-legend solo). One [GestureDetector]
/// owns both so Flutter disambiguates single vs double.
class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.color,
    required this.active,
    required this.onToggle,
    required this.onSolo,
    required this.tokens,
  });

  final String label;
  final Color color;
  final bool active;
  final VoidCallback onToggle;
  final VoidCallback onSolo;
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    final dotColor = active ? color : tokens.globalTextMuted;
    return Semantics(
      button: true,
      toggled: active,
      label: '$label type filter',
      child: ClideTooltip(
        message: 'Click to toggle · double-click to isolate',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onToggle,
            onDoubleTap: onSolo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: active ? color.withAlpha(0x22) : null,
                border: Border.all(color: active ? color : tokens.buttonBorder),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  ClideText(label, fontSize: clideFontSmall, fontFamily: clideMonoFamily, color: active ? tokens.globalForeground : tokens.globalTextMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketEntry {
  const _TicketEntry({required this.id, required this.title, this.type, this.status, this.priority, this.parentId});
  final String id;
  final String title;
  final String? type;
  final String? status;
  final String? priority;
  final String? parentId;

  factory _TicketEntry.fromJson(Map<String, dynamic> json) => _TicketEntry(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        type: json['type'] as String?,
        status: json['status'] as String?,
        priority: json['priority'] as String?,
        parentId: json['parent_id'] as String?,
      );
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.entry, required this.tokens, required this.typeColors, this.focused = false, this.focusKey});
  final _TicketEntry entry;
  final SurfaceTokens tokens;
  final TicketTypeColors typeColors;
  final bool focused;
  final GlobalKey? focusKey;

  @override
  Widget build(BuildContext context) {
    final typeColor = typeColors.forType(entry.type);
    final statusLabel = _statusLabel(entry.status);

    return Padding(
      key: focusKey,
      padding: const EdgeInsets.only(bottom: 4),
      child: ClideTappable(
        onTap: () => ClideKernel.of(context).messages.publish('builtin.tickets', 'selection', {'id': entry.id}),
        builder: (ctx, hovered, _) => Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: hovered ? tokens.sidebarItemHover : (focused ? tokens.sidebarItemSelected : tokens.panelBackground),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: focused ? tokens.globalFocus : (hovered ? tokens.panelActiveBorder : tokens.panelBorder), width: 1),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Parent shown as a muted breadcrumb above; the card's own ticket
                  // sits below it under a tree connector and in bold, so it's clear
                  // which id is the subject and which is its parent (T-281).
                  if (entry.parentId != null)
                    ClideTappable(
                      onTap: () => ClideKernel.of(context).messages.publish('builtin.tickets', 'selection', {'id': entry.parentId}),
                      builder: (ctx, hovered, _) => Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: ClideText(
                          entry.parentId!,
                          fontSize: clideFontSmall,
                          color: hovered ? tokens.globalForeground : tokens.globalTextMuted,
                          fontFamily: clideMonoFamily,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      if (entry.parentId != null) ClideText('└ ', fontSize: clideFontSmall, color: tokens.globalTextMuted),
                      ClideTooltip(
                        message: entry.type ?? 'task',
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ClideText(entry.id, fontSize: clideFontSmall, color: tokens.globalForeground, fontFamily: clideMonoFamily, fontWeight: FontWeight.w600),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClideText(entry.title, fontSize: clideFontCaption),
                  if (statusLabel != null) ...[
                    const SizedBox(height: 6),
                    _StatusBadge(label: statusLabel, tokens: tokens, status: entry.status),
                  ],
                ],
              ),
              // Hover affordance (T-327): hand the full ticket to the focused
              // Claude pane via the message bus.
              if (hovered) Positioned(top: 0, right: 0, child: _PickUpAction(id: entry.id, tokens: tokens)),
            ],
          ),
        ),
      ),
    );
  }

  static String? _statusLabel(String? status) => switch (status) {
        'in_progress' => 'WIP',
        'review' => 'REVIEW',
        'cancelled' => 'CANCELLED',
        _ => null,
      };
}

/// The hover "pick up" run-icon (T-327): fetches the full ticket and publishes
/// it on the message bus for the focused Claude pane to inject — the sidebar
/// stays decoupled from the session orchestrator (bus-only).
class _PickUpAction extends StatelessWidget {
  const _PickUpAction({required this.id, required this.tokens});
  final String id;
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    return ClideTappable(
      tooltip: 'Pick up — hand this ticket to the Claude pane',
      onTap: () {
        final kernel = ClideKernel.of(context);
        unawaited(() async {
          final resp = await kernel.ipc.request('pql.tickets.show', args: {'id': id, 'withContext': true});
          if (!resp.ok) return; // a missing ticket / failed fetch is a quiet no-op
          // Carry the current status so the receiver can gate the in_progress
          // transition without a second fetch (T-339).
          kernel.messages.publish('builtin.tickets', 'pick-up', {'id': id, 'prompt': pickUpPrompt(resp.data), 'status': resp.data['status']});
        }());
      },
      builder: (ctx, hovered, _) => Padding(
        padding: const EdgeInsets.all(2),
        child: ClideIcon(PhosphorIcons.byName('person-simple-run'), size: 14, color: hovered ? tokens.globalFocus : tokens.globalTextMuted),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.tokens, this.status});
  final String label;
  final SurfaceTokens tokens;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'in_progress' => tokens.statusInfo,
      'review' => tokens.statusWarning,
      'cancelled' => tokens.statusError,
      _ => tokens.globalTextMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(0x30),
        borderRadius: BorderRadius.circular(3),
      ),
      child: ClideText(label, fontSize: clideFontBadge, color: color, fontFamily: clideMonoFamily),
    );
  }
}
