/// A single agent roster row: color dot + name + status sub-text +
/// controls (T-171). Split out of claude_meta_sidebar.dart (T-395).
///
/// Controls (trailing region):
/// - permission-mode badge (T-181) — D/A/P cycles the safe trio; shift-click
///   reaches bypassPermissions behind a confirm
/// - eye / eye-slash — show / hide the session pane
/// - speaker / speaker-slash — mute / unmute broker delivery
/// - inject (chat icon) — expand the inline message input
/// - fork (git-branch icon) — open a new pane branching from this session (T-172)
/// - close (×) — kill the session
library;

import 'package:clide/builtin/claude/src/claude_status.dart' show formatTokenCount, permissionModeLabel, shortModelLabel;
import 'package:clide/builtin/claude/src/meta_sidebar/icon_button.dart';
import 'package:clide/builtin/claude/src/meta_sidebar/inject_field.dart';
import 'package:clide/builtin/claude/src/meta_sidebar/permission_badge.dart';
import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/team_panel_host.dart' show teamColor;
import 'package:clide/builtin/claude/src/transcript_reader.dart' show SessionStatus;
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class AgentRosterRow extends StatefulWidget {
  const AgentRosterRow({
    super.key,
    required this.member,
    required this.status,
    required this.orchestrator,
    required this.injectingAgentId,
    required this.injectController,
    required this.onToggleInject,
    required this.onInjectSubmit,
    required this.onClose,
    required this.onSetPermissionMode,
    required this.onFork,
  });

  final TeamMemberJoined member;
  final SessionStatus? status;
  final ClaudeSessionOrchestrator? orchestrator;

  /// The member name currently in inject mode (null = none).
  final String? injectingAgentId;

  /// Shared text controller for the inject field (cleared on submit/cancel).
  final TextEditingController injectController;

  final void Function(String memberName) onToggleInject;
  final void Function(String memberName, String text) onInjectSubmit;
  final void Function(String memberName) onClose;

  /// Called when the badge cycles to a new `mode` string for this member.
  /// Handles both safe-trio clicks and confirmed bypass. The parent sends
  /// the mode to the session via `StreamJsonSession.setPermissionMode`.
  final void Function(String memberName, String mode) onSetPermissionMode;

  /// Called when the fork button is tapped (T-172). The session id of the
  /// member's managed session is passed so the host can open a fork pane.
  final void Function(String memberName) onFork;

  @override
  State<AgentRosterRow> createState() => _AgentRosterRowState();
}

class _AgentRosterRowState extends State<AgentRosterRow> {
  /// Whether the bypass-confirm inline prompt is showing.
  bool _confirmingBypass = false;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final managed = widget.orchestrator?.byMemberName(widget.member.name);
    final color = teamColor(widget.member.color, fallback: tokens.globalForeground);
    final st = widget.status;
    final model = st?.model ?? widget.member.model;
    final sub = [
      widget.member.agentType,
      if (model != null) shortModelLabel(model),
      if (st?.permissionMode != null) permissionModeLabel(st!.permissionMode!),
      if (st?.contextTokens != null) '${formatTokenCount(st!.contextTokens!)} ctx',
    ].join('  ·  ');

    final isVisible = managed?.visible ?? true;
    final isMuted = managed?.muted ?? false;
    final isInjecting = widget.injectingAgentId == widget.member.name;
    final currentMode = st?.permissionMode ?? 'default';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Color dot
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 8),
              // Name + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClideText(widget.member.name, fontSize: clideFontSmall, color: tokens.globalForeground, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (sub.isNotEmpty) ClideText(sub, muted: true, fontSize: clideFontSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    // T-181: permission-mode badge (inline below the status sub-text).
                    if (managed != null)
                      PermissionModeBadge(
                        mode: currentMode,
                        tokens: tokens,
                        onCycle: () {
                          final next = _nextSafeMode(currentMode);
                          widget.onSetPermissionMode(widget.member.name, next);
                        },
                        onBypass: () => setState(() => _confirmingBypass = true),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Trailing controls (T-171).
              // T-172 seam: append a fork icon button to this row.
              if (managed != null) _buildControls(context, tokens, managed, isVisible, isMuted, isInjecting),
            ],
          ),
          // Bypass confirm: replaces inject field area when active.
          if (_confirmingBypass) _buildBypassConfirm(tokens),
          // Inline inject-message field — visible only when toggled.
          if (isInjecting && !_confirmingBypass) _buildInjectField(context, tokens),
        ],
      ),
    );
  }

  /// Safe-mode cycle: default → acceptEdits → plan → default (T-181).
  static String _nextSafeMode(String current) {
    const cycle = ['default', 'acceptEdits', 'plan'];
    final idx = cycle.indexOf(current);
    return cycle[(idx + 1) % cycle.length];
  }

  Widget _buildBypassConfirm(SurfaceTokens tokens) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 4),
      child: Row(
        children: [
          Expanded(
            child: ClideText(
              ClideSettings.i18n.string(
                context,
                'roster.bypass.confirmBody',
                namespace: 'builtin.claude',
                placeholder: 'Enable bypassPermissions? All tool calls will be auto-allowed.',
              ),
              fontSize: clideFontSmall,
              color: tokens.globalTextMuted,
            ),
          ),
          const SizedBox(width: 4),
          // Confirm
          Semantics(
            button: true,
            label: ClideSettings.i18n.string(context, 'roster.bypass.confirm.semantics', namespace: 'builtin.claude', placeholder: 'Confirm bypass'),
            excludeSemantics: true,
            onTap: () {
              setState(() => _confirmingBypass = false);
              widget.onSetPermissionMode(widget.member.name, 'bypassPermissions');
            },
            child: ClideTappable(
              tooltip: ClideSettings.i18n.string(context, 'roster.bypass.confirm.tooltip', namespace: 'builtin.claude', placeholder: 'Confirm'),
              onTap: () {
                setState(() => _confirmingBypass = false);
                widget.onSetPermissionMode(widget.member.name, 'bypassPermissions');
              },
              builder: (ctx, hovered, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                child: ClideText(
                  ClideSettings.i18n.string(context, 'roster.bypass.ok', namespace: 'builtin.claude', placeholder: 'OK'),
                  fontSize: clideFontSmall,
                  color: hovered ? tokens.globalForeground : tokens.globalFocus,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Cancel
          Semantics(
            button: true,
            label: ClideSettings.i18n.string(context, 'roster.bypass.cancel.semantics', namespace: 'builtin.claude', placeholder: 'Cancel bypass'),
            excludeSemantics: true,
            onTap: () => setState(() => _confirmingBypass = false),
            child: ClideTappable(
              tooltip: ClideSettings.i18n.string(context, 'roster.bypass.cancel.tooltip', namespace: 'builtin.claude', placeholder: 'Cancel'),
              onTap: () => setState(() => _confirmingBypass = false),
              builder: (ctx, hovered, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                child: ClideText(
                  ClideSettings.i18n.string(context, 'roster.bypass.cancel', namespace: 'builtin.claude', placeholder: 'Cancel'),
                  fontSize: clideFontSmall,
                  color: hovered ? tokens.globalForeground : tokens.globalTextMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context, SurfaceTokens tokens, ManagedSession managed, bool isVisible, bool isMuted, bool isInjecting) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Show / hide
        MetaIconButton(
          painter: isVisible ? PhosphorIcons.byName('eye') : PhosphorIcons.byName('eye-slash'),
          tooltip: isVisible
              ? ClideSettings.i18n.string(context, 'roster.hidePane', namespace: 'builtin.claude', placeholder: 'Hide pane')
              : ClideSettings.i18n.string(context, 'roster.showPane', namespace: 'builtin.claude', placeholder: 'Show pane'),
          color: tokens.globalTextMuted,
          onTap: () => isVisible ? widget.orchestrator!.hide(managed.id) : widget.orchestrator!.show(managed.id),
        ),
        // Mute / unmute
        MetaIconButton(
          painter: isMuted ? PhosphorIcons.byName('eye-slash') : PhosphorIcons.byName('eye'),
          // NOTE: We use eye/eyeSlash as stand-ins until a dedicated speaker
          // icon is added to PhosphorIcons (no speaker codepoint yet).
          // The semantic tooltip still says mute/unmute so AT users are clear.
          tooltip: isMuted
              ? ClideSettings.i18n.string(context, 'roster.unmute', namespace: 'builtin.claude', placeholder: 'Unmute messages')
              : ClideSettings.i18n.string(context, 'roster.mute', namespace: 'builtin.claude', placeholder: 'Mute messages'),
          color: isMuted ? tokens.globalFocus : tokens.globalTextMuted,
          onTap: () => isMuted ? widget.orchestrator!.unmute(managed.id) : widget.orchestrator!.mute(managed.id),
        ),
        // Inject message
        MetaIconButton(
          painter: PhosphorIcons.byName('chat-circle'),
          tooltip: ClideSettings.i18n.string(context, 'roster.inject', namespace: 'builtin.claude', placeholder: 'Inject message'),
          color: isInjecting ? tokens.globalFocus : tokens.globalTextMuted,
          onTap: () => widget.onToggleInject(widget.member.name),
        ),
        // Fork session (T-172): branch into a new pane without touching the original.
        MetaIconButton(
          painter: PhosphorIcons.byName('git-branch'),
          tooltip: ClideSettings.i18n.string(context, 'roster.fork', namespace: 'builtin.claude', placeholder: 'Fork session'),
          color: tokens.globalTextMuted,
          onTap: () => widget.onFork(widget.member.name),
        ),
        // Close session
        MetaIconButton(
          painter: PhosphorIcons.byName('x'),
          tooltip: ClideSettings.i18n.string(context, 'roster.close', namespace: 'builtin.claude', placeholder: 'Close session'),
          color: tokens.globalTextMuted,
          onTap: () => widget.onClose(widget.member.name),
        ),
      ],
    );
  }

  Widget _buildInjectField(BuildContext context, SurfaceTokens tokens) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 4),
      child: Row(
        children: [
          Expanded(
            child: InjectTextField(
              controller: widget.injectController,
              tokens: tokens,
              onSubmit: (text) {
                if (text.trim().isNotEmpty) widget.onInjectSubmit(widget.member.name, text.trim());
              },
            ),
          ),
          const SizedBox(width: 4),
          MetaIconButton(
            painter: PhosphorIcons.byName('x'),
            tooltip: ClideSettings.i18n.string(context, 'roster.inject.cancel', namespace: 'builtin.claude', placeholder: 'Cancel'),
            color: tokens.globalTextMuted,
            onTap: () => widget.onToggleInject(widget.member.name),
          ),
        ],
      ),
    );
  }
}
