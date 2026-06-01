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

/// A row of reader-chrome action buttons: back, forward, pin (set/jump), edit.
///
/// Designed to plug into [ClidePaneChrome.trailing].  All callbacks are
/// optional — pass null to hide/disable the corresponding button.
class ReaderActionBar extends StatelessWidget {
  const ReaderActionBar({
    super.key,
    required this.canGoBack,
    required this.canGoForward,
    required this.hasPinned,
    required this.onBack,
    required this.onForward,
    required this.onPin,
    required this.onJumpToPin,
    required this.onEdit,
  });

  final bool canGoBack;
  final bool canGoForward;
  final bool hasPinned;
  final VoidCallback? onBack;
  final VoidCallback? onForward;

  /// Called when the pin button is tapped (set / replace current pin).
  final VoidCallback? onPin;

  /// Called when the jump-to-pin affordance is tapped.
  final VoidCallback? onJumpToPin;

  /// Called when the edit pencil is tapped.  Pass null to hide the button.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          painter: PhosphorIcons.caretLeft,
          tooltip: 'Back',
          enabled: canGoBack,
          onTap: canGoBack ? onBack : null,
          tokens: tokens,
        ),
        const SizedBox(width: 2),
        _ActionButton(
          painter: PhosphorIcons.caretRight,
          tooltip: 'Forward',
          enabled: canGoForward,
          onTap: canGoForward ? onForward : null,
          tokens: tokens,
        ),
        const SizedBox(width: 4),
        _PinButton(
          hasPinned: hasPinned,
          onPin: onPin,
          onJumpToPin: onJumpToPin,
          tokens: tokens,
        ),
        if (onEdit != null) ...[
          const SizedBox(width: 2),
          _ActionButton(
            painter: PhosphorIcons.pencilSimple,
            tooltip: 'Edit in editor',
            enabled: true,
            onTap: onEdit,
            tokens: tokens,
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Private button widgets
// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.painter,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
    required this.tokens,
  });

  final ClideIconPainter painter;
  final String tooltip;
  final bool enabled;
  final VoidCallback? onTap;
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      enabled: enabled,
      onTap: onTap,
      excludeSemantics: true,
      child: ClideTappable(
        onTap: onTap,
        tooltip: tooltip,
        builder: (ctx, hovered, _) => Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hovered && enabled ? tokens.sidebarItemHover : null,
            borderRadius: BorderRadius.circular(3),
          ),
          child: ClideIcon(
            painter,
            size: 11,
            color: enabled ? tokens.panelHeaderForeground : tokens.globalTextMuted,
          ),
        ),
      ),
    );
  }
}

/// Pin button: when [hasPinned] is true it shows the pin "filled" and the
/// button activates jump-to-pin; a long-press (or secondary tap) sets a new
/// pin.  When [hasPinned] is false the single tap sets the pin.
///
/// For simplicity (and to keep the widget API flat): a single tap ALWAYS sets
/// the pin (replacing the previous one), while the adjacent jump-to-pin uses a
/// separate Tappable rendered as a small indicator badge.
class _PinButton extends StatelessWidget {
  const _PinButton({
    required this.hasPinned,
    required this.onPin,
    required this.onJumpToPin,
    required this.tokens,
  });

  final bool hasPinned;
  final VoidCallback? onPin;
  final VoidCallback? onJumpToPin;
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The pin-set button (always shown, sets/replaces the pin).
        Semantics(
          button: true,
          label: hasPinned ? 'Replace pin' : 'Pin current',
          onTap: onPin,
          excludeSemantics: true,
          child: ClideTappable(
            onTap: onPin,
            tooltip: hasPinned ? 'Replace pin' : 'Pin current',
            builder: (ctx, hovered, _) => Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hovered ? tokens.sidebarItemHover : null,
                borderRadius: BorderRadius.circular(3),
              ),
              child: ClideIcon(
                PhosphorIcons.link,
                size: 11,
                color: hasPinned ? tokens.globalFocus : tokens.panelHeaderForeground,
              ),
            ),
          ),
        ),
        // Jump-to-pin affordance — only visible when a pin is set.
        if (hasPinned) ...[
          const SizedBox(width: 1),
          Semantics(
            button: true,
            label: 'Jump to pin',
            onTap: onJumpToPin,
            excludeSemantics: true,
            child: ClideTappable(
              onTap: onJumpToPin,
              tooltip: 'Jump to pin',
              builder: (ctx, hovered, _) => Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hovered ? tokens.sidebarItemHover : tokens.panelBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: ClideText(
                  '↩',
                  fontSize: 9,
                  color: tokens.globalFocus,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
