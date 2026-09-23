/// "Compacting context…" strip, docked above the composer while claude
/// compacts (T-244).
///
/// Compaction can take tens of seconds with nothing streaming, which reads as a
/// wedged session. This is display-only (D-78 — not an interactive control),
/// sits in the same slot and chrome as the task dock, and renders nothing when
/// [active] is false. A live region, so a screen reader hears it start.
library;

import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class ClaudeCompactingIndicator extends StatelessWidget {
  const ClaudeCompactingIndicator({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    if (!active) return const SizedBox.shrink();
    final tokens = ClideSettings.theme.of(context).surface;
    final label = ClideSettings.i18n.string(context, 'compacting.banner', namespace: 'builtin.claude', placeholder: 'Compacting context…');
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      child: Semantics(
        liveRegion: true,
        label: label,
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: tokens.listItemBackground,
            border: Border.all(color: tokens.panelBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              ClideSpinner(size: 12, color: tokens.globalTextMuted),
              const SizedBox(width: 8),
              Expanded(
                child: ClideText(label, fontSize: clideFontCaption, color: tokens.globalTextMuted, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
