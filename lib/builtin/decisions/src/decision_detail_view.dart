import 'dart:async';

import 'package:clide/builtin/decisions/src/decision_colors.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class DecisionDetailView extends StatefulWidget {
  const DecisionDetailView({super.key});

  @override
  State<DecisionDetailView> createState() => _DecisionDetailViewState();
}

class _DecisionDetailViewState extends State<DecisionDetailView> {
  StreamSubscription<Message>? _sub;
  Map<String, Object?>? _decision;
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sub != null) return;
    final kernel = ClideKernel.of(context);
    _sub = kernel.messages.subscribe(publisher: 'builtin.decisions', channel: 'selection').listen((msg) {
      final id = msg.data['id'] as String?;
      if (id != null) {
        kernel.panels.activateTab(Slots.contextPanel, 'decisions.detail');
        unawaited(_load(id));
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load(String id) async {
    setState(() => _loading = true);
    final kernel = ClideKernel.of(context);
    final resp = await kernel.ipc.request('pql.decisions.show', args: {'id': id});
    if (!mounted) return;
    setState(() {
      _loading = false;
      _decision = resp.ok ? resp.data : null;
    });
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
                    ClideText(id, fontSize: 13, color: typeColor, fontFamily: clideMonoFamily),
                    const Spacer(),
                    if (domain != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: tokens.panelBorder, borderRadius: BorderRadius.circular(3)),
                        child: ClideText(domain, fontSize: 10, color: tokens.globalTextMuted, fontFamily: clideMonoFamily),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ClideText(title, fontSize: 15, fontWeight: FontWeight.w500),
                if (date != null) ...[
                  const SizedBox(height: 6),
                  ClideText(date, muted: true, fontSize: 12, fontFamily: clideMonoFamily),
                ],
                if (status != null && status != 'active') ...[
                  const SizedBox(height: 8),
                  _StatusBadge(status: status, tokens: tokens),
                ],
              ],
            ),
          ),
        ],
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
      child: ClideText(status.toUpperCase(), fontSize: 10, color: color, fontFamily: clideMonoFamily),
    );
  }
}
