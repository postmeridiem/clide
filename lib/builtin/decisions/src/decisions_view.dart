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
  final Set<String> _expanded = {'confirmed'};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loading || _decisions.isNotEmpty) return;
    unawaited(_load());
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

  void _toggleSection(String key) {
    setState(() {
      if (_expanded.contains(key)) {
        _expanded.remove(key);
      } else {
        _expanded.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    if (_loading) return const Center(child: ClideText('Loading decisions...', muted: true));
    if (_error != null) return Padding(padding: const EdgeInsets.all(12), child: ClideText(_error!, muted: true));
    if (_decisions.isEmpty) return const Padding(padding: EdgeInsets.all(12), child: ClideText('No decisions found.\nRun `pql decisions sync` to index.', muted: true));

    final lf = _filter.toLowerCase();
    final hasFilter = lf.isNotEmpty;
    final filtered = hasFilter ? _decisions.where((d) => d.id.toLowerCase().contains(lf) || d.title.toLowerCase().contains(lf) || (d.domain ?? '').toLowerCase().contains(lf) || (d.type ?? '').contains(lf)).toList() : _decisions;

    final confirmed = filtered.where((d) => d.type == 'confirmed').toList();
    final questions = filtered.where((d) => d.type == 'question').toList();
    final rejected = filtered.where((d) => d.type == 'rejected').toList();

    final isDark = ClideTheme.of(context).dark;
    final typeColors = DecisionTypeColors.forTheme(dark: isDark);

    return Column(
      children: [
        ClideFilterBox(hint: 'Filter decisions…', onChanged: (v) => setState(() => _filter = v)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (confirmed.isNotEmpty) _AccordionSection(
                  label: 'CONFIRMED', count: confirmed.length, tokens: tokens,
                  color: typeColors.confirmed,
                  expanded: hasFilter || _expanded.contains('confirmed'),
                  onToggle: () => _toggleSection('confirmed'),
                  children: [for (final d in confirmed) _DecisionCard(entry: d, tokens: tokens, typeColors: typeColors)],
                ),
                if (questions.isNotEmpty) _AccordionSection(
                  label: 'QUESTIONS', count: questions.length, tokens: tokens,
                  color: typeColors.question,
                  expanded: hasFilter || _expanded.contains('question'),
                  onToggle: () => _toggleSection('question'),
                  children: [for (final d in questions) _DecisionCard(entry: d, tokens: tokens, typeColors: typeColors)],
                ),
                if (rejected.isNotEmpty) _AccordionSection(
                  label: 'REJECTED', count: rejected.length, tokens: tokens,
                  color: typeColors.rejected,
                  expanded: hasFilter || _expanded.contains('rejected'),
                  onToggle: () => _toggleSection('rejected'),
                  children: [for (final d in rejected) _DecisionCard(entry: d, tokens: tokens, typeColors: typeColors)],
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

class _AccordionSection extends StatelessWidget {
  const _AccordionSection({
    required this.label, required this.count, required this.tokens,
    required this.color, required this.expanded, required this.onToggle,
    required this.children,
  });
  final String label;
  final int count;
  final SurfaceTokens tokens;
  final Color color;
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
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
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

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({required this.entry, required this.tokens, required this.typeColors});
  final _DecisionEntry entry;
  final SurfaceTokens tokens;
  final DecisionTypeColors typeColors;

  @override
  Widget build(BuildContext context) {
    final typeColor = typeColors.forType(entry.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ClideTappable(
        onTap: () => ClideKernel.of(context).messages.publish('builtin.decisions', 'selection', {'id': entry.id}),
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
                    message: entry.type ?? 'confirmed',
                    child: Container(width: 8, height: 8, decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle)),
                  ),
                  const SizedBox(width: 6),
                  ClideText(entry.id, fontSize: 11, color: tokens.globalTextMuted, fontFamily: clideMonoFamily),
                  const Spacer(),
                  if (entry.domain != null)
                    ClideText(entry.domain!, fontSize: 10, color: tokens.globalTextMuted, fontFamily: clideMonoFamily),
                ],
              ),
              const SizedBox(height: 4),
              ClideText(entry.title, fontSize: 13),
              if (entry.status == 'resolved') ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: tokens.statusSuccess.withAlpha(0x30), borderRadius: BorderRadius.circular(3)),
                  child: ClideText('resolved', fontSize: 10, color: tokens.statusSuccess, fontFamily: clideMonoFamily),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
