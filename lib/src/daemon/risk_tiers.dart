/// Risk tiers for every clide command (D-115).
///
/// Every command the dispatcher registers has exactly one tier, and this
/// table is where they live: one file answers "what can an agent do without
/// asking?". [DaemonDispatcher.register] refuses a command that has no tier
/// here and wasn't given one explicitly, so a new verb can't ship
/// unclassified.
///
/// - **observe** — reads IDE or workspace state; no side effects.
/// - **display** — changes only what the user sees.
/// - **workspaceWrite** — changes workspace files through the confined
///   resolvers.
/// - **escalate** — can run code, reach outside the workspace, or change
///   what is trusted.
///
/// Agents are pre-approved for observe and display only (the Claude allow
/// rules are generated from this table). workspaceWrite goes through
/// Claude's own permission prompt; escalate is confirmed inside clide.
///
/// Flutter-free: the daemon side runs under plain `dart test`.
library;

enum RiskTier {
  observe('observe'),
  display('display'),
  workspaceWrite('workspace-write'),
  escalate('escalate');

  const RiskTier(this.wireName);

  /// The tier's name on the wire (`clide capabilities`) and in docs.
  final String wireName;

  /// Whether agents run this tier without any prompt.
  bool get preApproved => this == observe || this == display;
}

/// A command's risk: one [tier], unless the command's first positional
/// `action` argument picks a different one (`claude account list` only
/// reads; `claude account set` changes the session's account).
class CommandRisk {
  const CommandRisk(this.tier, {this.byAction = const {}});

  /// The tier for the command, and for any action not in [byAction].
  final RiskTier tier;

  /// Tier overrides keyed by the request's `action` argument.
  final Map<String, RiskTier> byAction;

  /// The tier a request with [args] runs under.
  RiskTier tierFor(Map<String, Object?> args) {
    final action = args['action'];
    if (action is String) return byAction[action.trim()] ?? tier;
    return tier;
  }

  /// Every tier this command can run under.
  Set<RiskTier> get tiers => {tier, ...byAction.values};
}

const _observe = CommandRisk(RiskTier.observe);
const _display = CommandRisk(RiskTier.display);
const _write = CommandRisk(RiskTier.workspaceWrite);
const _escalate = CommandRisk(RiskTier.escalate);

/// The tier of every command clide registers. Keep it sorted by command.
const Map<String, CommandRisk> commandRiskTiers = {
  // Transport: the C client's raw-argv envelope. The inner command it
  // re-dispatches is checked under its own tier.
  '_argv': _observe,

  'app.quit': _escalate, // closes every running pane and session
  'app.update': _escalate, // downloads and installs a new build
  'canvas.add-note': _write,
  'canvas.add-text': _write,
  'canvas.connect': _write,
  'canvas.delete': _write,
  'canvas.list': _observe,
  'canvas.move': _write,
  'canvas.resize': _write,
  'capabilities': _observe,
  'claude.account': CommandRisk(RiskTier.escalate, byAction: {'list': RiskTier.observe}),
  'claude.restore': _escalate, // spawns Claude sessions
  'clipboard.history': _escalate, // the user's copied data, outside the workspace
  'clipboard.set': _display,
  'draw': _display,
  'editor.activate': _display,
  'editor.active': _observe,
  'editor.close': _display,
  'editor.goto-line': _display,
  'editor.insert': _write,
  'editor.list': _observe,
  'editor.open': _display,
  'editor.read': _observe,
  'editor.replace-selection': _write,
  'editor.save': _write,
  'editor.set-content': _write,
  'editor.set-selection': _display,
  'env.path': CommandRisk(RiskTier.escalate, byAction: {'list': RiskTier.observe}),
  'files.ls': _observe,
  'files.read': _observe,
  'files.root': _observe,
  'files.walk': _observe,
  'files.watch': _observe,
  'files.write': _write,
  'git.branches': _observe,
  'git.checkout': _escalate,
  'git.commit': _write,
  'git.diff': _observe,
  'git.discard': _escalate, // destroys uncommitted work
  'git.log': _observe,
  'git.pull': _escalate, // brings in remote code
  'git.push': _escalate, // sends code off the machine
  'git.stage': _write,
  'git.stage-all': _write,
  'git.stage-hunk': _write,
  'git.stash': _write,
  'git.stash-pop': _write,
  'git.status': _observe,
  'git.unstage': _write,
  'git.unstage-hunk': _write,
  'icon.show': _display,
  'image.show': _display,
  'instance': _observe,
  'log.level': _display,
  'pane.close': _escalate, // own panes are free (D-115)
  'pane.focus': _display,
  'pane.list': _observe,
  'pane.resize': _display,
  'pane.spawn': _escalate,
  'pane.tail': _observe,
  'pane.write': _escalate, // own panes are free (D-115)
  'panel.resize': _display,
  'ping': _observe,
  'pql.backlinks': _observe,
  'pql.decisions.list': _observe,
  'pql.decisions.read': _observe,
  'pql.decisions.show': _observe,
  'pql.decisions.sync': _observe, // refreshes pql's derived index only
  'pql.doctor': _observe,
  'pql.files': _observe,
  'pql.meta': _observe,
  'pql.outlinks': _observe,
  'pql.plan.status': _observe,
  'pql.query': _observe,
  'pql.schema': _observe,
  'pql.search': _observe,
  'pql.tags': _observe,
  'pql.tickets.board': _observe,
  'pql.tickets.list': _observe,
  'pql.tickets.show': _observe,
  'pql.tickets.status': _write, // lands in the committed ticket changelog
  'project.init': _escalate,
  'project.new': _escalate,
  'search.cancel': _observe,
  'search.grep': _observe,
  'search.replace': _write,
  'status': _observe,
  'ui.filter': _display,
  'ui.open': _display,
  'ui.toast': _display,
  'version': _observe,
  'window.hide': _display,
  'window.show': _display,
};
