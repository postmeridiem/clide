/// Clickable permission-mode badge shown in each roster row (T-181).
/// Split out of claude_meta_sidebar.dart (T-395).
library;

import 'package:clide/builtin/claude/src/claude_status.dart' show permissionModeLabel;
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:flutter/widgets.dart';

/// Maps a permission-mode string to a single-letter badge label.
String permissionModeBadgeLabel(String mode) => switch (mode) {
  'acceptEdits' => 'A',
  'plan' => 'P',
  'bypassPermissions' => 'B',
  _ => 'D', // default
};

/// - Plain click → cycles the safe trio: default → acceptEdits → plan → default.
/// - Shift-click → shows the bypass confirm inline in the parent row.
///
/// The badge reflects the LIVE mode from `SessionStatus.permissionMode`
/// (T-157). It is a custom painted label (no Material), consistent with the
/// rendering stack rules (D-7, CLAUDE.md guardrails).
class PermissionModeBadge extends StatelessWidget {
  const PermissionModeBadge({super.key, required this.mode, required this.tokens, required this.onCycle, required this.onBypass});

  final String mode;
  final SurfaceTokens tokens;

  /// Called on a plain click — the parent cycles to the next safe mode.
  final VoidCallback onCycle;

  /// Called on a shift-click — the parent shows the bypass confirm.
  final VoidCallback onBypass;

  @override
  Widget build(BuildContext context) {
    final label = permissionModeBadgeLabel(mode);
    final isBypass = mode == 'bypassPermissions';
    final badgeColor = isBypass ? const Color(0xFFF06C6F) : tokens.globalFocus;

    final tooltip =
        'Permission mode: ${permissionModeLabel(mode)}. '
        'Click to cycle default/acceptEdits/plan; Shift-click for bypassPermissions.';

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Semantics(
        button: true,
        label: 'Permission mode: $label',
        excludeSemantics: true,
        onTap: () {
          if (HardwareKeyboard.instance.isShiftPressed) {
            onBypass();
          } else {
            onCycle();
          }
        },
        child: ClideTappable(
          tooltip: tooltip,
          onTap: () {
            if (HardwareKeyboard.instance.isShiftPressed) {
              onBypass();
            } else {
              onCycle();
            }
          },
          builder: (ctx, hovered, _) => Container(
            width: 16,
            height: 14,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(hovered ? 51 : 26),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: badgeColor.withAlpha(hovered ? 180 : 100), width: 1),
            ),
            child: ClideText(label, fontSize: 9, color: badgeColor),
          ),
        ),
      ),
    );
  }
}
