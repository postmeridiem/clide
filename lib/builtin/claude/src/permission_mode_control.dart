/// Icon-only permission-mode control trailing the Claude composer (T-275),
/// built on the ClideAnchoredOverlay + ClideMenu primitive (D-88).
///
/// Shows the current mode as a per-mode coloured glyph; clicking opens a menu
/// of the safe trio (default / accept-edits / plan) with the active one marked,
/// plus a divided, disabled `bypass` row — that footgun stays behind the
/// cockpit's explicit confirmed path (T-181), never one click away here. The
/// label lives in the tooltip, the menu rows, and the status-bar indicator —
/// the resting button is the glyph alone.
library;

import 'package:clide/builtin/claude/src/claude_status.dart' show kSafePermissionCycle, permissionModeLabel;
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// Per-mode glyph. `bypass` reuses a warning shield; the safe trio gets a
/// check-shield (default), pencil (accept-edits), and checklist (plan).
ClideIconPainter permissionModeIcon(String mode) {
  switch (mode) {
    case 'acceptEdits':
      return PhosphorIcons.byName('pencil-simple');
    case 'plan':
      return PhosphorIcons.byName('list-checks');
    case 'bypassPermissions':
      return PhosphorIcons.byName('shield-warning');
    default:
      return PhosphorIcons.byName('shield-check');
  }
}

/// Per-mode accent — used by the control glyph and the passive status indicator
/// so both read the same colour. All theme tokens (no hardcoded hex).
Color permissionModeColor(String mode, SurfaceTokens tokens) {
  switch (mode) {
    case 'acceptEdits':
      return tokens.statusWarning;
    case 'plan':
      return tokens.globalFocus;
    case 'bypassPermissions':
      return tokens.statusError;
    default:
      return tokens.globalTextMuted;
  }
}

class PermissionModeControl extends StatefulWidget {
  const PermissionModeControl({super.key, required this.mode, required this.onSelect});

  /// Current permission mode (e.g. `default`, `acceptEdits`, `plan`).
  final String mode;

  /// Set a specific safe mode (the disabled `bypass` row never calls this).
  final ValueChanged<String> onSelect;

  @override
  State<PermissionModeControl> createState() => _PermissionModeControlState();
}

class _PermissionModeControlState extends State<PermissionModeControl> {
  final ClideOverlayController _overlay = ClideOverlayController();

  @override
  void dispose() {
    _overlay.dispose();
    super.dispose();
  }

  List<ClideMenuEntry> _entries(SurfaceTokens tokens) => [
    for (final m in kSafePermissionCycle)
      ClideMenuItem(
        leading: permissionModeIcon(m),
        color: permissionModeColor(m, tokens),
        label: permissionModeLabel(m),
        active: m == widget.mode,
        onSelect: () => widget.onSelect(m),
      ),
    const ClideMenuSeparator(),
    ClideMenuItem(
      leading: permissionModeIcon('bypassPermissions'),
      color: permissionModeColor('bypassPermissions', tokens),
      label: permissionModeLabel('bypassPermissions'),
      enabled: false,
      active: widget.mode == 'bypassPermissions',
      onSelect: () {},
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return ClideAnchoredOverlay(
      controller: _overlay,
      side: ClideAnchorSide.above,
      align: ClideAnchorAlign.end,
      offset: const Offset(0, -6),
      overlayBuilder: (ctx, ctrl) => ClideMenu(onClose: ctrl.close, minWidth: 180, entries: _entries(ClideTheme.of(ctx).surface)),
      anchor: ListenableBuilder(
        listenable: _overlay,
        builder: (ctx, _) {
          final open = _overlay.isOpen;
          return Semantics(
            button: true,
            label: 'permission mode: ${permissionModeLabel(widget.mode)}. Activate to change.',
            excludeSemantics: true,
            child: ClideTappable(
              onTap: _overlay.toggle,
              tooltip: 'Permission mode: ${permissionModeLabel(widget.mode)} — change (Ctrl/Cmd+M cycles)',
              builder: (ctx, hovered, _) => Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hovered ? tokens.listItemHoverBackground : null,
                  border: Border.all(color: open ? tokens.globalFocus : (hovered ? tokens.panelActiveBorder : tokens.globalBorder)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ClideIcon(permissionModeIcon(widget.mode), size: 16, color: permissionModeColor(widget.mode, tokens)),
              ),
            ),
          );
        },
      ),
    );
  }
}
