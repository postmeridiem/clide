import 'dart:async';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:jovial_svg/jovial_svg.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideTheme.of(context).surface;
    return Stack(
      children: [
        Center(
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
                    Expanded(child: _StartColumn(tokens: tokens, kernel: kernel)),
                    const SizedBox(width: 56),
                    Expanded(child: _RecentColumn(tokens: tokens, kernel: kernel)),
                  ],
                ),
              ],
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
        SizedBox(
          width: 144,
          height: 144,
          child: ScalableImageWidget.fromSISource(
            si: ScalableImageSource.fromSvg(rootBundle, 'assets/logo/logo.svg'),
          ),
        ),
        const SizedBox(width: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClideText('clide', fontSize: 52, fontWeight: FontWeight.w300, color: tokens.globalForeground),
            ClideText('Flutter desktop IDE for Claude Code', muted: true, fontSize: 16),
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
        ClideText('START', fontSize: 12, color: tokens.sidebarSectionHeader, fontFamily: clideMonoFamily),
        const SizedBox(height: 20),
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
        decoration: BoxDecoration(
          color: hovered ? tokens.listItemHoverBackground : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            ClideIcon(icon, size: 18, color: tokens.globalTextMuted),
            const SizedBox(width: 14),
            Expanded(child: ClideText(label, fontSize: 15, color: tokens.globalForeground)),
            if (shortcut != null)
              ClideText(shortcut!, fontSize: 13, color: tokens.globalTextMuted, fontFamily: clideMonoFamily),
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
            ClideText('RECENT', fontSize: 12, color: tokens.sidebarSectionHeader, fontFamily: clideMonoFamily),
            const SizedBox(height: 20),
            if (recents.isEmpty)
              const ClideText('No recent projects.', muted: true, fontSize: 14)
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

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.project, required this.tokens, required this.onTap});
  final RecentProject project;
  final SurfaceTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClideTappable(
      onTap: onTap,
      builder: (context, hovered, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hovered ? tokens.listItemHoverBackground : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClideText(project.name, fontSize: 15, fontWeight: FontWeight.w500),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(child: ClideText(project.relativePath, muted: true, fontSize: 13, fontFamily: clideMonoFamily, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (project.branch != null) ...[
                        ClideText('  ·  ', muted: true, fontSize: 13),
                        ClideIcon(PhosphorIcons.gitBranch, size: 11, color: tokens.globalTextMuted),
                        const SizedBox(width: 3),
                        ClideText(project.branch!, muted: true, fontSize: 13, fontFamily: clideMonoFamily),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            ClideText(project.timeAgo, muted: true, fontSize: 13),
          ],
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
      listenable: kernel.toolCheck,
      builder: (ctx, _) {
        final tc = kernel.toolCheck;
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ClideText('clide 2.0.0-dev', muted: true, fontSize: 12, fontFamily: clideMonoFamily),
            ClideText('  ·  ', muted: true, fontSize: 12),
            if (!tc.checked)
              ClideText('checking…', muted: true, fontSize: 12, fontFamily: clideMonoFamily)
            else if (tc.allOk)
              ClideText('application ok', fontSize: 12, fontFamily: clideMonoFamily, color: tokens.statusSuccess)
            else
              ClideText(tc.errors.join(' · '), fontSize: 12, fontFamily: clideMonoFamily, color: tokens.statusWarning),
            ClideText('  ·  ', muted: true, fontSize: 12),
            _ThemeLink(tokens: tokens, kernel: kernel, themeName: themeName),
          ],
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
          ClideText('theme: ', muted: true, fontSize: 12, fontFamily: clideMonoFamily),
          ClideText(themeName, fontSize: 12, fontFamily: clideMonoFamily, color: hovered ? tokens.globalForeground : tokens.globalFocus),
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
