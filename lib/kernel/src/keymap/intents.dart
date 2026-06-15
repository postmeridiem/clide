/// Typed [Intent]s the keymap dispatches.
///
/// Widgets bind Actions to Intent types via `Actions.handler`. Preset
/// YAML files reference Intents by their string id (`activate`,
/// `palette.selectNext`, …). The id stays stable across SDK reshapes;
/// the Dart class name can move without invalidating user keymaps.
///
/// Two flavors of intents live here:
///   1. **Flutter-provided** — `ActivateIntent` and `DismissIntent`
///      are first-class Flutter intents; we reuse them so the keymap
///      integrates with anything else in the Flutter ecosystem that
///      already dispatches those (focus traversal, modal scrims, …).
///      They're mapped by id in [builtinIntents] but not declared
///      here.
///   2. **Clide-specific** — palette navigation, text scale, the
///      `InvokeCommandIntent` bridge. Each subclass extends [Intent]
///      directly.
library;

import 'package:flutter/widgets.dart';

// -- Panel-to-panel focus traversal -----------------------------------------

/// Move focus to the next panel in `FocusTracker.traversalOrder`
/// (sidebar → workspace → context). Bound to F6 by default.
class FocusNextPanelIntent extends Intent {
  const FocusNextPanelIntent();
}

/// Move focus to the previous panel. Bound to Shift+F6 by default.
class FocusPreviousPanelIntent extends Intent {
  const FocusPreviousPanelIntent();
}

// -- Command palette --------------------------------------------------------

/// Open the command palette.
class PaletteOpenIntent extends Intent {
  const PaletteOpenIntent();
}

/// Highlight the next palette result.
class PaletteSelectNextIntent extends Intent {
  const PaletteSelectNextIntent();
}

/// Highlight the previous palette result.
class PaletteSelectPreviousIntent extends Intent {
  const PaletteSelectPreviousIntent();
}

/// Invoke the highlighted palette result.
class PaletteAcceptIntent extends Intent {
  const PaletteAcceptIntent();
}

// -- Quick open -------------------------------------------------------------

/// Open the quick-open file finder (fuzzy file picker), distinct from
/// the command palette.
class QuickOpenIntent extends Intent {
  const QuickOpenIntent();
}

/// Highlight the next quick-open result.
class QuickOpenSelectNextIntent extends Intent {
  const QuickOpenSelectNextIntent();
}

/// Highlight the previous quick-open result.
class QuickOpenSelectPreviousIntent extends Intent {
  const QuickOpenSelectPreviousIntent();
}

/// Open the highlighted quick-open result.
class QuickOpenAcceptIntent extends Intent {
  const QuickOpenAcceptIntent();
}

// -- Find in files ----------------------------------------------------------

/// Reveal the find-in-files search panel in the sidebar.
class FindInFilesIntent extends Intent {
  const FindInFilesIntent();
}

// -- Text scale -------------------------------------------------------------

class TextScaleIncreaseIntent extends Intent {
  const TextScaleIncreaseIntent();
}

class TextScaleDecreaseIntent extends Intent {
  const TextScaleDecreaseIntent();
}

class TextScaleResetIntent extends Intent {
  const TextScaleResetIntent();
}

// -- Pane navigation (vim normal-mode motions outside the editor) ------------

/// Base for the preset-neutral navigation intents (T-406). A focused non-editor
/// pane (file tree, conversation, lists) runs its own [SequenceMatcher] and
/// dispatches the resolved [NavIntent] to its own handler — the vim preset binds
/// j/k/etc. to these; default/vscode/jetbrains can later bind arrows/page keys
/// to the same ids. Marker base so a pane's key handler can tell a nav motion
/// apart from any other fired intent.
sealed class NavIntent extends Intent {
  const NavIntent();
}

/// Move the selection / scroll down one step (vim `j`).
class NavDownIntent extends NavIntent {
  const NavDownIntent();
}

/// Move the selection / scroll up one step (vim `k`).
class NavUpIntent extends NavIntent {
  const NavUpIntent();
}

/// Scroll down half a viewport (vim `ctrl+d`).
class NavPageDownIntent extends NavIntent {
  const NavPageDownIntent();
}

/// Scroll up half a viewport (vim `ctrl+u`).
class NavPageUpIntent extends NavIntent {
  const NavPageUpIntent();
}

/// Jump to the first item / top (vim `gg`).
class NavTopIntent extends NavIntent {
  const NavTopIntent();
}

/// Jump to the last item / bottom (vim `G`).
class NavBottomIntent extends NavIntent {
  const NavBottomIntent();
}

/// Expand the focused node, or step into it / move right (vim `l`).
class NavExpandOrRightIntent extends NavIntent {
  const NavExpandOrRightIntent();
}

/// Collapse the focused node, or step out of it / move left (vim `h`).
class NavCollapseOrLeftIntent extends NavIntent {
  const NavCollapseOrLeftIntent();
}

/// Activate the focused item — open the file, run the row (vim `o` / `enter`).
class NavActivateIntent extends NavIntent {
  const NavActivateIntent();
}

// -- Command bridge ---------------------------------------------------------

/// Generic "invoke this CommandRegistry command id" intent. Used for
/// bindings that target a contributed command rather than a typed
/// intent. The keymap creates one per binding; the Actions handler
/// dispatches to the [CommandRegistry].
class InvokeCommandIntent extends Intent {
  const InvokeCommandIntent(this.commandId);
  final String commandId;
}

// -- Lookup -----------------------------------------------------------------

/// Map from YAML id → factory. Preset files reference intents by id;
/// the keymap loader uses this to instantiate them. Intents with a
/// configurable payload (only `InvokeCommandIntent` today) are not in
/// the map — the loader recognises the `command:` prefix and
/// instantiates them inline.
final Map<String, Intent Function()> builtinIntents = {
  'activate': () => const ActivateIntent(),
  'dismiss': () => const DismissIntent(),
  // Widget-level focus traversal (Tab / Shift+Tab). These are
  // Flutter-provided, like activate/dismiss — bound by id so the
  // default preset integrates with the framework's focus system. They
  // are distinct from the panel-to-panel cycling below (F6).
  'focus.next': () => const NextFocusIntent(),
  'focus.previous': () => const PreviousFocusIntent(),
  'focus.nextPanel': () => const FocusNextPanelIntent(),
  'focus.previousPanel': () => const FocusPreviousPanelIntent(),
  'palette.open': () => const PaletteOpenIntent(),
  'palette.selectNext': () => const PaletteSelectNextIntent(),
  'palette.selectPrevious': () => const PaletteSelectPreviousIntent(),
  'palette.accept': () => const PaletteAcceptIntent(),
  'quickOpen.open': () => const QuickOpenIntent(),
  'quickOpen.selectNext': () => const QuickOpenSelectNextIntent(),
  'quickOpen.selectPrevious': () => const QuickOpenSelectPreviousIntent(),
  'quickOpen.accept': () => const QuickOpenAcceptIntent(),
  'findInFiles.open': () => const FindInFilesIntent(),
  // Pane navigation (T-406) — preset-neutral; the vim preset binds j/k/etc.
  'nav.down': () => const NavDownIntent(),
  'nav.up': () => const NavUpIntent(),
  'nav.pageDown': () => const NavPageDownIntent(),
  'nav.pageUp': () => const NavPageUpIntent(),
  'nav.top': () => const NavTopIntent(),
  'nav.bottom': () => const NavBottomIntent(),
  'nav.expandOrRight': () => const NavExpandOrRightIntent(),
  'nav.collapseOrLeft': () => const NavCollapseOrLeftIntent(),
  'nav.activate': () => const NavActivateIntent(),
  'text.scaleIncrease': () => const TextScaleIncreaseIntent(),
  'text.scaleDecrease': () => const TextScaleDecreaseIntent(),
  'text.scaleReset': () => const TextScaleResetIntent(),
};

/// Parse an intent id into an [Intent]. Returns null if the id is
/// unknown. Recognises:
///   - any builtin intent by its stable id
///   - `command:<command-id>` → [InvokeCommandIntent]
Intent? parseIntentId(String id) {
  final builtin = builtinIntents[id];
  if (builtin != null) return builtin();
  if (id.startsWith('command:')) {
    return InvokeCommandIntent(id.substring('command:'.length));
  }
  return null;
}
