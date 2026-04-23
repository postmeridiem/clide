import 'dart:async';

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

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    if (_loading) {
      return const Center(child: ClideText('Loading decisions...', muted: true));
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: ClideText(_error!, muted: true),
      );
    }
    if (_decisions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: ClideText('No decisions found.\nRun `pql decisions sync` to index.', muted: true),
      );
    }
    final lf = _filter.toLowerCase();
    final filtered = lf.isEmpty ? _decisions : _decisions.where((d) => d.id.toLowerCase().contains(lf) || d.title.toLowerCase().contains(lf) || (d.domain ?? '').toLowerCase().contains(lf)).toList();
    return Column(
      children: [
        ClideFilterBox(hint: 'Filter decisions…', onChanged: (v) => setState(() => _filter = v)),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (ctx, i) => _DecisionRow(entry: filtered[i], tokens: tokens),
          ),
        ),
      ],
    );
  }
}

class _DecisionEntry {
  const _DecisionEntry({required this.id, required this.title, this.domain, this.status});
  final String id;
  final String title;
  final String? domain;
  final String? status;

  factory _DecisionEntry.fromJson(Map<String, dynamic> json) => _DecisionEntry(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        domain: json['domain'] as String?,
        status: json['status'] as String?,
      );
}

class _DecisionRow extends StatelessWidget {
  const _DecisionRow({required this.entry, required this.tokens});
  final _DecisionEntry entry;
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    return ClideTappable(
      builder: (context, hovered, _) => Container(
        color: hovered ? tokens.listItemHoverBackground : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            ClideText(entry.id, color: tokens.globalTextMuted, fontSize: 12),
            const SizedBox(width: 8),
            Expanded(child: ClideText(entry.title, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
