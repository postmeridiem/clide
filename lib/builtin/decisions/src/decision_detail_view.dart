import 'dart:async';

import 'package:clide/builtin/decisions/src/decision_colors.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class DecisionDetailView extends StatefulWidget {
  const DecisionDetailView({super.key, this.initialId});
  final String? initialId;

  @override
  State<DecisionDetailView> createState() => _DecisionDetailViewState();
}

class _DecisionDetailViewState extends State<DecisionDetailView> {
  Map<String, Object?>? _decision;
  bool _loading = false;
  StreamSubscription<Message>? _sub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sub != null) return;
    final kernel = ClideKernel.of(context);
    _sub = kernel.messages.subscribe(publisher: 'builtin.decisions', channel: 'selection').listen((msg) {
      final id = msg.data['id'] as String?;
      if (id != null) unawaited(_load(id));
    });
    if (widget.initialId != null) {
      unawaited(_load(widget.initialId!));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load(String id) async {
    setState(() => _loading = true);
    final kernel = ClideKernel.of(context);
    final resp = await kernel.ipc.request('pql.decisions.read', args: {'id': id});
    if (!mounted) return;
    if (resp.ok) {
      kernel.messages.publish('builtin.decisions', 'focus', {'id': id});
    }
    setState(() {
      _loading = false;
      _decision = resp.ok ? resp.data : null;
    });
  }

  void _navigateToRecord(BuildContext context, String id) {
    final kernel = ClideKernel.of(context);
    if (id.startsWith('T-')) {
      kernel.messages.publish('builtin.tickets', 'selection', {'id': id});
    } else {
      kernel.messages.publish('builtin.decisions', 'selection', {'id': id});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: ClideText('Loading…', muted: true));
    final d = _decision;
    if (d == null) return const Padding(padding: EdgeInsets.all(12), child: ClideText('Select a decision to view details.', muted: true));

    final tokens = ClideTheme.of(context).surface;
    final isDark = ClideTheme.of(context).dark;
    final typeColors = DecisionTypeColors.forTheme(dark: isDark);

    final id = d['id'] as String? ?? '';
    final title = d['title'] as String? ?? '';
    final type = d['type'] as String?;
    final domain = d['domain'] as String?;
    final status = d['status'] as String?;
    final date = d['date'] as String?;
    final body = d['body'] as String?;
    final refs = (d['refs'] as List?)?.cast<Map<String, Object?>>() ?? const [];
    final typeColor = typeColors.forType(type);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.panelBackground,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: tokens.panelBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClideTooltip(
                      message: type ?? 'confirmed',
                      child: Container(width: 10, height: 10, decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle)),
                    ),
                    const SizedBox(width: 8),
                    ClideText(id, fontSize: clideFontSmall, color: typeColor, fontFamily: clideMonoFamily),
                    const Spacer(),
                    if (domain != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: tokens.panelBorder, borderRadius: BorderRadius.circular(3)),
                        child: ClideText(domain, fontSize: clideFontBadge, color: tokens.globalTextMuted, fontFamily: clideMonoFamily),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ClideText(title, fontSize: 15, fontWeight: FontWeight.w500),
                if (date != null) ...[
                  const SizedBox(height: 6),
                  ClideText(date, muted: true, fontSize: clideFontSmall, fontFamily: clideMonoFamily),
                ],
                if (status != null && status != 'active') ...[
                  const SizedBox(height: 8),
                  _StatusBadge(status: status, tokens: tokens),
                ],
              ],
            ),
          ),
          if (body != null && body.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClideMarkdown(body, onRecordTap: (id) => _navigateToRecord(context, id)),
          ],
          if (refs.isNotEmpty) ...[
            const SizedBox(height: 16),
            ClideText('CROSS-REFERENCES', fontSize: clideFontSmall, color: tokens.sidebarSectionHeader, fontFamily: clideMonoFamily),
            const SizedBox(height: 6),
            for (final ref in refs) _RefCard(ref: ref, tokens: tokens),
          ],
        ],
      ),
    );
  }
}

class _RefCard extends StatelessWidget {
  const _RefCard({required this.ref, required this.tokens});
  final Map<String, Object?> ref;
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    final targetId = (ref['target_id'] ?? ref['source_id']) as String? ?? '';
    final refType = ref['ref_type'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ClideTappable(
        onTap: () => ClideKernel.of(context).messages.publish('builtin.decisions', 'selection', {'id': targetId}),
        builder: (ctx, hovered, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: hovered ? tokens.sidebarItemHover : tokens.panelBackground,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: hovered ? tokens.panelActiveBorder : tokens.panelBorder),
          ),
          child: Row(
            children: [
              ClideText(targetId, fontSize: clideFontSmall, color: tokens.globalFocus, fontFamily: clideMonoFamily),
              const SizedBox(width: 8),
              ClideText(refType, fontSize: clideFontSmall, color: tokens.globalTextMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.tokens});
  final String status;
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'open' => tokens.statusWarning,
      'resolved' => tokens.statusSuccess,
      _ => tokens.globalTextMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withAlpha(0x30), borderRadius: BorderRadius.circular(3)),
      child: ClideText(status.toUpperCase(), fontSize: clideFontBadge, color: color, fontFamily: clideMonoFamily),
    );
  }
}
