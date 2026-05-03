import 'dart:async';

import 'package:clide/builtin/decisions/src/decision_colors.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class DecisionsView extends StatefulWidget {
  const DecisionsView({super.key});

  @override
  State<DecisionsView> createState() => _DecisionsViewState();
}

class _DecisionsViewState extends State<DecisionsView> {
  List<_DecisionEntry> _decisions = [];
  String? _error;
  bool _loading = true;
  String _filter = '';
  String? _focusedId;
  final _focusedKey = GlobalKey();
  final Set<String> _pinned = {'confirmed'};
  StreamSubscription<Message>? _focusSub;
  StreamSubscription<DaemonEvent>? _fileSub;
  StreamSubscription<SchedulerTick>? _schedulerSub;
  bool _refreshing = false;
  bool _pendingRefresh = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_focusSub == null) {
      final kernel = ClideKernel.of(context);
      _focusSub = kernel.messages.subscribe(publisher: 'builtin.decisions', channel: 'focus').listen(_onFocus);
      _fileSub = kernel.events
          .on<DaemonEvent>()
          .where((e) => e.subsystem == 'files' && e.kind == 'files.changed' && _isDecisionPath(e.data['path'] as String? ?? ''))
          .listen((_) => _refresh());
      _schedulerSub = kernel.events.on<SchedulerTick>().where((e) => e.tier == SchedulerTier.oneMinute).listen((_) => _refresh());
    }
    if (!_loading || _decisions.isNotEmpty) return;
    unawaited(_load());
  }

  static bool _isDecisionPath(String path) => path.startsWith('decisions/') && path.endsWith('.md');

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
    await kernel.ipc.request('pql.decisions.sync');
    final resp = await kernel.ipc.request('pql.decisions.list');
    if (!mounted) return;
    if (!resp.ok) {
      setState(() {
        _error = resp.error?.message ?? 'failed to load decisions';
        _loading = false;
      });
      return;
    }
    final raw = resp.data['decisions'];
    if (raw is List) {
      setState(() {
        _decisions = [for (final e in raw) _DecisionEntry.fromJson((e as Map).cast<String, dynamic>())];
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _focusSub?.cancel();
    _fileSub?.cancel();
    _schedulerSub?.cancel();
    super.dispose();
  }

  bool _isSectionExpanded(String type) {
    if (_pinned.contains(type)) return true;
    if (_focusedId == null) return false;
    final entry = _decisions.where((d) => d.id == _focusedId).firstOrNull;
    return (entry?.type ?? 'confirmed') == type;
  }

  void _onFocus(Message msg) {
    final id = msg.data['id'] as String?;
    if (id == null || id == _focusedId) return;
    setState(() => _focusedId = id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _focusedKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 200), alignment: 0.3);
    });
  }

  void _toggleSection(String key) {
    setState(() {
      if (_pinned.contains(key)) {
        _pinned.remove(key);
      } else {
        _pinned.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    if (_loading) return const Center(child: ClideText('Loading decisions...', muted: true));
    if (_error != null) return Padding(padding: const EdgeInsets.all(12), child: ClideText(_error!, muted: true));
    if (_decisions.isEmpty)
      return const Padding(padding: EdgeInsets.all(12), child: ClideText('No decisions found.\nRun `pql decisions sync` to index.', muted: true));

    final lf = _filter.toLowerCase();
    final hasFilter = lf.isNotEmpty;
    final filtered = hasFilter
        ? _decisions
            .where((d) =>
                d.id.toLowerCase().contains(lf) ||
                d.title.toLowerCase().contains(lf) ||
                (d.domain ?? '').toLowerCase().contains(lf) ||
                (d.type ?? '').contains(lf))
            .toList()
        : _decisions;

    final confirmed = filtered.where((d) => d.type == 'confirmed').toList();
    final questions = filtered.where((d) => d.type == 'question').toList();
    final rejected = filtered.where((d) => d.type == 'rejected').toList();

    final isDark = ClideTheme.of(context).dark;
    final typeColors = DecisionTypeColors.forTheme(dark: isDark);

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: ClideFilterBox(hint: 'Filter decisions…', onChanged: (v) => setState(() => _filter = v))),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ClideTappable(
                onTap: _refreshing ? null : _refresh,
                tooltip: 'Refresh decisions',
                builder: (ctx, hovered, _) =>
                    ClideIcon(PhosphorIcons.arrowClockwise, size: 13, color: hovered ? tokens.globalForeground : tokens.globalTextMuted),
              ),
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (confirmed.isNotEmpty)
                  ClideAccordion(
                    label: 'CONFIRMED',
                    count: confirmed.length,
                    leading: Container(width: 8, height: 8, decoration: BoxDecoration(color: typeColors.confirmed, shape: BoxShape.circle)),
                    expanded: hasFilter || _isSectionExpanded('confirmed'),
                    onToggle: () => _toggleSection('confirmed'),
                    children: [
                      for (final d in confirmed)
                        _DecisionCard(
                            entry: d, tokens: tokens, typeColors: typeColors, focused: d.id == _focusedId, focusKey: d.id == _focusedId ? _focusedKey : null)
                    ],
                  ),
                if (questions.isNotEmpty)
                  ClideAccordion(
                    label: 'QUESTIONS',
                    count: questions.length,
                    leading: Container(width: 8, height: 8, decoration: BoxDecoration(color: typeColors.question, shape: BoxShape.circle)),
                    expanded: hasFilter || _isSectionExpanded('question'),
                    onToggle: () => _toggleSection('question'),
                    children: [
                      for (final d in questions)
                        _DecisionCard(
                            entry: d, tokens: tokens, typeColors: typeColors, focused: d.id == _focusedId, focusKey: d.id == _focusedId ? _focusedKey : null)
                    ],
                  ),
                if (rejected.isNotEmpty)
                  ClideAccordion(
                    label: 'REJECTED',
                    count: rejected.length,
                    leading: Container(width: 8, height: 8, decoration: BoxDecoration(color: typeColors.rejected, shape: BoxShape.circle)),
                    expanded: hasFilter || _isSectionExpanded('rejected'),
                    onToggle: () => _toggleSection('rejected'),
                    children: [
                      for (final d in rejected)
                        _DecisionCard(
                            entry: d, tokens: tokens, typeColors: typeColors, focused: d.id == _focusedId, focusKey: d.id == _focusedId ? _focusedKey : null)
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

class _DecisionEntry {
  const _DecisionEntry({required this.id, required this.title, this.type, this.domain, this.status});
  final String id;
  final String title;
  final String? type;
  final String? domain;
  final String? status;

  factory _DecisionEntry.fromJson(Map<String, dynamic> json) => _DecisionEntry(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        type: json['type'] as String?,
        domain: json['domain'] as String?,
        status: json['status'] as String?,
      );
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({required this.entry, required this.tokens, required this.typeColors, this.focused = false, this.focusKey});
  final _DecisionEntry entry;
  final SurfaceTokens tokens;
  final DecisionTypeColors typeColors;
  final bool focused;
  final GlobalKey? focusKey;

  @override
  Widget build(BuildContext context) {
    final typeColor = typeColors.forType(entry.type);
    return Padding(
      key: focusKey,
      padding: const EdgeInsets.only(bottom: 4),
      child: ClideTappable(
        onTap: () => ClideKernel.of(context).messages.publish('builtin.decisions', 'selection', {'id': entry.id}),
        builder: (ctx, hovered, _) => Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: hovered ? tokens.sidebarItemHover : (focused ? tokens.sidebarItemSelected : tokens.panelBackground),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: focused ? tokens.globalFocus : (hovered ? tokens.panelActiveBorder : tokens.panelBorder), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClideTooltip(
                    message: entry.type ?? 'confirmed',
                    child: Container(width: 8, height: 8, decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle)),
                  ),
                  const SizedBox(width: 6),
                  ClideText(entry.id, fontSize: clideFontSmall, color: tokens.globalTextMuted, fontFamily: clideMonoFamily),
                  const Spacer(),
                  if (entry.domain != null) ClideText(entry.domain!, fontSize: clideFontBadge, color: tokens.globalTextMuted, fontFamily: clideMonoFamily),
                ],
              ),
              const SizedBox(height: 4),
              ClideText(entry.title, fontSize: clideFontCaption),
              if (entry.status == 'resolved') ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: tokens.statusSuccess.withAlpha(0x30), borderRadius: BorderRadius.circular(3)),
                  child: ClideText('resolved', fontSize: clideFontBadge, color: tokens.statusSuccess, fontFamily: clideMonoFamily),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
