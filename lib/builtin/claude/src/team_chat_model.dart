/// The shared chat model for team broker traffic (T-180).
///
/// Subscribes to the broker's [TeamBroker.messages] stream and keeps an
/// append-only timeline of [TeamMessage]s. Both the compact sidebar widget
/// and the full workspace pane read from this one model — they share state,
/// they do NOT each hold their own copy.
///
/// [postAsUser] is the user's write path: it routes by @tag (one agent or
/// broadcast) and, when the interrupt flag is set, calls [interrupt()] on the
/// target session THEN delivers the message.
///
/// Flutter-free on purpose: this module (like [TeamBroker]) runs under
/// `dart test`. Use [dart:async] Stream/StreamController for observability;
/// do NOT use [ChangeNotifier].
library;

import 'dart:async';

import 'package:clide/builtin/claude/src/team_broker.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';

/// Resolves a session by orchestrator member name — injected by the
/// orchestrator so the model doesn't depend on the Flutter-coupled
/// [ClaudeSessionOrchestrator] type directly.
typedef SessionResolver = StreamJsonSession? Function(String memberName);

/// The shared timeline + user-post logic for team broker chat (T-180).
///
/// Lifetime matches the orchestrator: created once, subscribed to the broker,
/// disposed when the orchestrator is torn down.
class TeamChatModel {
  TeamChatModel({
    required TeamBroker broker,
    SessionResolver? sessionResolver,
  })  : _broker = broker,
        _sessionResolver = sessionResolver {
    _sub = broker.messages.listen(_onMessage);
  }

  final TeamBroker _broker;
  final SessionResolver? _sessionResolver;
  late final StreamSubscription<TeamMessage> _sub;

  final _messages = <TeamMessage>[];

  final _changeCtl = StreamController<void>.broadcast();

  /// All broker messages in arrival order. Unmodifiable snapshot; new messages
  /// are signalled via [changes].
  List<TeamMessage> get messages => List.unmodifiable(_messages);

  /// Fires a void event whenever a new message is appended. Broadcast —
  /// multiple listeners are supported. Flutter-free.
  Stream<void> get changes => _changeCtl.stream;

  void _onMessage(TeamMessage msg) {
    _messages.add(msg);
    if (!_changeCtl.isClosed) _changeCtl.add(null);
  }

  // ---------------------------------------------------------------------------
  // User post path
  // ---------------------------------------------------------------------------

  /// Post [text] as the user into the broker channel.
  ///
  /// - [toName] `null` or `'team'` → broadcast to all agents.
  /// - [toName] a specific member name → `send_message(to: toName)`.
  /// - [interrupt] `true` → call [StreamJsonSession.interrupt] on the target
  ///   session first (cancels its current turn), then deliver. Default false.
  ///
  /// The message is also appended to the local timeline immediately so the
  /// user sees it without waiting for the broker echo.
  void postAsUser(String text, {String? toName, bool interrupt = false}) {
    final from = 'user';
    final isTeam = toName == null || toName.isEmpty || toName == 'team';

    if (interrupt && !isTeam) {
      // isTeam is false only when toName is a non-null, non-empty, non-'team'
      // string, so Dart's flow analysis promotes it to non-null here.
      _sessionResolver?.call(toName)?.interrupt();
    }

    if (isTeam) {
      // Broadcast: create a local record and deliver via the broker.
      final msg = TeamMessage(from: from, to: null, text: text, at: DateTime.now(), broadcast: true);
      _messages.add(msg);
      if (!_changeCtl.isClosed) _changeCtl.add(null);
      _broker.sendAsUser(text);
    } else {
      // Directed message.
      final msg = TeamMessage(from: from, to: toName, text: text, at: DateTime.now());
      _messages.add(msg);
      if (!_changeCtl.isClosed) _changeCtl.add(null);
      _broker.sendAsUser(text, to: toName);
    }
  }

  /// Dispose — cancels the broker subscription and closes the changes stream.
  void dispose() {
    _sub.cancel();
    _changeCtl.close();
  }
}
