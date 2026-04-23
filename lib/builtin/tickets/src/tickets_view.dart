import 'dart:async';

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
  final Set<String> _expanded = {'active', 'backlog'};

  void _toggle(String key) {
    setState(() {
      if (_expanded.contains(key)) _expanded.remove(key); else _expanded.add(key);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loading || _tickets.isNotEmpty) return;
    unawaited(_load());
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
    final hasFilter = lf.isNotEmpty;
    final filtered = hasFilter ? _tickets.where((t) => t.id.toLowerCase().contains(lf) || t.title.toLowerCase().contains(lf) || (t.status ?? '').contains(lf) || (t.type ?? '').contains(lf)).toList() : _tickets;

    final active = filtered.where((t) => t.status == 'in_progress').toList();
    final backlog = filtered.where((t) => t.status == 'backlog' || t.status == 'ready').toList();
    final done = filtered.where((t) => t.status == 'done').toList();
    final other = filtered.where((t) => t.status == 'cancelled' || t.status == 'review').toList();

    final isDark = ClideTheme.of(context).dark;
    final typeColors = TicketTypeColors.forTheme(dark: isDark);

    return Column(
      children: [
        ClideFilterBox(hint: 'Filter tickets…', onChanged: (v) => setState(() => _filter = v)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (active.isNotEmpty) _AccordionSection(label: 'ACTIVE', count: active.length, tokens: tokens, expanded: hasFilter || _expanded.contains('active'), onToggle: () => _toggle('active'), children: [for (final t in active) _TicketCard(entry: t, tokens: tokens, typeColors: typeColors)]),
                if (backlog.isNotEmpty) _AccordionSection(label: 'BACKLOG', count: backlog.length, tokens: tokens, expanded: hasFilter || _expanded.contains('backlog'), onToggle: () => _toggle('backlog'), children: [for (final t in backlog) _TicketCard(entry: t, tokens: tokens, typeColors: typeColors)]),
                if (done.isNotEmpty) _AccordionSection(label: 'DONE', count: done.length, tokens: tokens, expanded: hasFilter || _expanded.contains('done'), onToggle: () => _toggle('done'), children: [for (final t in done) _TicketCard(entry: t, tokens: tokens, typeColors: typeColors)]),
                if (other.isNotEmpty) _AccordionSection(label: 'OTHER', count: other.length, tokens: tokens, expanded: hasFilter || _expanded.contains('other'), onToggle: () => _toggle('other'), children: [for (final t in other) _TicketCard(entry: t, tokens: tokens, typeColors: typeColors)]),
              ],
            ),
          ),
        ),
      ],
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

class _AccordionSection extends StatelessWidget {
  const _AccordionSection({required this.label, required this.count, required this.tokens, required this.expanded, required this.onToggle, required this.children});
  final String label;
  final int count;
  final SurfaceTokens tokens;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClideTappable(
          onTap: onToggle,
          builder: (ctx, hovered, _) => Padding(
            padding: const EdgeInsets.only(left: 4, top: 10, bottom: 4),
            child: Row(
              children: [
                ClideIcon(expanded ? PhosphorIcons.caretDown : PhosphorIcons.caretRight, size: 10, color: tokens.globalTextMuted),
                const SizedBox(width: 6),
                ClideText('$label · $count', fontSize: 11, color: hovered ? tokens.globalForeground : tokens.sidebarSectionHeader, fontFamily: clideMonoFamily),
              ],
            ),
          ),
        ),
        if (expanded) ...children,
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.entry, required this.tokens, required this.typeColors});
  final _TicketEntry entry;
  final SurfaceTokens tokens;
  final TicketTypeColors typeColors;

  @override
  Widget build(BuildContext context) {
    final typeColor = typeColors.forType(entry.type);
    final statusLabel = _statusLabel(entry.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ClideTappable(
        onTap: () => ClideKernel.of(context).messages.publish('builtin.tickets', 'selection', {'id': entry.id}),
        builder: (ctx, hovered, _) => Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: hovered ? tokens.sidebarItemHover : tokens.panelBackground,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: hovered ? tokens.panelActiveBorder : tokens.panelBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClideTooltip(
                    message: entry.type ?? 'task',
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ClideText(entry.id, fontSize: 11, color: tokens.globalTextMuted, fontFamily: clideMonoFamily),
                  if (entry.parentId != null) ...[
                    ClideText(' ← ', fontSize: 11, color: tokens.globalTextMuted),
                    ClideText(entry.parentId!, fontSize: 11, color: tokens.globalTextMuted, fontFamily: clideMonoFamily),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              ClideText(entry.title, fontSize: 13),
              if (statusLabel != null) ...[
                const SizedBox(height: 6),
                _StatusBadge(label: statusLabel, tokens: tokens, status: entry.status),
              ],
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
      child: ClideText(label, fontSize: 10, color: color, fontFamily: clideMonoFamily),
    );
  }
}
