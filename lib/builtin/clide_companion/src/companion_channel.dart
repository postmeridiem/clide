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

// The primary session's load used to travel here too, on `companion.load` plus
// a `companion.load.ask` handshake. Both are gone (T-561): the strip reads a
// `SessionReader` directly now that one exists, and the ask/answer was the only
// request/response pattern in the codebase — invented for a retention problem
// `FilterStateCache` had already solved. Load never spanned surfaces; it went
// out to the bus and came back to a single widget.

/// Ask for a companion state change. The extension is what actually applies it.
void publishCompanionSet(MessageBus messages, {bool? enabled, bool? open, String? frequency}) {
  messages.publish(clideCompanionPublisher, companionSetChannel, {'enabled': ?enabled, 'open': ?open, 'frequency': ?frequency});
}

/// Announce the applied state. Extension-only — a surface that publishes this
/// itself would be reporting a change it has not persisted.
void publishCompanionState(MessageBus messages, {required bool enabled, required bool open, required String frequency}) {
  messages.publish(clideCompanionPublisher, companionStateChannel, {'enabled': enabled, 'open': open, 'frequency': frequency});
}
