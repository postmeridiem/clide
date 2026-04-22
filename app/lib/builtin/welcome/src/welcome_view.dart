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
                  label: i.string('open-project',
                      namespace: _ns, placeholder: 'Open project…'),
                  hint: i.string('open-project.hint',
                      namespace: _ns,
                      placeholder: 'Pick a git repository'),
                  icon: const FolderIcon(),
                  onTap: () {},
                ),
                _StartAction(
                  label: 'New Claude session…',
                  icon: const TerminalIcon(),
                  onTap: () {},
                ),
              ],
            ),
          ),
        );
      },
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
