/// The Config tab (T-183): the settings table over [ClaudeConfig] plus the
/// skills/agents/commands/hooks/permissions/MCP accordion. Split out of
/// claude_meta_sidebar.dart (T-395). The accordion's expansion state lives in
/// the parent (it survives tab switches) and arrives as a prop + toggle
/// callback.
///
/// T-414 makes the settings table a control panel: model / effort /
/// permission-mode rows are live popover controls. Picking an option
/// publishes the explicit slash command (`/model sonnet`) on the
/// `builtin.claude`/`command` channel; the primary Claude pane executes it
/// through the same `_send` routing the composer uses — one implementation,
/// two surfaces (D-6).
library;

import 'package:clide/builtin/claude/src/claude_config.dart';
import 'package:clide/builtin/claude/src/claude_status.dart' show permissionModeLabel;
import 'package:clide/builtin/claude/src/meta_sidebar/models.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart' show ModelOption, kEffortLevels, kFallbackModels, kPermissionModes;
import 'package:clide/builtin/claude/src/transcript_reader.dart' show SessionStatus;
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class ConfigTabView extends StatelessWidget {
  const ConfigTabView({super.key, required this.config, required this.expanded, required this.onToggleSection, this.status, this.models});

  final ClaudeConfig? config;

  /// The primary session's live status — drives the control rows' current
  /// values. Null before the session reports (controls fall back to the
  /// probe/settings values).
  final SessionStatus? status;

  /// Models selectable for the primary session (from its `initialize`
  /// response); falls back to [kFallbackModels].
  final List<ModelOption>? models;

  /// Sections currently expanded — owned by the parent state.
  final Set<ConfigSection> expanded;
  final void Function(ConfigSection section) onToggleSection;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final cfg = config;
    if (cfg == null) {
      return metaPlaceholder(ClideSettings.i18n.string(context, 'config.empty', namespace: 'builtin.claude', placeholder: 'Claude environment not loaded.'));
    }
    final settings = cfg.settings;
    final model = status?.model ?? cfg.probe?.model ?? settings['model']?.toString() ?? 'default';
    final outputStyle = settings['outputStyle']?.toString() ?? 'default';
    final mode = status?.permissionMode ?? cfg.probe?.permissionMode ?? settings['permissionMode']?.toString() ?? 'default';
    final effort = status?.effort ?? settings['effortLevel']?.toString() ?? 'default';

    final children = <Widget>[
      // Pinned SETTINGS control panel — not collapsible. Carded to match the
      // settings overlay (T-158 facelift).
      metaSectionHeader(context, tokens, ClideSettings.i18n.string(context, 'config.section.settings', namespace: 'builtin.claude', placeholder: 'SETTINGS')),
      metaCard(tokens, [
        SettingControlRow(
          label: ClideSettings.i18n.string(context, 'config.row.model', namespace: 'builtin.claude', placeholder: 'model'),
          value: model,
          valueColor: tokens.globalFocus,
          options: (models == null || models!.isEmpty) ? kFallbackModels : models!,
          isActive: (o) => o.value == model || model.toLowerCase().contains(o.value.toLowerCase()),
          command: 'model',
        ),
        SettingControlRow(
          label: ClideSettings.i18n.string(context, 'config.row.effort', namespace: 'builtin.claude', placeholder: 'effort'),
          value: effort,
          options: kEffortLevels,
          isActive: (o) => o.value == effort,
          command: 'effort',
        ),
        SettingControlRow(
          label: ClideSettings.i18n.string(context, 'config.row.permissionMode', namespace: 'builtin.claude', placeholder: 'permission mode'),
          value: permissionModeLabel(mode),
          options: kPermissionModes,
          isActive: (o) => o.value == mode,
          command: 'permissions',
        ),
        _configRow(tokens, ClideSettings.i18n.string(context, 'config.row.outputStyle', namespace: 'builtin.claude', placeholder: 'output style'), outputStyle),
        _configRow(
          tokens,
          ClideSettings.i18n.string(context, 'config.row.source', namespace: 'builtin.claude', placeholder: 'source'),
          ClideSettings.i18n.string(context, 'config.row.source.value', namespace: 'builtin.claude', placeholder: '~/.claude + .claude'),
        ),
      ]),
      const SizedBox(height: 12),

      // ---- Accordion sections ----
      for (final section in ConfigSection.values) _accordion(context, tokens, cfg, section),

      // Footer hint.
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: ClideText(
          ClideSettings.i18n.string(
            context,
            'config.footer',
            namespace: 'builtin.claude',
            placeholder: 'expand a list to see all · click a skill/agent/command → opens its .md',
          ),
          muted: true,
          fontSize: clideFontSmall,
        ),
      ),
    ];

    return ListView(padding: const EdgeInsets.all(12), children: children);
  }

  /// One read-only key→value row in the pinned SETTINGS table.
  Widget _configRow(SurfaceTokens tokens, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: kMetaLabelColumnWidth,
            child: ClideText(label, muted: true, fontSize: kMetaFont),
          ),
          Expanded(
            child: ClideText(value, fontSize: kMetaFont, color: valueColor ?? tokens.globalForeground),
          ),
        ],
      ),
    );
  }

  String _sectionLabel(BuildContext context, ConfigSection section) => switch (section) {
    ConfigSection.skills => ClideSettings.i18n.string(context, 'config.section.skills', namespace: 'builtin.claude', placeholder: 'SKILLS'),
    ConfigSection.agents => ClideSettings.i18n.string(context, 'config.section.agents', namespace: 'builtin.claude', placeholder: 'AGENTS'),
    ConfigSection.commands => ClideSettings.i18n.string(context, 'config.section.commands', namespace: 'builtin.claude', placeholder: 'COMMANDS'),
    ConfigSection.hooks => ClideSettings.i18n.string(context, 'config.section.hooks', namespace: 'builtin.claude', placeholder: 'HOOKS'),
    ConfigSection.permissions => ClideSettings.i18n.string(context, 'config.section.permissions', namespace: 'builtin.claude', placeholder: 'PERMISSIONS'),
    ConfigSection.mcpServers => ClideSettings.i18n.string(context, 'config.section.mcpServers', namespace: 'builtin.claude', placeholder: 'MCP SERVERS'),
  };

  int _sectionCount(ClaudeConfig config, ConfigSection section) => switch (section) {
    ConfigSection.skills => config.skills.length,
    ConfigSection.agents => config.agents.length,
    ConfigSection.commands => config.commands.length,
    ConfigSection.hooks => config.hooks.length,
    ConfigSection.permissions => config.permissions.allow.length + config.permissions.deny.length + config.permissions.ask.length,
    ConfigSection.mcpServers => config.mcpServers.length,
  };

  Widget _accordion(BuildContext context, SurfaceTokens tokens, ClaudeConfig config, ConfigSection section) {
    final isExpanded = expanded.contains(section);
    final children = isExpanded ? _sectionChildren(context, tokens, config, section) : const <Widget>[];
    return ClideAccordion(
      label: _sectionLabel(context, section),
      count: _sectionCount(config, section),
      expanded: isExpanded,
      onToggle: () => onToggleSection(section),
      children: children,
    );
  }

  List<Widget> _sectionChildren(BuildContext context, SurfaceTokens tokens, ClaudeConfig config, ConfigSection section) {
    switch (section) {
      case ConfigSection.skills:
        return [for (final skill in config.skills) _fileRow(context, tokens, skill.name, skill.path)];
      case ConfigSection.agents:
        return [for (final agent in config.agents) _fileRow(context, tokens, agent.name, agent.path)];
      case ConfigSection.commands:
        return [for (final cmd in config.commands) _fileRow(context, tokens, cmd.name, cmd.path)];
      case ConfigSection.hooks:
        return [
          for (final hook in config.hooks)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 2, bottom: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClideText(hook.event, fontSize: clideFontSmall, color: tokens.sidebarSectionHeader),
                  for (final cmd in hook.commands)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 1),
                      child: ClideText(cmd, fontSize: clideFontSmall, muted: true),
                    ),
                ],
              ),
            ),
        ];
      case ConfigSection.permissions:
        return _permissionRows(context, tokens, config.permissions);
      case ConfigSection.mcpServers:
        return [
          for (final srv in config.mcpServers)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 2, bottom: 2),
              child: ClideText(srv.name, fontSize: clideFontSmall, color: tokens.globalForeground),
            ),
        ];
    }
  }

  /// A tappable row for file-backed items (skills, agents, commands).
  /// All config items are .md files — opens in the markdown reader panel
  /// via the kernel MessageBus (D-6, T-183).
  Widget _fileRow(BuildContext context, SurfaceTokens tokens, String name, String? path) {
    final row = Padding(
      padding: const EdgeInsets.only(left: 16, top: 2, bottom: 2),
      child: ClideText(name, fontSize: clideFontSmall, color: path != null ? tokens.globalFocus : tokens.globalForeground),
    );
    if (path == null) return row;
    void openMarkdown() => ClideKernel.of(context).messages.publish('builtin.markdown', 'selection', {'path': path});
    return Semantics(
      button: true,
      label: name,
      excludeSemantics: true,
      onTap: openMarkdown,
      child: ClideTappable(
        tooltip: path,
        onTap: openMarkdown,
        builder: (ctx, hovered, _) => Padding(
          padding: const EdgeInsets.only(left: 16, top: 2, bottom: 2),
          child: ClideText(name, fontSize: clideFontSmall, color: hovered ? tokens.globalForeground : tokens.globalFocus),
        ),
      ),
    );
  }

  /// Renders grouped allow/ask/deny permission rows, colour-coded by kind.
  List<Widget> _permissionRows(BuildContext context, SurfaceTokens tokens, ClaudePermissions perms) {
    // allow → statusSuccess, ask → statusWarning, deny → statusError
    Color kindColor(ConfigPermKind k) => switch (k) {
      ConfigPermKind.allow => tokens.statusSuccess,
      ConfigPermKind.ask => tokens.statusWarning,
      ConfigPermKind.deny => tokens.statusError,
    };

    String kindLabel(ConfigPermKind k) => switch (k) {
      ConfigPermKind.allow => ClideSettings.i18n.string(context, 'config.perm.allow', namespace: 'builtin.claude', placeholder: 'allow'),
      ConfigPermKind.ask => ClideSettings.i18n.string(context, 'config.perm.ask', namespace: 'builtin.claude', placeholder: 'ask'),
      ConfigPermKind.deny => ClideSettings.i18n.string(context, 'config.perm.deny', namespace: 'builtin.claude', placeholder: 'deny'),
    };

    final groups = [(ConfigPermKind.allow, perms.allow), (ConfigPermKind.ask, perms.ask), (ConfigPermKind.deny, perms.deny)];

    final rows = <Widget>[];
    for (final (kind, rules) in groups) {
      if (rules.isEmpty) continue;
      final color = kindColor(kind);
      rows.add(
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 36,
                child: ClideText(kindLabel(kind), fontSize: clideFontSmall, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final rule in rules)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: ClideText(rule, fontSize: clideFontSmall, color: tokens.globalForeground),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return rows;
  }
}

/// One live setting row (T-414): label + current value as a popover control on
/// the owned anchored-menu primitive. Picking an option publishes the explicit
/// slash command on `builtin.claude`/`command`; the primary Claude pane
/// executes it through its normal `_send` routing — so the sidebar control and
/// the typed command are literally the same code path (D-6).
class SettingControlRow extends StatefulWidget {
  const SettingControlRow({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.isActive,
    required this.command,
    this.valueColor,
  });

  final String label;

  /// Current value, displayed on the trigger.
  final String value;
  final Color? valueColor;

  final List<ModelOption> options;
  final bool Function(ModelOption option) isActive;

  /// The slash-command token this control drives (`model`, `effort`,
  /// `permissions`); a pick publishes `/<command> <option.value>`.
  final String command;

  @override
  State<SettingControlRow> createState() => _SettingControlRowState();
}

class _SettingControlRowState extends State<SettingControlRow> {
  final ClideOverlayController _overlay = ClideOverlayController();

  void _pick(String value) {
    ClideKernel.of(context).messages.publish('builtin.claude', 'command', {'text': '/${widget.command} $value'});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: kMetaLabelColumnWidth,
            child: ClideText(widget.label, muted: true, fontSize: kMetaFont),
          ),
          Expanded(
            child: ClideAnchoredOverlay(
              controller: _overlay,
              align: ClideAnchorAlign.start,
              overlayBuilder: (ctx, c) => ClideMenu(
                onClose: c.close,
                entries: [
                  for (final o in widget.options)
                    ClideMenuItem(
                      label: o.description.isEmpty ? o.displayName : '${o.displayName} — ${o.description}',
                      active: widget.isActive(o),
                      semanticLabel: ClideSettings.i18n.interpolated(
                        context,
                        'config.control.option.semantics',
                        namespace: 'builtin.claude',
                        placeholder: '${widget.label}: ${o.displayName}',
                        replacers: [
                          I18nReplacer(from: '{label}', replace: widget.label),
                          I18nReplacer(from: '{name}', replace: o.displayName),
                        ],
                      ),
                      onSelect: () => _pick(o.value),
                    ),
                ],
              ),
              anchor: Semantics(
                button: true,
                label: ClideSettings.i18n.interpolated(
                  context,
                  'config.control.semantics',
                  namespace: 'builtin.claude',
                  placeholder: '${widget.label}: ${widget.value}. Click to change.',
                  replacers: [
                    I18nReplacer(from: '{label}', replace: widget.label),
                    I18nReplacer(from: '{value}', replace: widget.value),
                  ],
                ),
                excludeSemantics: true,
                onTap: _overlay.toggle,
                child: ClideTappable(
                  tooltip: ClideSettings.i18n.interpolated(
                    context,
                    'config.control.tooltip',
                    namespace: 'builtin.claude',
                    placeholder: 'change ${widget.label}',
                    replacers: [I18nReplacer(from: '{label}', replace: widget.label)],
                  ),
                  onTap: _overlay.toggle,
                  builder: (ctx, hovered, _) => DecoratedBox(
                    decoration: BoxDecoration(color: hovered ? tokens.listItemHoverBackground : null, borderRadius: BorderRadius.circular(4)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: ClideText(widget.value, fontSize: kMetaFont, color: widget.valueColor ?? tokens.globalForeground, maxLines: 1),
                          ),
                          const SizedBox(width: 4),
                          ClideIcon(PhosphorIcons.byName('caret-down'), size: 10, color: hovered ? tokens.globalForeground : tokens.globalTextMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
