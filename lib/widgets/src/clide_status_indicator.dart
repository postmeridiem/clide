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

class ClideStatusIndicator extends StatelessWidget {
  const ClideStatusIndicator({super.key, required this.status, this.size = 14});

  final ClideRunStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final (Widget glyph, String label) = switch (status) {
      ClideRunStatus.running => (ClideSpinner(size: size, color: tokens.globalTextMuted, key: const ValueKey('running')), 'running'),
      ClideRunStatus.success => (ClideIcon(const CheckIcon(), size: size, color: tokens.statusSuccess, key: const ValueKey('success')), 'succeeded'),
      ClideRunStatus.error => (ClideIcon(const CloseIcon(), size: size, color: tokens.statusError, key: const ValueKey('error')), 'failed'),
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
