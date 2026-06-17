/// Shared action-bar chrome for sidebar reader widgets (T-189, T-190, T-191).
///
/// Provides [ReaderActionBar] — the visible action bar: back, forward, pin,
/// edit pencil. Plugs into a [ClidePaneChrome] via its `trailing:` slot. The
/// retained back/forward history that drives it is the kernel `ReaderNav`
/// (one per right-pane reader); this file is just the buttons.
library;

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// Action bar widget
// ---------------------------------------------------------------------------

/// The reader's **navigator** — back, forward, jump-to-pin (only while
/// pinned), and the edit pencil. Plugs into [ClidePaneChrome.trailing].
/// The pin/unpin toggle is deliberately NOT here: it's a mode control,
/// not navigation, so it lives in the pane's leading slot as a
/// standalone [ReaderPinButton] (T-198). All callbacks are optional —
/// pass null to hide/disable the corresponding button.
class ReaderActionBar extends StatelessWidget {
  const ReaderActionBar({
    super.key,
    required this.canGoBack,
    required this.canGoForward,
    required this.hasPinned,
    required this.onBack,
    required this.onForward,
    required this.onJumpToPin,
    required this.onEdit,
  });

  final bool canGoBack;
  final bool canGoForward;
  final bool hasPinned;
  final VoidCallback? onBack;
  final VoidCallback? onForward;

  /// Called when the jump-to-pin button (in the navigator) is tapped.
  final VoidCallback? onJumpToPin;

  /// Called when the edit pencil is tapped. Pass null to hide the button.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(painter: PhosphorIcons.byName('caret-left'), tooltip: 'Back', enabled: canGoBack, onTap: canGoBack ? onBack : null, tokens: tokens),
        const SizedBox(width: 2),
        _ActionButton(
          painter: PhosphorIcons.byName('caret-right'),
          tooltip: 'Forward',
          enabled: canGoForward,
          onTap: canGoForward ? onForward : null,
          tokens: tokens,
        ),
        if (hasPinned) ...[
          const SizedBox(width: 2),
          _ActionButton(painter: PhosphorIcons.byName('arrow-u-up-left'), tooltip: 'Jump to pin', enabled: true, onTap: onJumpToPin, tokens: tokens),
        ],
        if (onEdit != null) ...[
          const SizedBox(width: 4),
          _ActionButton(painter: PhosphorIcons.byName('pencil-simple'), tooltip: 'Edit in editor', enabled: true, onTap: onEdit, tokens: tokens),
        ],
      ],
    );
  }
}

/// The pin/unpin toggle — a single button that sits in the pane's
/// leading slot (before the title), separate from the navigator so the
/// two kinds of control don't read as one group (T-198). [pinned]
/// drives the accent + the Pin/Unpin label; [onTap] toggles.
class ReaderPinButton extends StatelessWidget {
  const ReaderPinButton({super.key, required this.pinned, required this.onTap});

  final bool pinned;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _ActionButton(
      painter: PhosphorIcons.byName('push-pin'),
      tooltip: pinned ? 'Unpin' : 'Pin',
      enabled: onTap != null,
      active: pinned,
      onTap: onTap,
      tokens: ClideSettings.theme.of(context).surface,
    );
  }
}

// ---------------------------------------------------------------------------
// Private button widget
// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.painter, required this.tooltip, required this.enabled, required this.onTap, required this.tokens, this.active = false});

  final ClideIconPainter painter;
  final String tooltip;
  final bool enabled;

  /// Renders the glyph in the focus/accent colour to signal an on state
  /// (used by the pin toggle when something is pinned).
  final bool active;
  final VoidCallback? onTap;
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (!enabled) {
      color = tokens.globalTextMuted;
    } else if (active) {
      color = tokens.globalFocus;
    } else {
      color = tokens.panelHeaderForeground;
    }
    return Semantics(
      button: true,
      label: tooltip,
      enabled: enabled,
      toggled: active,
      onTap: onTap,
      excludeSemantics: true,
      child: ClideTappable(
        onTap: onTap,
        tooltip: tooltip,
        builder: (ctx, hovered, _) => Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: hovered && enabled ? tokens.sidebarItemHover : null, borderRadius: BorderRadius.circular(3)),
          child: ClideIcon(painter, size: 11, color: color),
        ),
      ),
    );
  }
}
