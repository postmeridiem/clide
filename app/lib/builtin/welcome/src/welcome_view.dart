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
                  fontSize: 40,
                  fontWeight: FontWeight.w300,
                  color: tokens.panelActiveBorder,
                ),
                const SizedBox(height: 12),
                ClideText(
                  i.string(
                    'subtitle',
                    namespace: _ns,
                    placeholder: 'Flutter desktop IDE for Claude Code',
                  ),
                  muted: true,
                  fontSize: 14,
                ),
                const SizedBox(height: 32),
                ClideButton(
                  label: i.string(
                    'open-project',
                    namespace: _ns,
                    placeholder: 'Open project',
                  ),
                  semanticHint: i.string(
                    'open-project.hint',
                    namespace: _ns,
                    placeholder:
                        'Pick a git repository to open as the workspace',
                  ),
                  variant: ClideButtonVariant.primary,
                  onPressed: () {
                    // project open UI lands with the project picker tier
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
