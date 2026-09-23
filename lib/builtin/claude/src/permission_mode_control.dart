/// Icon-only permission-mode control trailing the Claude composer (T-275),
/// built on the ClideAnchoredOverlay + ClideMenu primitive (D-88).
///
/// Shows the current mode as a per-mode coloured glyph; clicking opens a menu
/// of the modes the session can enter, the active one marked (T-597): Manual,
/// Accept edits, Plan, Auto (when the model supports it). Bypass permissions
/// appears only when the user allowed it in settings — the desktop app's
/// pattern — so it's a plain, clearly-dangerous row below a divider rather than
/// the shift-click gate it used to hide behind (T-510). The label lives in the
/// tooltip, the menu rows, and the status-bar indicator — the resting button is
/// the glyph alone.
library;

import 'package:clide/builtin/claude/src/claude_status.dart' show permissionModeLabel;
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// Per-mode glyph: check-shield (Manual), pencil (Accept edits), checklist
/// (Plan), star-shield (Auto — hands-off, with a safety check), warning shield
/// (Bypass).
ClideIconPainter permissionModeIcon(String mode) {
  switch (mode) {
    case 'acceptEdits':
      return PhosphorIcons.byName('pencil-simple');
    case 'plan':
      return PhosphorIcons.byName('list-checks');
    case 'auto':
      return PhosphorIcons.byName('shield-star');
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
    case 'auto':
      return tokens.statusSuccess;
    case 'bypassPermissions':
      return tokens.statusError;
    default:
      return tokens.globalTextMuted;
  }
}

class PermissionModeControl extends StatefulWidget {
  const PermissionModeControl({super.key, required this.mode, required this.onSelect, this.modes = const ['default', 'acceptEdits', 'plan']});

  /// Current permission mode (e.g. `default`, `acceptEdits`, `auto`).
  final String mode;

  /// The modes to offer, in menu order — what the session can enter now.
  final List<String> modes;

  /// Set a specific mode.
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

  ClideMenuItem _row(String m, SurfaceTokens tokens) => ClideMenuItem(
    leading: permissionModeIcon(m),
    color: permissionModeColor(m, tokens),
    label: permissionModeLabel(m),
    active: m == widget.mode,
    onSelect: () => widget.onSelect(m),
  );

  List<ClideMenuEntry> _entries(SurfaceTokens tokens) {
    final bypass = widget.modes.contains('bypassPermissions');
    return [
      for (final m in widget.modes)
        if (m != 'bypassPermissions') _row(m, tokens),
      // Offered only when allowed in settings; set apart as the one mode with
      // no checks at all.
      if (bypass) ...[const ClideMenuSeparator(), _row('bypassPermissions', tokens)],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return ClideAnchoredOverlay(
      controller: _overlay,
      side: ClideAnchorSide.above,
      align: ClideAnchorAlign.end,
      offset: const Offset(0, -6),
      overlayBuilder: (ctx, ctrl) => ClideMenu(onClose: ctrl.close, minWidth: 180, entries: _entries(ClideSettings.theme.of(ctx).surface)),
      anchor: ListenableBuilder(
        listenable: _overlay,
        builder: (ctx, _) {
          final open = _overlay.isOpen;
          return Semantics(
            button: true,
            label: ClideSettings.i18n.interpolated(
              context,
              'permissionControl.semantics',
              namespace: 'builtin.claude',
              placeholder: 'permission mode: ${permissionModeLabel(widget.mode)}. Activate to change.',
              replacers: [I18nReplacer(from: '{mode}', replace: permissionModeLabel(widget.mode))],
            ),
            excludeSemantics: true,
            child: ClideTappable(
              onTap: _overlay.toggle,
              tooltip: ClideSettings.i18n.interpolated(
                context,
                'permissionControl.tooltip',
                namespace: 'builtin.claude',
                placeholder: 'Permission mode: ${permissionModeLabel(widget.mode)} — change (Ctrl/Cmd+M cycles)',
                replacers: [I18nReplacer(from: '{mode}', replace: permissionModeLabel(widget.mode))],
              ),
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
