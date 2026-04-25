import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class ToolStatusItem extends StatelessWidget {
  const ToolStatusItem({super.key});

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideTheme.of(context).surface;
    return ListenableBuilder(
      listenable: kernel.toolchain,
      builder: (ctx, _) {
        final tc = kernel.toolchain;
        if (!tc.resolved) return const SizedBox.shrink();
        if (tc.allOk) {
          return _chip('application ok', tokens.statusSuccess, tokens);
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < tc.missing.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              _chip('${tc.missing[i]} not found', tokens.statusWarning, tokens),
            ],
          ],
        );
      },
    );
  }

  Widget _chip(String label, Color color, SurfaceTokens tokens) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          ClideText(label, fontSize: clideFontCaption, color: color),
        ],
      ),
    );
  }
}
