/// Faithful tiling for a Claude agent team (epic T-132, T-140).
///
/// Wraps the lead Claude surface on the left; when the orchestrator
/// emits [TeamMemberJoined], a resizable right pane appears holding a
/// teammate tile per live member, arranged in a responsive grid that
/// wraps 1→2→3 columns by count. Each tile renders the teammate's
/// conversation from its per-agent MessageBus channel. Tiles vanish on
/// [TeamMemberLeft]. With no team, only the lead is shown.
library;

import 'dart:async';

import 'package:clide/builtin/claude/src/conversation_controller.dart';
import 'package:clide/builtin/claude/src/activity_cluster.dart' show foldLevelFromName, kActivityFoldLevelKey;
import 'package:clide/builtin/claude/src/conversation_view.dart';
import 'package:clide/builtin/claude/src/transcript_publisher.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class TeamPanelHost extends StatefulWidget {
  const TeamPanelHost({super.key, required this.lead});

  /// The lead Claude surface (normally the tabbed primary/secondary host).
  final Widget lead;

  @override
  State<TeamPanelHost> createState() => _TeamPanelHostState();
}

class _TeamPanelHostState extends State<TeamPanelHost> {
  final List<TeamMemberJoined> _members = [];
  final Map<String, ConversationController> _controllers = {};
  StreamSubscription<TeamMemberJoined>? _joinSub;
  StreamSubscription<TeamMemberLeft>? _leftSub;
  bool _subscribed = false;

  /// Fraction of the width given to the lead pane.
  double _leadFraction = 0.5;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subscribed) return;
    _subscribed = true;
    final kernel = ClideKernel.of(context);
    _joinSub = kernel.events.on<TeamMemberJoined>().listen(_onJoined);
    _leftSub = kernel.events.on<TeamMemberLeft>().listen(_onLeft);
  }

  void _onJoined(TeamMemberJoined m) {
    if (_controllers.containsKey(m.agentId)) return;
    final kernel = ClideKernel.of(context);
    _controllers[m.agentId] = ConversationController.fromBus(messages: kernel.messages, channel: ClaudeConversation.teammateChannel(m.agentId));
    setState(() => _members.add(m));
  }

  void _onLeft(TeamMemberLeft m) {
    _controllers.remove(m.agentId)?.dispose();
    setState(() => _members.removeWhere((x) => x.agentId == m.agentId));
  }

  @override
  void dispose() {
    _joinSub?.cancel();
    _leftSub?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_members.isEmpty) return widget.lead;
    final tokens = ClideTheme.of(context).surface;

    return LayoutBuilder(
      builder: (context, constraints) {
        final total = constraints.maxWidth;
        final leadW = (total * _leadFraction).clamp(240.0, total > 480 ? total - 240 : total);
        return Row(
          children: [
            SizedBox(width: leadW, child: widget.lead),
            _Divider(
              color: tokens.panelBorder,
              onDrag: (dx) => setState(() {
                _leadFraction = ((leadW + dx) / total).clamp(0.2, 0.8);
              }),
            ),
            Expanded(
              child: _TeammateGrid(members: _members, controllers: _controllers, tokens: tokens),
            ),
          ],
        );
      },
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color, required this.onDrag});
  final Color color;
  final void Function(double dx) onDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (e) => onDrag(e.delta.dx),
        child: SizedBox(
          width: 7,
          child: Center(child: Container(width: 1, color: color)),
        ),
      ),
    );
  }
}

/// Equal-sized teammate tiles in a grid that wraps 1→2→3 columns by count.
class _TeammateGrid extends StatelessWidget {
  const _TeammateGrid({required this.members, required this.controllers, required this.tokens});

  final List<TeamMemberJoined> members;
  final Map<String, ConversationController> controllers;
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    final cols = members.length >= 3 ? 3 : members.length;
    final rows = (members.length / cols).ceil();

    // One selection area over the whole grid so a drag-select spans tiles.
    return ClideSelectionArea(
      child: Column(
        children: [
          for (var r = 0; r < rows; r++)
            Expanded(
              child: Row(children: [for (var c = 0; c < cols; c++) Expanded(child: _cell(r * cols + c))]),
            ),
        ],
      ),
    );
  }

  Widget _cell(int i) {
    if (i >= members.length) return const SizedBox.shrink();
    final m = members[i];
    return _TeammateTile(member: m, controller: controllers[m.agentId]!, tokens: tokens);
  }
}

class _TeammateTile extends StatelessWidget {
  const _TeammateTile({required this.member, required this.controller, required this.tokens});

  final TeamMemberJoined member;
  final ConversationController controller;
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    final accent = teamColor(member.color, fallback: tokens.globalForeground);
    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(border: Border.all(color: tokens.panelBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: tokens.panelHeader,
              border: Border(bottom: BorderSide(color: tokens.panelBorder)),
            ),
            child: Row(
              children: [
                Container(width: 3, height: 13, color: accent),
                const SizedBox(width: 6),
                ClideText(member.name, fontSize: clideFontSmall, color: accent, fontFamily: clideMonoFamily),
                const SizedBox(width: 8),
                Expanded(
                  child: ClideText(
                    [member.agentType, if (member.model != null) member.model!].join(' · '),
                    fontSize: clideFontSmall,
                    muted: true,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            // Re-fold live with the activity fold-level setting (T-235).
            child: ListenableBuilder(
              listenable: ClideKernel.of(context).settings,
              builder: (ctx, _) => ConversationView(
                controller: controller,
                wrapInSelectionArea: false,
                foldLevel: foldLevelFromName(ClideKernel.of(ctx).settings.get<String>(kActivityFoldLevelKey)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Map a Claude Code team member colour name to a display [Color]. These
/// are CC-assigned identity colours (named strings), so they're fixed
/// constants here rather than theme tokens.
Color teamColor(String? name, {required Color fallback}) {
  switch (name) {
    case 'red':
      return const Color(0xFFE06C75);
    case 'orange':
      return const Color(0xFFD97757);
    case 'yellow':
      return const Color(0xFFE5C07B);
    case 'green':
      return const Color(0xFF98C379);
    case 'cyan':
      return const Color(0xFF56B6C2);
    case 'blue':
      return const Color(0xFF61AFEF);
    case 'magenta':
    case 'purple':
      return const Color(0xFFC678DD);
    case 'pink':
      return const Color(0xFFE39EC1);
    default:
      return fallback;
  }
}
