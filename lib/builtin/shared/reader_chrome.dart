/// Shared action-bar chrome for sidebar reader widgets (T-189, T-190, T-191).
///
/// Provides:
///  - [ReaderHistory] — back/forward history stack with browser semantics.
///  - [ReaderActionBar] — the visible action bar widget: back, forward, pin,
///    edit pencil.  Plugs into a [ClidePaneChrome] via its `trailing:` slot.
///
/// Usage: mix [ReaderHistoryMixin] into a [State] to get back/forward/pin state
/// management, then put a [ReaderActionBar] in [ClidePaneChrome.trailing].
library;

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// History model
// ---------------------------------------------------------------------------

/// Back/forward history stack.  [T] is the entry type (String path for
/// markdown, String id for decisions).
///
/// Standard browser semantics:
///  - [push] appends at [_index+1] and truncates any forward entries.
///  - [back]/[forward] adjust the index without re-pushing.
///  - [canGoBack]/[canGoForward] drive the enabled state of the buttons.
class ReaderHistory<T> {
  final List<T> _stack = [];
  int _index = -1;

  bool get canGoBack => _index > 0;
  bool get canGoForward => _index < _stack.length - 1;

  T? get current => _index >= 0 && _index < _stack.length ? _stack[_index] : null;

  /// Push a new entry, truncating any forward history.
  void push(T entry) {
    if (_index >= 0 && _stack[_index] == entry) {
      // Same entry as current — don't push a duplicate.
      return;
    }
    // Truncate forward history.
    if (_index < _stack.length - 1) {
      _stack.removeRange(_index + 1, _stack.length);
    }
    _stack.add(entry);
    _index = _stack.length - 1;
  }

  /// Move back one step. Returns the entry now current, or null.
  T? back() {
    if (!canGoBack) return null;
    _index--;
    return _stack[_index];
  }

  /// Move forward one step. Returns the entry now current, or null.
  T? forward() {
    if (!canGoForward) return null;
    _index++;
    return _stack[_index];
  }
}

// ---------------------------------------------------------------------------
// Mixin
// ---------------------------------------------------------------------------

/// Mix into a [State] that owns a [ReaderHistory] and an optional pin.
///
/// The concrete state must call [historyPush] whenever it loads a new
/// entry (NOT when navigating back/forward — those call [historyBack] /
/// [historyForward] and then load the returned entry without re-pushing).
mixin ReaderHistoryMixin<T, W extends StatefulWidget> on State<W> {
  final ReaderHistory<T> _history = ReaderHistory<T>();
  T? _pinned;

  bool get canGoBack => _history.canGoBack;
  bool get canGoForward => _history.canGoForward;
  bool get hasPinned => _pinned != null;
  T? get pinnedEntry => _pinned;

  /// Record that the reader is now showing [entry].  Must be called AFTER
  /// setState has been applied so the action-bar buttons rebuild.
  void historyPush(T entry) {
    setState(() => _history.push(entry));
  }

  /// Navigate back. Returns the entry to load, or null if already at start.
  T? historyBack() {
    final entry = _history.back();
    if (entry != null) setState(() {});
    return entry;
  }

  /// Navigate forward. Returns the entry to load, or null if at end.
  T? historyForward() {
    final entry = _history.forward();
    if (entry != null) setState(() {});
    return entry;
  }

  /// Set or replace the pin with the current entry.
  void pinCurrent() {
    final cur = _history.current;
    if (cur == null) return;
    setState(() => _pinned = cur);
  }

  /// Returns the pinned entry, or null if none set.
  T? jumpToPin() {
    return _pinned;
  }
}

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
