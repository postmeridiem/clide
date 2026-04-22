import 'dart:async';
import 'dart:convert';

import 'package:clide_app/kernel/kernel.dart';
import 'package:clide_app/widgets/widgets.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loading || _decisions.isNotEmpty) return;
    unawaited(_load());
  }

  Future<void> _load() async {
    final kernel = ClideKernel.of(context);
    final resp = await kernel.ipc.request('pql.exec', args: {
      'argv': ['decisions', 'list', '--type', 'confirmed'],
    });
    if (!mounted) return;
    if (!resp.ok) {
      setState(() {
        _error = resp.error?.message ?? 'failed to load decisions';
        _loading = false;
      });
      return;
    }
    final raw = resp.data['stdout'] as String? ?? '[]';
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      setState(() {
        _decisions = list.map(_DecisionEntry.fromJson).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'parse error: $e';
        _loading = false;
      });
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
    return ListView.builder(
        itemCount: _decisions.length,
        itemBuilder: (ctx, i) {
          final d = _decisions[i];
          return _DecisionRow(entry: d, tokens: tokens);
        },
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

class _DecisionRow extends StatefulWidget {
  const _DecisionRow({required this.entry, required this.tokens});
  final _DecisionEntry entry;
  final SurfaceTokens tokens;

  @override
  State<_DecisionRow> createState() => _DecisionRowState();
}

class _DecisionRowState extends State<_DecisionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        color: _hovered ? widget.tokens.listItemHoverBackground : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            ClideText(widget.entry.id, color: widget.tokens.globalTextMuted, fontSize: 12),
            const SizedBox(width: 8),
            Expanded(child: ClideText(widget.entry.title, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
