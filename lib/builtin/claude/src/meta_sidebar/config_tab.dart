/// The Config tab (T-183): the pinned settings table over [ClaudeConfig]
/// plus the skills/agents/commands/hooks/permissions/MCP accordion.
/// Split out of claude_meta_sidebar.dart (T-395). The accordion's
/// expansion state lives in the parent (it survives tab switches) and
/// arrives as a prop + toggle callback.
library;

import 'package:clide/builtin/claude/src/claude_config.dart';
import 'package:clide/builtin/claude/src/claude_status.dart' show permissionModeLabel;
import 'package:clide/builtin/claude/src/meta_sidebar/models.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class ConfigTabView extends StatelessWidget {
  const ConfigTabView({super.key, required this.config, required this.expanded, required this.onToggleSection});

  final ClaudeConfig? config;

  /// Sections currently expanded — owned by the parent state.
  final Set<ConfigSection> expanded;
  final void Function(ConfigSection section) onToggleSection;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final cfg = config;
    if (cfg == null) {
      return metaPlaceholder('Claude environment not loaded.');
    }
    final settings = cfg.settings;
    final model = cfg.probe?.model ?? settings['model']?.toString() ?? '—';
    final outputStyle = settings['outputStyle']?.toString() ?? 'default';
    final mode = cfg.probe?.permissionMode ?? settings['permissionMode']?.toString() ?? 'default';

    final children = <Widget>[
      // Pinned SETTINGS table — not collapsible.
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: ClideText('SETTINGS', fontSize: clideFontSmall, color: tokens.globalTextMuted),
      ),
      _configRow(tokens, 'model', model, valueColor: tokens.globalFocus),
      _configRow(tokens, 'output style', outputStyle),
      _configRow(tokens, 'permission mode', permissionModeLabel(mode)),
      _configRow(tokens, 'source', '~/.claude + .claude'),

      // ---- Accordion sections ----
      for (final section in ConfigSection.values) _accordion(context, tokens, cfg, section),

      // Footer hint.
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: ClideText('expand a list to see all · click a skill/agent/command → opens its .md', muted: true, fontSize: clideFontSmall),
      ),
    ];

    return ListView(padding: const EdgeInsets.all(12), children: children);
  }

  /// One key→value row in the pinned SETTINGS table.
  Widget _configRow(SurfaceTokens tokens, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kMetaRowPitch),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: kMetaLabelColumnWidth,
            child: ClideText(label, muted: true, fontSize: clideFontSmall),
          ),
          Expanded(
            child: ClideText(value, fontSize: clideFontSmall, color: valueColor ?? tokens.globalForeground),
          ),
        ],
      ),
    );
  }

  String _sectionLabel(ConfigSection section) => switch (section) {
    ConfigSection.skills => 'SKILLS',
    ConfigSection.agents => 'AGENTS',
    ConfigSection.commands => 'COMMANDS',
    ConfigSection.hooks => 'HOOKS',
    ConfigSection.permissions => 'PERMISSIONS',
    ConfigSection.mcpServers => 'MCP SERVERS',
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
      label: _sectionLabel(section),
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
        return _permissionRows(tokens, config.permissions);
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
  List<Widget> _permissionRows(SurfaceTokens tokens, ClaudePermissions perms) {
    // allow → statusSuccess, ask → statusWarning, deny → statusError
    Color kindColor(ConfigPermKind k) => switch (k) {
      ConfigPermKind.allow => tokens.statusSuccess,
      ConfigPermKind.ask => tokens.statusWarning,
      ConfigPermKind.deny => tokens.statusError,
    };

    String kindLabel(ConfigPermKind k) => switch (k) {
      ConfigPermKind.allow => 'allow',
      ConfigPermKind.ask => 'ask',
      ConfigPermKind.deny => 'deny',
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
