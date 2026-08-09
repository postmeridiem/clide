/// How anything reads Clide's own session (T-555).
///
/// The fourth consumer of the shared reader (epic T-550), and the one that
/// proves the interface is not quietly primary-only: the first three all read
/// the primary session, so an interface that assumed it would have passed every
/// migration and failed here.
///
/// Deliberately tiny. It names the id and hands back a reader — the session's
/// *lifecycle* is T-545's, the digest is T-546's, and what is done with his
/// replies is T-548's. Those three can now be written without any of them
/// touching the orchestrator, which is this ticket's whole job.
library;

import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/session_reader.dart';

/// Orchestrator id for the companion, in clide's own namespace.
///
/// Namespaced rather than a bare name because Clide is a clide-owned session
/// sitting alongside the user's: the prefix is what lets clide recognise its own
/// — filtering companion transcripts out of the `/resume` picker (T-545) becomes
/// a namespace check rather than a guess at a transcript's contents.
///
/// Matches [clideCompanionPublisher] on the bus by construction: one name for
/// one thing, whichever channel it travels on.
const kCompanionSessionId = 'clide.companion';

/// A reader following Clide's session.
///
/// A function rather than a singleton: readers are cheap, each consumer owns
/// and disposes its own, and a shared instance would make teardown everyone's
/// problem. What must not be duplicated is the *id*, and that is the constant
/// above.
SessionReader companionSessionReader({ClaudeSessionOrchestrator? orchestrator}) => SessionReader(sessionId: kCompanionSessionId, orchestrator: orchestrator);
