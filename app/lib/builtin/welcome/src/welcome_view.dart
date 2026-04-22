import 'dart:async';

import 'package:clide_app/kernel/kernel.dart';
import 'package:clide_app/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  static const _ns = 'builtin.welcome';

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideTheme.of(context).surface;
    return ListenableBuilder(
      listenable: kernel.i18n,
      builder: (ctx, _) {
        final i = kernel.i18n;
        return ClideSurface(
          color: tokens.globalBackground,
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClideText(
                  i.string('title', namespace: _ns, placeholder: 'clide'),
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  color: tokens.globalForeground,
                ),
                const SizedBox(height: 8),
                ClideText(
                  i.string(
                    'subtitle',
                    namespace: _ns,
                    placeholder: 'Flutter desktop IDE for Claude Code',
                  ),
                  muted: true,
                ),
                const SizedBox(height: 40),
                ClideText(
                  'START',
                  fontSize: clideFontCaption,
                  color: tokens.sidebarSectionHeader,
                  fontFamily: clideMonoFamily,
                ),
                const SizedBox(height: 12),
                _StartAction(
                  label: i.string('open-project', namespace: _ns, placeholder: 'Open project…'),
                  hint: i.string('open-project.hint', namespace: _ns, placeholder: 'Pick a git repository'),
                  icon: PhosphorIcons.folder,
                  onTap: () => _openProject(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openProject(BuildContext context) {
    final kernel = ClideKernel.of(context);
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

class _StartAction extends StatefulWidget {
  const _StartAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.hint,
  });

  final String label;
  final String? hint;
  final ClideIconPainter icon;
  final VoidCallback onTap;

  @override
  State<_StartAction> createState() => _StartActionState();
}

class _StartActionState extends State<_StartAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Semantics(
          button: true,
          label: widget.label,
          hint: widget.hint,
          child: Container(
            width: 280,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _hover ? tokens.listItemHoverBackground : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                ClideIcon(widget.icon, size: 16, color: tokens.globalFocus),
                const SizedBox(width: 12),
                Expanded(
                  child: ClideText(
                    widget.label,
                    color: tokens.globalFocus,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
