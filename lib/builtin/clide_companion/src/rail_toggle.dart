/// The minimise/restore control for the Clide strip (T-528).
///
/// Lives as the last item in the context panel's bottom icon rail, drawn like
/// the tabs beside it but behaving unlike them: it does not change which detail
/// view is showing, it toggles whether Clide is there at all.
///
/// **It cannot live on the strip.** The control that brings Clide back must
/// survive his going away, and anything inside the strip disappears with it.
///
/// **It is not a caret**, deliberately. `StatusbarCollapseToggle` sits
/// immediately to the right of this rail and collapses the entire context
/// panel; two adjacent controls that both look like "hide something" is the
/// failure mode this placement has to design against. A face reads as *Clide*
/// rather than as a second hide button.
library;

import 'package:clide/builtin/clide_companion/src/companion_channel.dart';
import 'package:clide/builtin/clide_companion/src/companion_state.dart';
import 'package:clide/kernel/src/facade.dart' show ClideKernel;
import 'package:clide/widgets/src/clide_icon_rail.dart';
import 'package:clide/widgets/src/clide_settings.dart';
import 'package:clide/widgets/src/icons/phosphor.dart';
import 'package:flutter/widgets.dart';

/// Namespace for this control's strings — the companion's, not the shell's.
const _ns = 'builtin.clide-companion';

/// Rail id. Must not collide with a tab contribution id, since both are drawn
/// from the same rail.
const kCompanionRailToggleId = 'clide.companion.toggle';

/// The toggle for [state], or null when the companion is disabled for this repo.
///
/// Disabled hides the control as well: a dead button that only settings can
/// revive is worse than no button, and "off is off for the repo" means the
/// companion leaves no trace in the chrome.
ClideIconRailToggle? companionRailToggle(BuildContext context, CompanionState state) {
  if (!state.enabled) return null;
  final messages = ClideKernel.maybeOf(context)?.messages;
  if (messages == null) return null;

  final tooltip = state.open
      ? ClideSettings.i18n.string(context, 'rail.minimise', namespace: _ns, placeholder: 'Minimise Clide')
      : ClideSettings.i18n.string(context, 'rail.restore', namespace: _ns, placeholder: 'Show Clide');

  return ClideIconRailToggle(
    id: kCompanionRailToggleId,
    icon: PhosphorIcons.byName('smiley'),
    tooltip: tooltip,
    on: state.open,
    // Publish rather than write: the extension owns persistence and is the only
    // thing that announces, so the rail button does not need to know where the
    // preference lives or who else is listening (T-527).
    onToggle: (open) => publishCompanionSet(messages, open: open),
  );
}
