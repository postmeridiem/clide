/// Typed [Intent]s the keymap dispatches.
///
/// Widgets bind Actions to Intent types via `Actions.handler`. Preset
/// YAML files reference Intents by their string id (`activate`,
/// `palette.selectNext`, …). The id stays stable across SDK reshapes;
/// the Dart class name can move without invalidating user keymaps.
///
/// To add a new Intent: declare a subclass with a unique [id] and
/// register it in [allIntents]. Widget integration is per-feature
/// (Actions wiring lives in the consuming widget).
library;

import 'package:flutter/widgets.dart';

/// Base for every keymap-dispatched intent. The [id] is the YAML
/// identifier (e.g. `palette.selectNext`).
abstract class ClideIntent extends Intent {
  const ClideIntent();
  String get id;
}

// -- Activation / navigation ------------------------------------------------

/// "Click this thing" — fired on Enter/Space against any focusable
/// `ClideTappable`-rooted widget.
class ActivateIntent extends ClideIntent {
  const ActivateIntent();
  @override
  String get id => 'activate';
}

/// "Cancel / dismiss the current modal / overlay".
class DismissIntent extends ClideIntent {
  const DismissIntent();
  @override
  String get id => 'dismiss';
}

/// "Move focus to the next focusable in tab order".
class FocusNextIntent extends ClideIntent {
  const FocusNextIntent();
  @override
  String get id => 'focus.next';
}

/// "Move focus to the previous focusable".
class FocusPreviousIntent extends ClideIntent {
  const FocusPreviousIntent();
  @override
  String get id => 'focus.previous';
}

// -- Command palette --------------------------------------------------------

/// Open the command palette.
class PaletteOpenIntent extends ClideIntent {
  const PaletteOpenIntent();
  @override
  String get id => 'palette.open';
}

/// Highlight the next palette result.
class PaletteSelectNextIntent extends ClideIntent {
  const PaletteSelectNextIntent();
  @override
  String get id => 'palette.selectNext';
}

/// Highlight the previous palette result.
class PaletteSelectPreviousIntent extends ClideIntent {
  const PaletteSelectPreviousIntent();
  @override
  String get id => 'palette.selectPrevious';
}

/// Invoke the highlighted palette result.
class PaletteAcceptIntent extends ClideIntent {
  const PaletteAcceptIntent();
  @override
  String get id => 'palette.accept';
}

// -- Text scale -------------------------------------------------------------

class TextScaleIncreaseIntent extends ClideIntent {
  const TextScaleIncreaseIntent();
  @override
  String get id => 'text.scaleIncrease';
}

class TextScaleDecreaseIntent extends ClideIntent {
  const TextScaleDecreaseIntent();
  @override
  String get id => 'text.scaleDecrease';
}

class TextScaleResetIntent extends ClideIntent {
  const TextScaleResetIntent();
  @override
  String get id => 'text.scaleReset';
}

// -- Command bridge ---------------------------------------------------------

/// Generic "invoke this CommandRegistry command id" intent. Used for
/// bindings that target a contributed command rather than a typed
/// intent. The keymap creates one per binding; the Actions handler
/// dispatches to the [CommandRegistry].
class InvokeCommandIntent extends ClideIntent {
  const InvokeCommandIntent(this.commandId);
  final String commandId;
  @override
  String get id => 'command:$commandId';
}

// -- Lookup -----------------------------------------------------------------

/// Map from YAML id → factory. Preset files reference intents by id;
/// the keymap loader uses this to instantiate them. Intents with a
/// configurable payload (only `InvokeCommandIntent` today) are not in
/// the map — the loader recognises the `command:` prefix and
/// instantiates them inline.
final Map<String, ClideIntent Function()> builtinIntents = {
  for (final i in _allBuiltin) i.id: () => i,
};

const List<ClideIntent> _allBuiltin = [
  ActivateIntent(),
  DismissIntent(),
  FocusNextIntent(),
  FocusPreviousIntent(),
  PaletteOpenIntent(),
  PaletteSelectNextIntent(),
  PaletteSelectPreviousIntent(),
  PaletteAcceptIntent(),
  TextScaleIncreaseIntent(),
  TextScaleDecreaseIntent(),
  TextScaleResetIntent(),
];

/// Parse an intent id into a [ClideIntent]. Returns null if the id is
/// unknown. Recognises:
///   - any builtin intent by its stable id
///   - `command:<command-id>` → [InvokeCommandIntent]
ClideIntent? parseIntentId(String id) {
  final builtin = builtinIntents[id];
  if (builtin != null) return builtin();
  if (id.startsWith('command:')) {
    return InvokeCommandIntent(id.substring('command:'.length));
  }
  return null;
}
