/// A self-contained run-status glyph: spinner while running, check on success,
/// cross on failure (T-296).
///
/// Deliberately NOT built on ConversationCard's success/error mark — it owns its
/// own states and rendering so the spinner→check / spinner→cross transition can
/// grow richer (a morph/cross-fade) without being constrained by that card. A
/// light [AnimatedSwitcher] cross-fade between states is wired now; the keyed
/// children leave the seam for a fuller transition later.
library;

import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/widgets/src/clide_icon.dart';
import 'package:clide/widgets/src/clide_spinner.dart';
import 'package:clide/widgets/src/icons/check.dart';
import 'package:clide/widgets/src/icons/x.dart';
import 'package:flutter/widgets.dart';

enum ClideRunStatus { running, success, error }

class ClideStatusIndicator extends StatefulWidget {
  const ClideStatusIndicator({super.key, required this.status, this.size = 14});

  final ClideRunStatus status;
  final double size;

  @override
  State<ClideStatusIndicator> createState() => _ClideStatusIndicatorState();
}

class _ClideStatusIndicatorState extends State<ClideStatusIndicator> {
  /// Monotonic id bumped on every status change, folded into the child key. A
  /// per-status-only key collides inside [AnimatedSwitcher]'s Stack when a
  /// status re-appears (running → success → running within the cross-fade)
  /// while its previous glyph is still animating out — the exiting and entering
  /// children share `ValueKey('running')` and trip the duplicate-key assertion
  /// (T-326). The sequence makes each appearance's key unique; a same-status
  /// rebuild keeps the key, so it still doesn't re-animate.
  int _seq = 0;

  @override
  void didUpdateWidget(ClideStatusIndicator old) {
    super.didUpdateWidget(old);
    if (old.status != widget.status) _seq++;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final key = ValueKey('${widget.status.name}-$_seq');
    final (Widget glyph, String label) = switch (widget.status) {
      ClideRunStatus.running => (ClideSpinner(size: widget.size, color: tokens.globalTextMuted, key: key), 'running'),
      ClideRunStatus.success => (ClideIcon(const CheckIcon(), size: widget.size, color: tokens.statusSuccess, key: key), 'succeeded'),
      ClideRunStatus.error => (ClideIcon(const CloseIcon(), size: widget.size, color: tokens.statusError, key: key), 'failed'),
    };
    return Semantics(
      label: label,
      container: true,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: glyph,
      ),
    );
  }
}
