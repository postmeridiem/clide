import 'dart:async';
import 'dart:convert';

import 'package:clide_app/kernel/kernel.dart';
import 'package:clide_app/widgets/widgets.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loading || _tickets.isNotEmpty) return;
    unawaited(_load());
  }

  Future<void> _load() async {
    final kernel = ClideKernel.of(context);
    final resp = await kernel.ipc.request('pql.exec', args: {
      'argv': ['ticket', 'list'],
    });
    if (!mounted) return;
    if (!resp.ok) {
      setState(() {
        _error = resp.error?.message ?? 'failed to load tickets';
        _loading = false;
      });
      return;
    }
    final raw = resp.data['stdout'] as String? ?? '[]';
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      setState(() {
        _tickets = list.map(_TicketEntry.fromJson).toList();
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
      return const Center(child: ClideText('Loading tickets...', muted: true));
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: ClideText(_error!, muted: true),
      );
    }
    if (_tickets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: ClideText('No tickets found.\nRun `pql ticket new` to create one.', muted: true),
      );
    }
    return ListView.builder(
      itemCount: _tickets.length,
      itemBuilder: (ctx, i) {
        final t = _tickets[i];
        return _TicketRow(entry: t, tokens: tokens);
      },
    );
  }
}

class _TicketEntry {
  const _TicketEntry({required this.id, required this.title, this.status, this.priority});
  final String id;
  final String title;
  final String? status;
  final String? priority;

  factory _TicketEntry.fromJson(Map<String, dynamic> json) => _TicketEntry(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        status: json['status'] as String?,
        priority: json['priority'] as String?,
      );
}

class _TicketRow extends StatefulWidget {
  const _TicketRow({required this.entry, required this.tokens});
  final _TicketEntry entry;
  final SurfaceTokens tokens;

  @override
  State<_TicketRow> createState() => _TicketRowState();
}

class _TicketRowState extends State<_TicketRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (widget.entry.status) {
      'done' => widget.tokens.statusSuccess,
      'in_progress' => widget.tokens.statusInfo,
      'cancelled' => widget.tokens.statusError,
      _ => widget.tokens.globalTextMuted,
    };
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        color: _hovered ? widget.tokens.listItemHoverBackground : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            ClideText(widget.entry.id, color: widget.tokens.globalTextMuted, fontSize: 12),
            const SizedBox(width: 6),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(child: ClideText(widget.entry.title, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
