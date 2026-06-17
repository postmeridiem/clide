/// A single icon-button used by the roster row controls + task rows.
/// Split out of claude_meta_sidebar.dart (T-395). Promote to
/// lib/widgets/ only when a second consumer appears.
library;

import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class MetaIconButton extends StatelessWidget {
  const MetaIconButton({super.key, required this.painter, required this.tooltip, required this.color, required this.onTap});

  final ClideIconPainter painter;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Icon-only button: expose the tooltip text as the Semantics button label
    // so AT (and widget tests) can find and activate it by name.
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      onTap: onTap,
      child: ClideTappable(
        tooltip: tooltip,
        onTap: onTap,
        builder: (ctx, hovered, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: ClideIcon(painter, size: 12, color: hovered ? ClideSettings.theme.of(ctx).surface.globalForeground : color),
        ),
      ),
    );
  }
}
