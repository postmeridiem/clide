import 'dart:async';

import 'package:clide/clide.dart' show clideName, clideTagline, clideVersion;
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/daemon/project_commands.dart' show projectCreatedChannel;
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter/widgets.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideSettings.theme.of(context).surface;
    return LayoutBuilder(
      builder: (context, c) {
        // Tips card sits below the START/RECENT row when there's room
        // for it; on shorter viewports the two centered columns win
        // and the tips drop out cleanly.
        final showTips = c.maxHeight > 640;
        return Stack(
          children: [
            // Scrollable so a short/narrow viewport (many recents, small window)
            // never overflows; minHeight keeps the content vertically centred
            // when there is room (T-273 follow-up — welcome RenderFlex overflow).
            Positioned.fill(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 850),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Header(tokens: tokens),
                          const SizedBox(height: 56),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _StartColumn(tokens: tokens, kernel: kernel),
                              ),
                              const SizedBox(width: 56),
                              Expanded(
                                child: _RecentColumn(tokens: tokens, kernel: kernel),
                              ),
                            ],
                          ),
                          if (showTips) ...[const SizedBox(height: 48), _TipsCard(tokens: tokens)],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 64,
              right: 64,
              bottom: 24,
              child: _StatusLine(tokens: tokens, kernel: kernel),
            ),
          ],
        );
      },
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard({required this.tokens});
  final SurfaceTokens tokens;

  // Every tip mirrors a binding that actually exists in the default
  // preset / contributed commands (T-383) — ctrl-based on the shipped
  // default keymap, hence ⌃ glyphs. If a binding moves, move the tip.
  // (catalog key, English label, shortcut glyph). The key/English pair resolves
  // through the i18n catalog at render (D-21); the glyph is not translated.
  static const _tips = <(String, String, String)>[
    ('tips.quickOpen', 'Quick open', '⌃P'),
    ('tips.commandPalette', 'Command palette', '⌃⇧P'),
    ('tips.toggleSidebar', 'Toggle sidebar', '⌃⇧1'),
    ('tips.toggleContext', 'Toggle context', '⌃⇧3'),
    ('tips.findInFiles', 'Find in files', '⌃⇧F'),
    ('tips.focusMode', 'Focus mode', '⌃.'),
  ];

  @override
  Widget build(BuildContext context) {
    // Split tips into two rows of three so the card lays out as a
    // 3-column grid matching the START/RECENT proportions above.
    final firstRow = _tips.sublist(0, 3);
    final secondRow = _tips.sublist(3);

    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: tokens.panelBackground,
          border: Border.all(color: tokens.panelBorder),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClideText(
              ClideSettings.i18n.string(context, 'section.tips', namespace: 'builtin.welcome', placeholder: 'TIPS'),
              fontSize: clideFontSmall,
              color: tokens.sidebarSectionHeader,
              fontFamily: ClideSettings.fonts.monoOf(context),
            ),
            const SizedBox(height: 14),
            _tipRow(context, firstRow, ClideSettings.fonts.monoOf(context)),
            const SizedBox(height: 8),
            _tipRow(context, secondRow, ClideSettings.fonts.monoOf(context)),
          ],
        ),
      ),
    );
  }

  Widget _tipRow(BuildContext context, List<(String, String, String)> tips, String mono) {
    return Row(
      children: [
        for (var i = 0; i < tips.length; i++) ...[
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ClideText(
                    ClideSettings.i18n.string(context, tips[i].$1, namespace: 'builtin.welcome', placeholder: tips[i].$2),
                    fontSize: clideFontMeta,
                    color: tokens.globalTextMuted,
                  ),
                ),
                ClideText(tips[i].$3, fontSize: clideFontSmall, color: tokens.globalForeground, fontFamily: mono),
              ],
            ),
          ),
          if (i < tips.length - 1) const SizedBox(width: 24),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.tokens});
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const ClideSvgView.asset('assets/logo/logo.svg', width: 144, height: 144),
        const SizedBox(width: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClideText(clideName, fontSize: clideFontWelcomeBanner, fontWeight: FontWeight.w300, color: tokens.globalForeground),
            ClideText(clideTagline, muted: true, fontSize: clideFontDialogTitle),
          ],
        ),
      ],
    );
  }
}

class _StartColumn extends StatelessWidget {
  const _StartColumn({required this.tokens, required this.kernel});
  final SurfaceTokens tokens;
  final KernelServices kernel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClideText(
          ClideSettings.i18n.string(context, 'section.start', namespace: 'builtin.welcome', placeholder: 'START'),
          fontSize: clideFontSmall,
          color: tokens.sidebarSectionHeader,
          fontFamily: ClideSettings.fonts.monoOf(context),
        ),
        const SizedBox(height: 20),
        // Only flows that exist get a tile — the old Clone-from-git and
        // Start-a-Claude-session rows were inert and advertised shortcuts
        // that were never registered (T-383). Re-add each WITH its flow.
        _ActionRow(
          icon: PhosphorIcons.byName('folder'),
          label: ClideSettings.i18n.string(context, 'action.openFolder', namespace: 'builtin.welcome', placeholder: 'Open folder…'),
          shortcut: '⌃O',
          tokens: tokens,
          onTap: () => _openFolder(context),
        ),
        _ActionRow(
          icon: PhosphorIcons.byName('folder-plus'),
          label: ClideSettings.i18n.string(context, 'action.newProject', namespace: 'builtin.welcome', placeholder: 'New project…'),
          tokens: tokens,
          onTap: () => _newProject(context),
        ),
      ],
    );
  }

  void _newProject(BuildContext context) {
    kernel.dialog.show<Object>((ctx, dismiss) => _NewProjectDialog(kernel: kernel, onClose: () => dismiss()));
  }

  void _openFolder(BuildContext context) async {
    try {
      final picked = await kernel.window.pickDirectory();
      if (picked != null) {
        final ok = await kernel.project.open(picked);
        if (ok) {
          kernel.panels.activateTab(Slots.workspace, 'claude.primary');
        } else {
          kernel.dialog.show((ctx, dismiss) => _NotARepoDialog(path: picked, onDismiss: () => dismiss()));
        }
      }
      return;
    } on MissingPluginException {
      // Platform has no native picker — fall through to text dialog.
    }

    kernel.dialog.show<String>((ctx, dismiss) {
      return _OpenProjectDialog(
        onOpen: (path) async {
          final ok = await kernel.project.open(path);
          if (ok) {
            kernel.panels.activateTab(Slots.workspace, 'claude.primary');
            dismiss(path);
          }
        },
        onCancel: () => dismiss(),
      );
    });
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, this.shortcut, required this.tokens, required this.onTap});
  final ClideIconPainter icon;
  final String label;
  final String? shortcut;
  final SurfaceTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClideTappable(
      onTap: onTap,
      builder: (context, hovered, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: hovered ? tokens.listItemHoverBackground : null, borderRadius: BorderRadius.circular(4)),
        child: Row(
          children: [
            ClideIcon(icon, size: 18, color: tokens.globalTextMuted),
            const SizedBox(width: 14),
            Expanded(
              child: ClideText(label, fontSize: clideFontBody, color: tokens.globalForeground),
            ),
            if (shortcut != null) ClideText(shortcut!, fontSize: clideFontMeta, color: tokens.globalTextMuted, fontFamily: ClideSettings.fonts.monoOf(context)),
          ],
        ),
      ),
    );
  }
}

class _RecentColumn extends StatelessWidget {
  const _RecentColumn({required this.tokens, required this.kernel});
  final SurfaceTokens tokens;
  final KernelServices kernel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: kernel.project,
      builder: (ctx, _) {
        final recents = kernel.project.recents;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClideText(
              ClideSettings.i18n.string(ctx, 'section.recent', namespace: 'builtin.welcome', placeholder: 'RECENT'),
              fontSize: clideFontSmall,
              color: tokens.sidebarSectionHeader,
              fontFamily: ClideSettings.fonts.monoOf(context),
            ),
            const SizedBox(height: 20),
            if (recents.isEmpty)
              ClideText(
                ClideSettings.i18n.string(ctx, 'recent.empty', namespace: 'builtin.welcome', placeholder: 'No recent projects.'),
                muted: true,
                fontSize: clideFontCaption,
              )
            else
              for (final r in recents)
                _RecentRow(
                  project: r,
                  tokens: tokens,
                  onTap: () => _openRecent(r.path),
                  onToggleSticky: () => kernel.project.setStickyStartup(r.path, !r.startupSticky),
                ),
          ],
        );
      },
    );
  }

  void _openRecent(String path) {
    kernel.project.open(path).then((ok) {
      if (ok) kernel.panels.activateTab(Slots.workspace, 'claude.primary');
    });
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.project, required this.tokens, required this.onTap, required this.onToggleSticky});
  final RecentProject project;
  final SurfaceTokens tokens;
  final VoidCallback onTap;
  final VoidCallback onToggleSticky;

  @override
  Widget build(BuildContext context) {
    return ClideTappable(
      onTap: onTap,
      builder: (context, hovered, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: hovered ? tokens.listItemHoverBackground : null, borderRadius: BorderRadius.circular(4)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClideText(project.name, fontSize: clideFontBody, fontWeight: FontWeight.w500),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: ClideText(
                          project.relativePath,
                          muted: true,
                          fontSize: clideFontMeta,
                          fontFamily: ClideSettings.fonts.monoOf(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (project.branch != null) ...[
                        ClideText('  ·  ', muted: true, fontSize: clideFontMeta),
                        ClideIcon(PhosphorIcons.byName('git-branch'), size: 11, color: tokens.globalTextMuted),
                        const SizedBox(width: 3),
                        Flexible(
                          child: ClideText(
                            project.branch!,
                            muted: true,
                            fontSize: clideFontMeta,
                            fontFamily: ClideSettings.fonts.monoOf(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            _StickyToggle(key: ValueKey('welcome.sticky.${project.path}'), sticky: project.startupSticky, tokens: tokens, onTap: onToggleSticky),
            const SizedBox(width: 12),
            ClideText(project.timeAgo, muted: true, fontSize: clideFontMeta),
          ],
        ),
      ),
    );
  }
}

/// Sticky-startup checkbox shown on each recent-project row (T-115).
/// When exactly one row is checked, clide opens that project on next
/// launch instead of showing the picker. Tooltip explains the rule.
class _StickyToggle extends StatelessWidget {
  const _StickyToggle({super.key, required this.sticky, required this.tokens, required this.onTap});
  final bool sticky;
  final SurfaceTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: sticky,
      label: ClideSettings.i18n.string(context, 'sticky.label', namespace: 'builtin.welcome', placeholder: 'always open this project on launch'),
      tooltip: sticky
          ? ClideSettings.i18n.string(
              context,
              'sticky.tooltip.active',
              namespace: 'builtin.welcome',
              placeholder: 'Always open this project on launch (uncheck to restore picker)',
            )
          : ClideSettings.i18n.string(context, 'sticky.tooltip', namespace: 'builtin.welcome', placeholder: 'Always open this project on launch'),
      child: ClideTappable(
        onTap: onTap,
        builder: (context, hovered, _) => Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: sticky ? tokens.statusBarItemActiveBackground : null,
            border: Border.all(color: hovered || sticky ? tokens.panelActiveBorder : tokens.globalBorder),
            borderRadius: BorderRadius.circular(3),
          ),
          child: sticky ? ClideIcon(PhosphorIcons.byName('check'), size: 12, color: tokens.buttonForeground) : null,
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.tokens, required this.kernel});
  final SurfaceTokens tokens;
  final KernelServices kernel;

  @override
  Widget build(BuildContext context) {
    final themeName = kernel.theme.currentName;
    return ListenableBuilder(
      listenable: kernel.toolchain,
      builder: (ctx, _) {
        final tc = kernel.toolchain;
        // FittedBox+scaleDown shrinks the row uniformly on narrow
        // viewports rather than overflowing — at standard widths it's
        // a no-op. The status line is decorative chrome; keep it on
        // one line by accepting a tiny font on very narrow screens.
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClideText('$clideName $clideVersion', muted: true, fontSize: clideFontSmall, fontFamily: ClideSettings.fonts.monoOf(context)),
              ClideText('  ·  ', muted: true, fontSize: clideFontSmall),
              if (!tc.resolved)
                ClideText(
                  ClideSettings.i18n.string(ctx, 'status.checking', namespace: 'builtin.welcome', placeholder: 'checking…'),
                  muted: true,
                  fontSize: clideFontSmall,
                  fontFamily: ClideSettings.fonts.monoOf(context),
                )
              else if (tc.allOk)
                ClideText(
                  ClideSettings.i18n.string(ctx, 'status.ok', namespace: 'builtin.welcome', placeholder: 'application ok'),
                  fontSize: clideFontSmall,
                  fontFamily: ClideSettings.fonts.monoOf(context),
                  color: tokens.statusSuccess,
                )
              else
                ClideText(
                  tc.missing
                      .map(
                        (t) => ClideSettings.i18n.interpolated(
                          ctx,
                          'status.notFound',
                          namespace: 'builtin.welcome',
                          placeholder: '{tool} not found',
                          replacers: [I18nReplacer(from: '{tool}', replace: t)],
                        ),
                      )
                      .join(' · '),
                  fontSize: clideFontSmall,
                  fontFamily: ClideSettings.fonts.monoOf(context),
                  color: tokens.statusWarning,
                ),
              ClideText('  ·  ', muted: true, fontSize: clideFontSmall),
              _ThemeLink(tokens: tokens, kernel: kernel, themeName: themeName),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeLink extends StatelessWidget {
  const _ThemeLink({required this.tokens, required this.kernel, required this.themeName});
  final SurfaceTokens tokens;
  final KernelServices kernel;
  final String themeName;

  @override
  Widget build(BuildContext context) {
    return ClideTappable(
      onTap: () => kernel.commands.execute('theme.pick'),
      builder: (ctx, hovered, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClideText(
            ClideSettings.i18n.string(ctx, 'status.theme', namespace: 'builtin.welcome', placeholder: 'theme: '),
            muted: true,
            fontSize: clideFontSmall,
            fontFamily: ClideSettings.fonts.monoOf(context),
          ),
          ClideText(
            themeName,
            fontSize: clideFontSmall,
            fontFamily: ClideSettings.fonts.monoOf(context),
            color: hovered ? tokens.globalForeground : tokens.globalFocus,
          ),
        ],
      ),
    );
  }
}

class _OpenProjectDialog extends StatefulWidget {
  const _OpenProjectDialog({required this.onOpen, required this.onCancel});
  final Future<void> Function(String path) onOpen;
  final VoidCallback onCancel;

  @override
  State<_OpenProjectDialog> createState() => _OpenProjectDialogState();
}

class _OpenProjectDialogState extends State<_OpenProjectDialog> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final path = _controller.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onOpen(path);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = ClideSettings.i18n.string(context, 'dialog.openProject.error', namespace: 'builtin.welcome', placeholder: 'Not a git repository'),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return Container(
      width: 420,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.modalSurfaceBackground,
        border: Border.all(color: tokens.modalSurfaceBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClideText(
            ClideSettings.i18n.string(context, 'dialog.openProject.title', namespace: 'builtin.welcome', placeholder: 'Open project'),
            fontSize: clideFontDialogTitle,
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 4),
          ClideText(
            ClideSettings.i18n.string(context, 'dialog.openProject.body', namespace: 'builtin.welcome', placeholder: 'Enter the path to a git repository.'),
            muted: true,
            fontSize: clideFontMeta,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: tokens.panelBackground,
              border: Border.all(color: tokens.globalBorder),
              borderRadius: BorderRadius.circular(4),
            ),
            child: EditableText(
              controller: _controller,
              focusNode: _focus,
              style: TextStyle(
                color: tokens.globalForeground,
                fontSize: clideFontCaption,
                fontFamily: ClideSettings.fonts.monoOf(context),
                fontFamilyFallback: clideMonoFamilyFallback,
              ),
              cursorColor: tokens.globalForeground,
              backgroundCursorColor: tokens.globalTextMuted,
              onSubmitted: (_) => unawaited(_submit()),
            ),
          ),
          if (_error != null) ...[const SizedBox(height: 8), ClideText(_error!, color: tokens.statusError, fontSize: clideFontSmall)],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ClideButton(
                label: ClideSettings.i18n.string(context, 'button.cancel', namespace: 'builtin.welcome', placeholder: 'Cancel'),
                onPressed: widget.onCancel,
              ),
              const SizedBox(width: 8),
              ClideButton(
                label: _loading
                    ? ClideSettings.i18n.string(context, 'button.opening', namespace: 'builtin.welcome', placeholder: 'Opening…')
                    : ClideSettings.i18n.string(context, 'button.open', namespace: 'builtin.welcome', placeholder: 'Open'),
                onPressed: _loading ? null : _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotARepoDialog extends StatelessWidget {
  const _NotARepoDialog({required this.path, required this.onDismiss});
  final String path;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return Container(
      width: 420,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.modalSurfaceBackground,
        border: Border.all(color: tokens.modalSurfaceBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClideText(
            ClideSettings.i18n.string(context, 'dialog.notRepo.title', namespace: 'builtin.welcome', placeholder: 'No git repo found'),
            fontSize: clideFontDialogTitle,
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 8),
          ClideText(path, muted: true, fontSize: clideFontMeta),
          const SizedBox(height: 8),
          ClideText(
            ClideSettings.i18n.string(
              context,
              'dialog.notRepo.body',
              namespace: 'builtin.welcome',
              placeholder: 'A clide project root requires a git repository.',
            ),
            muted: true,
            fontSize: clideFontMeta,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ClideButton(
                label: ClideSettings.i18n.string(context, 'button.ok', namespace: 'builtin.welcome', placeholder: 'OK'),
                onPressed: () => onDismiss(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// New-project dialog (T-488, story T-486): pick a location + name, create the
/// project via `project.new`, open it, and announce it on [projectCreatedChannel]
/// so the Claude extension can run the per-repo account roadblock. Stays
/// claude-free — the account step is the consumer's job, not this dialog's.
class _NewProjectDialog extends StatefulWidget {
  const _NewProjectDialog({required this.kernel, required this.onClose});
  final KernelServices kernel;
  final VoidCallback onClose;

  @override
  State<_NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<_NewProjectDialog> {
  final TextEditingController _parent = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final FocusNode _parentFocus = FocusNode(debugLabel: 'new-project-parent');
  final FocusNode _nameFocus = FocusNode(debugLabel: 'new-project-name');
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _parent.dispose();
    _name.dispose();
    _parentFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _browse() async {
    try {
      final picked = await widget.kernel.window.pickDirectory();
      if (picked != null && mounted) setState(() => _parent.text = picked);
    } on MissingPluginException {
      // No native picker on this platform — the user types the path instead.
    }
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final parent = _parent.text.trim();
    if (name.isEmpty) return setState(() => _error = 'Enter a project name.');
    if (parent.isEmpty) return setState(() => _error = 'Choose a location.');
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await widget.kernel.ipc.request(
      'project.new',
      args: {
        'positional': [name],
        'flags': {'dir': parent},
      },
    );
    if (!mounted) return;
    if (!r.ok) {
      return setState(() {
        _loading = false;
        _error = r.error?.message ?? 'Could not create the project.';
      });
    }
    final path = r.data['path'] as String;
    // Open the new workspace, then announce it — only a freshly-created project
    // announces, so only it triggers the account roadblock (T-488).
    final opened = await widget.kernel.project.open(path);
    if (opened) widget.kernel.panels.activateTab(Slots.workspace, 'claude.primary');
    widget.kernel.messages.publish('welcome', projectCreatedChannel, {'dir': path});
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return Container(
      width: 460,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.modalSurfaceBackground,
        border: Border.all(color: tokens.modalSurfaceBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClideText(
            ClideSettings.i18n.string(context, 'dialog.newProject.title', namespace: 'builtin.welcome', placeholder: 'New project'),
            fontSize: clideFontDialogTitle,
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 4),
          ClideText(
            ClideSettings.i18n.string(
              context,
              'dialog.newProject.body',
              namespace: 'builtin.welcome',
              placeholder: 'Creates a git repo + a CLAUDE.md, then opens it.',
            ),
            muted: true,
            fontSize: clideFontMeta,
          ),
          const SizedBox(height: 16),
          _field(
            tokens,
            'Location',
            _parent,
            _parentFocus,
            trailing: ClideButton(label: 'Browse…', onPressed: _browse),
          ),
          const SizedBox(height: 10),
          _field(tokens, 'Name', _name, _nameFocus, onSubmit: _create),
          if (_error != null) ...[const SizedBox(height: 8), ClideText(_error!, color: tokens.statusError, fontSize: clideFontSmall)],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ClideButton(
                label: ClideSettings.i18n.string(context, 'button.cancel', namespace: 'builtin.welcome', placeholder: 'Cancel'),
                onPressed: widget.onClose,
              ),
              const SizedBox(width: 8),
              ClideButton(
                label: _loading
                    ? ClideSettings.i18n.string(context, 'button.creating', namespace: 'builtin.welcome', placeholder: 'Creating…')
                    : ClideSettings.i18n.string(context, 'button.create', namespace: 'builtin.welcome', placeholder: 'Create'),
                onPressed: _loading ? null : _create,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(SurfaceTokens tokens, String label, TextEditingController c, FocusNode f, {Widget? trailing, Future<void> Function()? onSubmit}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClideText(label, fontSize: clideFontMeta, muted: true),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: tokens.panelBackground,
                  border: Border.all(color: f.hasFocus ? tokens.panelActiveBorder : tokens.globalBorder),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: EditableText(
                  controller: c,
                  focusNode: f,
                  style: TextStyle(
                    color: tokens.globalForeground,
                    fontSize: clideFontCaption,
                    fontFamily: ClideSettings.fonts.monoOf(context),
                    fontFamilyFallback: clideMonoFamilyFallback,
                  ),
                  cursorColor: tokens.globalForeground,
                  backgroundCursorColor: tokens.globalTextMuted,
                  maxLines: 1,
                  onSubmitted: onSubmit == null ? null : (_) => unawaited(onSubmit()),
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
          ],
        ),
      ],
    );
  }
}
