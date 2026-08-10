/// The lines clide sends Clide (T-532, D-107).
///
/// Four kinds, each a different contract, all on one channel because the model
/// has one input. The tag is the contract — the brief explains what each means,
/// and this file is the only place they are produced.
///
/// ## Neutral speaker labels
///
/// `user:` and `claude:`, never a real name. Settled 2026-08-09: the developer's
/// name and self-description go into the **system prompt once** (see
/// [composeSystemPrompt]), so his context knows who he is watching without every
/// transcript line carrying it. A name repeated on every line is both wasteful
/// and, in his mouth, faintly creepy.
///
/// ## Absence is silence
///
/// There is deliberately no "nothing is happening" line, no heartbeat, and no
/// "the session ended" line. **Every line sent is an invitation to reply**, and a
/// line describing emptiness invites a remark about emptiness — which he would
/// be right to make, because we told him something. A digest turn with nothing
/// in it is not sent at all.
///
/// That rule governs this file only. `SessionLoad` still reports absence to the
/// rain, because a renderer that stops hearing about absence shows stale
/// weather. One is a signal to a painter; the other is text to a model, and
/// conflating them is how an ambient companion starts narrating the tooling.
library;

/// One watched exchange: what the developer asked, and what Claude said back.
///
/// Prose only — no tool calls, no results, no thinking (D-107 commitment 3). The
/// filtering is T-546's; this is the shape it produces.
///
/// Returns null when there is nothing to send. A prompt with no reply yet is not
/// an exchange, and sending half of one asks him to comment on an unfinished
/// thought.
String? observedExchange({required String prompt, required String reply}) {
  final p = prompt.trim(), r = reply.trim();
  if (p.isEmpty && r.isEmpty) return null;
  final lines = <String>[if (p.isNotEmpty) '[observed] user: $p', if (r.isNotEmpty) '[observed] claude: $r'];
  return lines.join('\n');
}

/// A question typed into Clide's own input. Always answered — the one case where
/// silence is wrong.
String directQuestion(String text) => '[direct] user: ${text.trim()}';

/// Something that happened which nobody said out loud.
///
/// The non-conversational half of D-107's trigger list — a turn failing, a
/// commit landing, a run crossing a threshold. These have no `user:`/`claude:`
/// shape, which is why they need their own tag rather than being dressed up as
/// dialogue: a fabricated line of conversation would be a lie about what was
/// said, and he reasons about what was said.
String eventNotice(String what) => '[event] ${what.trim()}';

/// A change in Clide's own situation.
///
/// Told, not asked. He is expected to let it inform the next thing he says and
/// otherwise ignore it — the brief says so — because a companion who comments on
/// his own lifecycle is narrating the tooling instead of the work.
String lifecycleNotice(String what) => '[notice] ${what.trim()}';

/// He was not being fed for a while, and now he is again (T-528 semantics).
///
/// **Warm, never wounded.** An earlier draft had him note the absence neutrally,
/// which reads as being left behind; the developer minimised a panel to get on
/// with their work and should not be met with anything resembling a grievance.
/// Equally it is not a greeting — he is not pleased to see you, he is simply
/// back.
///
/// He is told he *missed* it, not merely that time passed, because the useful
/// consequence is the gap in what he knows: without this he would reason about a
/// conversation that had moved on without him.
String detachedNotice(Duration away) =>
    lifecycleNotice('You were not watching for ${_roughly(away)} and missed whatever happened in that time. You are watching again now.');

/// The primary conversation was cleared, and his went with it.
///
/// Sent into the *new* session as opening context rather than to the old one:
/// by the time this is true, the session that held the old conversation is gone.
/// He is told because otherwise his first remark in a fresh session reads as
/// amnesia — "sounds like you're getting started" three hours into the day.
const String clearedNotice = '[notice] The conversation you were watching was cleared and started over. Whatever came before is gone, for them and for you.';

/// Coarse, human duration. Never "0 minutes".
///
/// Rounded hard on purpose: precision here would be false, since the gap is
/// measured from when the strip closed rather than from when he last had
/// anything worth hearing, and an exact figure invites him to treat it as
/// significant.
String _roughly(Duration d) {
  if (d.inMinutes < 2) return 'a minute or two';
  if (d.inMinutes < 50) return 'about ${d.inMinutes} minutes';
  if (d.inHours < 2) return 'about an hour';
  if (d.inHours < 8) return 'about ${d.inHours} hours';
  return 'a long while';
}
