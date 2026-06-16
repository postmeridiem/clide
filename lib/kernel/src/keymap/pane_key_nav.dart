/// A reusable vim normal-mode navigation key handler for non-editor panes
/// (T-406).
///
/// The passive global key path is single-chord only and can't run sequences or
/// consume events (D-82), so — exactly like the editor's command-mode handler —
/// each pane that wants vim motions hosts its OWN [SequenceMatcher] inside a
/// `Focus.onKeyEvent`. [PaneKeyNav] is that handler, factored out so the file
/// tree, conversation, and lists share one implementation.
///
/// While a `vim.normal` scope flag is set and this region holds focus, bare and
/// shift-only chords (plus the two half-page chords `ctrl+d` / `ctrl+u`) feed
/// the matcher against the live keymap; a fired [NavIntent] is handed to
/// `onNav` with its repeat count. Everything else under `vim.normal` is
/// swallowed (vim normal mode is inert for unbound keys), except other-modifier
/// chords (palette, quick-open, …) which bubble to the global handler. Under a
/// non-vim preset or in insert mode the region is transparent — keys pass
/// straight through.
///
/// The vim preset binds nav.* `when: vim.normal && !editor.focused`, so a key
/// that also has an `editor.vim.*` motion (j/k/h/l/gg/G) resolves to the nav
/// intent here and to the editor motion in the editor — see vim.yaml.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../facade.dart';
import 'intents.dart';
import 'key_chord.dart';
import 'keymap.dart';
import 'sequence_matcher.dart';

/// Signature for a fired navigation motion: the [intent] and its repeat
/// [count] (>= 1, from a leading digit prefix like `5j`).
typedef NavHandler = void Function(NavIntent intent, int count);

class PaneKeyNav extends StatefulWidget {
  const PaneKeyNav({super.key, required this.child, required this.onNav, this.focusNode, this.autofocus = false, this.canRequestFocus = true});

  final Widget child;

  /// Called when a `nav.*` motion resolves while this region has focus.
  final NavHandler onNav;

  /// Focus node for the region. When null, [PaneKeyNav] owns one. Panes that
  /// want to move focus here programmatically (a row tap, F6) pass their own.
  final FocusNode? focusNode;

  final bool autofocus;

  /// Whether the region can take focus at all. False makes it a pure pass-through
  /// (used when a pane temporarily routes keys elsewhere, e.g. a filter box).
  final bool canRequestFocus;

  @override
  State<PaneKeyNav> createState() => _PaneKeyNavState();
}

class _PaneKeyNavState extends State<PaneKeyNav> {
  FocusNode? _ownNode;
  SequenceMatcher? _matcher;

  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'PaneKeyNav'));

  /// The half-page scroll chords are the only modified chords this handler
  /// claims; every other modified chord bubbles to the global shortcut path.
  static final KeyChord _ctrlD = KeyChord(modifiers: const {KeyModifier.ctrl}, key: LogicalKeyboardKey.keyD);
  static final KeyChord _ctrlU = KeyChord(modifiers: const {KeyModifier.ctrl}, key: LogicalKeyboardKey.keyU);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_matcher != null) return;
    final kernel = ClideKernel.of(context);
    _matcher = SequenceMatcher(keymap: () => kernel.keymap.keymap ?? Keymap(const []), context: () => kernel.keymap.scope);
  }

  @override
  void dispose() {
    _ownNode?.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final kernel = ClideKernel.of(context);
    // Only vim normal mode drives pane navigation. Insert/visual or a non-vim
    // preset → transparent, keys pass through to whatever's below.
    if (kernel.keymap.scope['vim.normal'] != true) return KeyEventResult.ignored;

    final hw = HardwareKeyboard.instance;
    final chord = KeyChord.fromKeyEvent(event, hw);
    if (chord == null) return KeyEventResult.ignored;

    // Bare + shift-only chords drive the matcher; ctrl+d/ctrl+u are the only
    // modified chords we claim (half-page scroll). Any other modified chord is
    // an app shortcut (palette, quick-open) — let it bubble to the global path.
    final modified = chord.modifiers.any((m) => m != KeyModifier.shift);
    if (modified && chord != _ctrlD && chord != _ctrlU) return KeyEventResult.ignored;

    final r = _matcher!.feed(chord);
    switch (r.outcome) {
      case SeqOutcome.fired:
        // The vim preset also binds these keys to editor.vim.* motions; in a
        // pane only nav.* applies, and editor.vim.* (an InvokeCommandIntent) is
        // swallowed — never run buffer edits from a pane. A typed *app* intent
        // (e.g. the ex-line `:` / ZZ) bubbles to the app-root Actions for its
        // global handler (T-407).
        final fired = r.intent;
        if (fired is NavIntent) {
          widget.onNav(fired, r.count);
        } else if (fired != null && fired is! InvokeCommandIntent) {
          Actions.maybeInvoke(context, fired);
        }
        return KeyEventResult.handled;
      case SeqOutcome.pending:
        return KeyEventResult.handled;
      case SeqOutcome.unmatched:
        // Vim normal mode beeps on unbound keys — swallow so a bare key never
        // leaks to text input or the global handler.
        return KeyEventResult.handled;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(focusNode: _node, autofocus: widget.autofocus, canRequestFocus: widget.canRequestFocus, onKeyEvent: _onKey, child: widget.child);
  }
}
