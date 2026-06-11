import 'package:clide/builtin/vim/src/vim_mode_service.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// Status-bar item showing the current Vim mode (`-- NORMAL --`). Renders
/// nothing while the Vim layer is disabled, so it's invisible under
/// non-Vim presets (T-207).
class VimModeIndicator extends StatelessWidget {
  const VimModeIndicator({super.key, required this.service});

  final VimModeService service;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        if (!service.enabled) return const SizedBox.shrink();
        final tokens = ClideTheme.of(context).surface;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ClideText('-- ${service.mode.label} --', fontFamily: clideMonoFamily, fontSize: clideFontCaption, color: tokens.statusBarForeground),
        );
      },
    );
  }
}
