import 'package:clide/extension/extension.dart';

/// Tier-reserved stub. Will surface a sidebar tab with sub-tabs
/// Settings / Skills / Agents / Hooks / MCP — `.claude/` as a
/// first-class IDE surface. Orthogonal to pql; purely clide-internal.
/// Commands: `claude.settings.open`, `claude.skills.new`,
/// `claude.skills.edit`, `claude.agents.new`, `claude.agents.edit`,
/// `claude.hooks.log`, `claude.mcp.status`.
///
/// Distinct from `builtin.claude`, which is reserved for Tier 1's
/// "run Claude Code in a PTY pane."
class ClaudeControlExtension extends ClideExtension {
  @override
  String get id => 'builtin.claude-control';
  @override
  String get title => 'Claude control';
  @override
  String get version => '0.0.0-stub';
  @override
  List<String> get dependsOn => const [];
  @override
  List<ContributionPoint> get contributions => const [];
}
