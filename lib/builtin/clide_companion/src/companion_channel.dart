/// The companion's MessageBus addressing (T-527, D-107).
///
/// Everything that talks *to* the strip goes through here rather than holding a
/// reference to it. The strip is one widget deep inside the context column, and
/// the things that need to change it are scattered — the settings panel, the
/// rail button (T-528), the CLI verbs (T-529), and eventually the session
/// itself (T-519). Wiring those to the widget directly would mean four callers
/// each needing a handle to a thing they cannot reach.
///
/// Two channels, the same drive/observe split the filter boxes use (T-270):
///
///  * [companionSetChannel] — *asks* for a change. Anyone may publish.
///  * [companionStateChannel] — *announces* the current state. Only the
///    extension publishes, after it has written the preference. Everything that
///    renders listens here, so the persisted value and what is on screen cannot
///    disagree.
///
/// The bus is a plain broadcast stream with no retention, so a subscriber that
/// mounts late has missed everything. Renderers therefore seed from the stored
/// preference once and follow the bus after that: the store holds the initial
/// truth, the bus carries the changes.
library;

import 'package:clide/kernel/src/events/message_bus.dart';

/// Publisher address for every companion message.
const clideCompanionPublisher = 'clide.companion';

/// Announces the companion's current state. Data keys mirror the preferences:
/// `enabled`, `open`, `frequency`.
const companionStateChannel = 'companion.state';

/// Requests a change. Carries only the keys it wants changed — a rail button
/// publishes `{'open': false}` and says nothing about `enabled`.
const companionSetChannel = 'companion.set';

/// Announces what the **primary** session is doing — the weather, not Clide
/// (D-107 commitment 5). Data: `busy`, and `busySinceMs` while it is.
///
/// Observe-only; there is no `set` counterpart, because nobody may ask the
/// primary session to look busy.
const companionLoadChannel = 'companion.load';

/// Announce the primary session's load.
///
/// [busySinceMs] is epoch milliseconds for the moment the current turn started,
/// null when idle. **The publisher stamps it**, because nothing upstream records
/// it — `_setBusy(true)` keeps no time — and because a renderer that timed turns
/// from its own prop changes would only be guessing.
void publishCompanionLoad(MessageBus messages, {required bool busy, int? busySinceMs}) {
  messages.publish(clideCompanionPublisher, companionLoadChannel, {'busy': busy, 'busySinceMs': ?busySinceMs});
}

/// Ask for a companion state change. The extension is what actually applies it.
void publishCompanionSet(MessageBus messages, {bool? enabled, bool? open, String? frequency}) {
  messages.publish(clideCompanionPublisher, companionSetChannel, {'enabled': ?enabled, 'open': ?open, 'frequency': ?frequency});
}

/// Announce the applied state. Extension-only — a surface that publishes this
/// itself would be reporting a change it has not persisted.
void publishCompanionState(MessageBus messages, {required bool enabled, required bool open, required String frequency}) {
  messages.publish(clideCompanionPublisher, companionStateChannel, {'enabled': enabled, 'open': open, 'frequency': frequency});
}
