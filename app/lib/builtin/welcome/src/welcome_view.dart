import 'dart:async';

import 'package:clide_app/kernel/kernel.dart';
import 'package:clide_app/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideTheme.of(context).surface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 1),
          _Header(tokens: tokens),
          const SizedBox(height: 48),
          Expanded(
            flex: 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 340, child: _StartColumn(tokens: tokens, kernel: kernel)),
                const SizedBox(width: 48),
                Expanded(child: _RecentColumn(tokens: tokens, kernel: kernel)),
              ],
            ),
          ),
          _StatusLine(tokens: tokens, kernel: kernel),
        ],
      ),
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
        Image.asset('assets/logo/clide-logo-192.png', width: 64, height: 64),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClideText('clide', fontSize: 42, fontWeight: FontWeight.w300, color: tokens.globalForeground),
            ClideText('Flutter desktop IDE for Claude Code', muted: true, fontSize: 14),
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
        ClideText('START', fontSize: 11, color: tokens.sidebarSectionHeader, fontFamily: clideMonoFamily),
        const SizedBox(height: 16),
        _ActionRow(
          icon: PhosphorIcons.folder,
          label: 'Open folder…',
          shortcut: '⌘O',
          tokens: tokens,
          onTap: () => _openFolder(context),
        ),
        _ActionRow(
          icon: PhosphorIcons.gitBranch,
          label: 'Clone from git…',
          shortcut: '⌘G',
          tokens: tokens,
          onTap: () {},
        ),
        _ActionRow(
          icon: PhosphorIcons.chatCircle,
          label: 'Start a Claude session',
          shortcut: '⌘C',
          tokens: tokens,
          onTap: () {},
        ),
      ],
    );
  }

  void _openFolder(BuildContext context) {
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

class _ActionRow extends StatefulWidget {
  const _ActionRow({required this.icon, required this.label, this.shortcut, required this.tokens, required this.onTap});
  final ClideIconPainter icon;
  final String label;
  final String? shortcut;
  final SurfaceTokens tokens;
  final VoidCallback onTap;

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hover ? widget.tokens.listItemHoverBackground : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              ClideIcon(widget.icon, size: 16, color: widget.tokens.globalTextMuted),
              const SizedBox(width: 12),
              Expanded(child: ClideText(widget.label, fontSize: 14, color: widget.tokens.globalForeground)),
              if (widget.shortcut != null)
                ClideText(widget.shortcut!, fontSize: 12, color: widget.tokens.globalTextMuted, fontFamily: clideMonoFamily),
            ],
          ),
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
            ClideText('RECENT', fontSize: 11, color: tokens.sidebarSectionHeader, fontFamily: clideMonoFamily),
            const SizedBox(height: 16),
            if (recents.isEmpty)
              const ClideText('No recent projects.', muted: true, fontSize: 13)
            else
              for (final r in recents)
                _RecentRow(project: r, tokens: tokens, onTap: () => _openRecent(r.path)),
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

class _RecentRow extends StatefulWidget {
  const _RecentRow({required this.project, required this.tokens, required this.onTap});
  final RecentProject project;
  final SurfaceTokens tokens;
  final VoidCallback onTap;

  @override
  State<_RecentRow> createState() => _RecentRowState();
}

class _RecentRowState extends State<_RecentRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hover ? widget.tokens.listItemHoverBackground : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClideText(widget.project.name, fontSize: 14, fontWeight: FontWeight.w500),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        ClideText(widget.project.relativePath, muted: true, fontSize: 12, fontFamily: clideMonoFamily),
                        if (widget.project.branch != null) ...[
                          ClideText('  ·  ', muted: true, fontSize: 12),
                          ClideIcon(PhosphorIcons.gitBranch, size: 10, color: widget.tokens.globalTextMuted),
                          const SizedBox(width: 3),
                          ClideText(widget.project.branch!, muted: true, fontSize: 12, fontFamily: clideMonoFamily),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              ClideText(widget.project.timeAgo, muted: true, fontSize: 12),
            ],
          ),
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
    return ListenableBuilder(
      listenable: kernel.ipc,
      builder: (ctx, _) {
        final connected = kernel.ipc.isConnected;
        final themeName = kernel.theme.currentName;
        return Row(
          children: [
            ClideText('clide 2.0.0-dev', muted: true, fontSize: 12, fontFamily: clideMonoFamily),
            ClideText('  ·  ', muted: true, fontSize: 12),
            ClideText(
              connected ? 'daemon connected' : 'daemon disconnected',
              fontSize: 12,
              fontFamily: clideMonoFamily,
              color: connected ? tokens.statusSuccess : tokens.statusError,
            ),
            ClideText('  ·  ', muted: true, fontSize: 12),
            ClideText('theme: ', muted: true, fontSize: 12, fontFamily: clideMonoFamily),
            ClideText(themeName, fontSize: 12, fontFamily: clideMonoFamily, color: tokens.globalFocus),
          ],
        );
      },
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
    setState(() { _loading = true; _error = null; });
    try {
      await widget.onOpen(path);
    } catch (_) {
      if (mounted) setState(() => _error = 'Not a git repository');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
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
          const ClideText('Open project', fontSize: 16, fontWeight: FontWeight.w600),
          const SizedBox(height: 4),
          const ClideText('Enter the path to a git repository.', muted: true, fontSize: 13),
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
              style: TextStyle(color: tokens.globalForeground, fontSize: 14, fontFamily: clideMonoFamily, fontFamilyFallback: clideMonoFamilyFallback),
              cursorColor: tokens.globalForeground,
              backgroundCursorColor: tokens.globalTextMuted,
              onSubmitted: (_) => unawaited(_submit()),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            ClideText(_error!, color: tokens.statusError, fontSize: 12),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ClideButton(label: 'Cancel', onPressed: widget.onCancel),
              const SizedBox(width: 8),
              ClideButton(label: _loading ? 'Opening…' : 'Open', onPressed: _loading ? null : _submit),
            ],
          ),
        ],
      ),
    );
  }
}
