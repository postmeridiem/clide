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
