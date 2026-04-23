import 'package:clide/builtin/tickets/src/ticket_colors.dart';
import 'package:clide/builtin/tickets/src/ticket_detail_controller.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class TicketDetailView extends StatefulWidget {
  const TicketDetailView({super.key, this.initialId});
  final String? initialId;

  @override
  State<TicketDetailView> createState() => _TicketDetailViewState();
}

class _TicketDetailViewState extends State<TicketDetailView> {
  TicketDetailController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final kernel = ClideKernel.of(context);
    _controller = TicketDetailController(ipc: kernel.ipc, messages: kernel.messages, panels: kernel.panels);
    if (widget.initialId != null) {
      _controller!.load(widget.initialId!);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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
    final c = _controller;
    if (c == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: c,
      builder: (ctx, _) {
        if (c.loading) return const Center(child: ClideText('Loading…', muted: true));
        final d = c.detail;
        if (d == null) return const Padding(padding: EdgeInsets.all(12), child: ClideText('Select a ticket to view details.', muted: true));

        final tokens = ClideTheme.of(ctx).surface;
        final isDark = ClideTheme.of(ctx).dark;
        final typeColors = TicketTypeColors.forTheme(dark: isDark);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TicketHeader(detail: d, tokens: tokens, typeColors: typeColors),
              const SizedBox(height: 12),
              _StatusControls(detail: d, tokens: tokens, controller: c),
              if (d.description != null && d.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClideMarkdown(d.description!, onRecordTap: (id) => _navigateToRecord(ctx, id)),
              ],
              if (d.parents.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionLabel(label: 'PARENT TREE', tokens: tokens),
                const SizedBox(height: 6),
                for (var i = 0; i < d.parents.length; i++)
                  _CompactCard(
                    data: d.parents[i],
                    tokens: tokens,
                    typeColors: typeColors,
                    indent: i,
                  ),
              ],
              if (d.decisions.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionLabel(label: 'REFERENCED DECISIONS', tokens: tokens),
                const SizedBox(height: 6),
                for (final dec in d.decisions) _DecisionRefCard(data: dec, tokens: tokens),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TicketHeader extends StatelessWidget {
  const _TicketHeader({required this.detail, required this.tokens, required this.typeColors});
  final TicketDetail detail;
  final SurfaceTokens tokens;
  final TicketTypeColors typeColors;

  @override
  Widget build(BuildContext context) {
    final typeColor = typeColors.forType(detail.type);
    return Container(
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
                message: detail.type ?? 'task',
                child: Container(width: 10, height: 10, decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle)),
              ),
              const SizedBox(width: 8),
              ClideText(detail.id, fontSize: clideFontSmall, color: typeColor, fontFamily: clideMonoFamily),
              const Spacer(),
              if (detail.priority != null)
                ClideText(detail.priority!, fontSize: clideFontSmall, color: tokens.globalTextMuted, fontFamily: clideMonoFamily),
            ],
          ),
          const SizedBox(height: 8),
          ClideText(detail.title, fontSize: 15, fontWeight: FontWeight.w500),
          if (detail.assignedTo != null) ...[
            const SizedBox(height: 6),
            ClideText('assigned: ${detail.assignedTo}', muted: true, fontSize: clideFontSmall, fontFamily: clideMonoFamily),
          ],
        ],
      ),
    );
  }
}

class _StatusControls extends StatelessWidget {
  const _StatusControls({required this.detail, required this.tokens, required this.controller});
  final TicketDetail detail;
  final SurfaceTokens tokens;
  final TicketDetailController controller;

  static const _statuses = ['backlog', 'ready', 'in_progress', 'review', 'done'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final s in _statuses) ...[
          Expanded(
            child: ClideTappable(
              onTap: () async {
                await controller.ipc.request('pql.tickets.status', args: {'ids': detail.id, 'status': s});
                await controller.load(detail.id);
              },
              builder: (ctx, hovered, _) {
                final active = detail.status == s;
                final color = active ? tokens.statusInfo : (hovered ? tokens.globalForeground : tokens.globalTextMuted);
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: active ? tokens.statusInfo.withAlpha(0x30) : null,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: active ? tokens.statusInfo : tokens.panelBorder),
                  ),
                  alignment: Alignment.center,
                  child: ClideText(_shortLabel(s), fontSize: clideFontBadge, color: color, fontFamily: clideMonoFamily),
                );
              },
            ),
          ),
          if (s != _statuses.last) const SizedBox(width: 4),
        ],
      ],
    );
  }

  static String _shortLabel(String s) => switch (s) {
        'backlog' => 'BACKLOG',
        'ready' => 'READY',
        'in_progress' => 'WIP',
        'review' => 'REVIEW',
        'done' => 'DONE',
        _ => s.toUpperCase(),
      };
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.tokens});
  final String label;
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    return ClideText(label, fontSize: clideFontSmall, color: tokens.sidebarSectionHeader, fontFamily: clideMonoFamily);
  }
}

class _CompactCard extends StatelessWidget {
  const _CompactCard({required this.data, required this.tokens, required this.typeColors, this.indent = 0});
  final Map<String, Object?> data;
  final SurfaceTokens tokens;
  final TicketTypeColors typeColors;
  final int indent;

  @override
  Widget build(BuildContext context) {
    final id = data['id'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final type = data['type'] as String?;
    final typeColor = typeColors.forType(type);
    return Padding(
      padding: EdgeInsets.only(left: indent * 12.0, bottom: 4),
      child: ClideTappable(
        onTap: () => ClideKernel.of(context).messages.publish('builtin.tickets', 'selection', {'id': id}),
        builder: (ctx, hovered, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: hovered ? tokens.sidebarItemHover : tokens.panelBackground,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: hovered ? tokens.panelActiveBorder : tokens.panelBorder),
          ),
          child: Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              ClideText(id, fontSize: clideFontSmall, color: tokens.globalTextMuted, fontFamily: clideMonoFamily),
              const SizedBox(width: 8),
              Expanded(child: ClideText(title, fontSize: clideFontSmall)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DecisionRefCard extends StatelessWidget {
  const _DecisionRefCard({required this.data, required this.tokens});
  final Map<String, Object?> data;
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    final id = data['id'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final type = data['type'] as String?;
    final domain = data['domain'] as String?;
    final color = switch (type) {
      'confirmed' => tokens.statusSuccess,
      'question' => tokens.statusWarning,
      'rejected' => tokens.statusError,
      _ => tokens.globalTextMuted,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ClideTappable(
        onTap: () => ClideKernel.of(context).messages.publish('builtin.decisions', 'selection', {'id': id}),
        builder: (ctx, hovered, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: hovered ? tokens.sidebarItemHover : tokens.panelBackground,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: hovered ? tokens.panelActiveBorder : tokens.panelBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  ClideText(id, fontSize: clideFontSmall, color: color, fontFamily: clideMonoFamily),
                  const Spacer(),
                  if (domain != null) ClideText(domain, fontSize: clideFontBadge, color: tokens.globalTextMuted, fontFamily: clideMonoFamily),
                ],
              ),
              const SizedBox(height: 3),
              ClideText(title, fontSize: clideFontSmall),
            ],
          ),
        ),
      ),
    );
  }
}
