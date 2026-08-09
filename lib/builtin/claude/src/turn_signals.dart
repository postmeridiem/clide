/// Turn-level signals the CLI already emits and clide used to discard (T-557).
///
/// Both shapes below were verified against the real binary at claude 2.1.226
/// (`docs/spikes/cc-stream-json-2.1.226.md`) rather than inferred. They are not
/// new capabilities: `_onStreamEvent` gates on `text_delta` and `_statusFromEvent`
/// reads only cost and context window, so everything here was arriving and being
/// dropped on the floor.
///
/// Flutter-free, so it stays usable from `dart test`.
library;

/// What the model is doing inside the current turn.
///
/// Replaces the inference clide has been resting on — "busy with no `partial-`
/// item yet means thinking" — which was never sound: the final assistant event
/// is rewritten to carry the same `partial-` uuid, so the prefix means "came
/// through the streaming path", not "arriving now".
enum TurnPhase {
  /// No turn in flight, or the turn has ended.
  idle,

  /// A `thinking` content block is streaming.
  ///
  /// Haiku 4.5 does this unprompted on every turn and no CLI flag stops it, so
  /// for the companion this is the common opening phase rather than an
  /// exception.
  thinking,

  /// A `text` content block is streaming — the reply proper.
  answering,
}

/// How a turn ended, from the `result` event.
///
/// The fields exist on every result and none of them were read. The Epic B
/// signal audit concluded there was no source for an API-error reaction; there
/// is, and this is it.
class TurnOutcome {
  const TurnOutcome({required this.isError, this.stopReason, this.terminalReason, this.apiErrorStatus});

  /// The CLI's own verdict on the turn.
  final bool isError;

  /// Why generation stopped — `end_turn`, `max_tokens`, … Null when absent.
  final String? stopReason;

  /// Why the turn terminated — `completed`, … Distinct from [stopReason]: one
  /// is the model's reason for stopping, the other the CLI's for finishing.
  final String? terminalReason;

  /// Set when the failure came from the API rather than from the CLI. Null on a
  /// clean turn, and null on a CLI-side failure — so it distinguishes *whose*
  /// error it was, which matters when deciding whether retrying could help.
  final Object? apiErrorStatus;

  /// Parse from a `result` event, which is the only place these appear.
  factory TurnOutcome.fromResult(Map<String, dynamic> ev) => TurnOutcome(
    isError: ev['is_error'] == true,
    stopReason: ev['stop_reason'] as String?,
    terminalReason: ev['terminal_reason'] as String?,
    apiErrorStatus: ev['api_error_status'],
  );

  @override
  String toString() => 'TurnOutcome(isError: $isError, stop: $stopReason, terminal: $terminalReason, api: $apiErrorStatus)';
}
