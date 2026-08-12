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

/// What one turn spent (T-556).
///
/// Deliberately a **delta**, never a running total: deltas add, and a ledger
/// that has to span session restarts can only be built out of things that add.
/// Every field below is "this turn", including [costUsd] — see the note there,
/// because the wire does not agree with itself on that point.
///
/// ## Where each number actually comes from
///
/// Measured against claude 2.1.226 by driving two turns through one session
/// (`docs/spikes/cc-stream-json-2.1.226.md` §9). The three shapes are NOT
/// interchangeable and picking the wrong one silently double-counts:
///
/// | Source | Semantics |
/// |---|---|
/// | `result.usage` | **this turn** |
/// | `result.modelUsage.<model>` | **cumulative** for the session |
/// | `result.total_cost_usd` | **cumulative** for the session |
///
/// So the token split is read from `result.usage` and the cost is differenced
/// against what the session has already reported.
///
/// **Thinking is the exception.** It appears in neither `result.usage` nor
/// `modelUsage` — only in `message_delta.usage.output_tokens_details`, which
/// arrives once per assistant message, before the turn's `result`. It is
/// therefore accumulated as messages complete and folded in at the turn
/// boundary. (`system/thinking_tokens` is a *different* number: the CLI's own
/// running estimate, which counts the signature blob and ran 2.7× high in the
/// probe. It is a liveness signal, not a token count.)
class TurnUsage {
  const TurnUsage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cacheCreationTokens = 0,
    this.cacheReadTokens = 0,
    this.thinkingTokens = 0,
    this.costUsd = 0,
  });

  /// Fresh input tokens — the expensive kind.
  final int inputTokens;

  /// Everything generated, thinking included. [thinkingTokens] is a *subset* of
  /// this, not an addition to it: a turn that output 103 tokens of which 96 were
  /// thinking spoke seven.
  final int outputTokens;

  /// Tokens written into the prompt cache. Priced above fresh input, and paid
  /// again on every turn that extends the cached prefix — which is why a
  /// long-lived companion session costs more per remark as it goes.
  final int cacheCreationTokens;

  /// Tokens read back from the cache — roughly a tenth the price of fresh
  /// input. A large total that is mostly this is a cheap total.
  final int cacheReadTokens;

  /// Of [outputTokens], how many were spent thinking rather than speaking.
  ///
  /// Haiku 4.5 thinks on every turn and no flag stops it, so for the companion
  /// this is never zero — and in the probe it was the overwhelming majority of
  /// the output. Broken out because "he spends more thinking than speaking" is
  /// an argument about the design that only this number can make.
  final int thinkingTokens;

  /// What this turn cost, in USD.
  ///
  /// A per-turn figure derived by differencing: the wire's `total_cost_usd` is
  /// **cumulative for the session**, which is the opposite of what its name
  /// suggests and of what one of clide's own comments used to claim. Verified:
  /// two turns reported $0.0353071 then $0.0393752, and the second exactly
  /// matched that session's cumulative `modelUsage.costUSD`.
  ///
  /// Real, but not a bill — under subscription auth nothing is charged. The
  /// currency is quota, which upstream does not expose at all.
  final double costUsd;

  /// Everything that crossed the wire, in both directions.
  int get totalTokens => inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens;

  /// Of [outputTokens], how many were actually said.
  int get spokenTokens => outputTokens - thinkingTokens;

  bool get isEmpty => totalTokens == 0 && costUsd == 0;

  /// Read the token split from a `result` event's `usage`.
  ///
  /// Cost is NOT read here — it needs the session's previous cumulative to
  /// difference against, which only the session knows. Thinking is not here
  /// either; the event does not carry it.
  factory TurnUsage.fromResult(Map<String, dynamic> ev) {
    final usage = ev['usage'];
    if (usage is! Map) return const TurnUsage();
    int n(String k) => (usage[k] as num?)?.toInt() ?? 0;
    return TurnUsage(
      inputTokens: n('input_tokens'),
      outputTokens: n('output_tokens'),
      cacheCreationTokens: n('cache_creation_input_tokens'),
      cacheReadTokens: n('cache_read_input_tokens'),
    );
  }

  /// Thinking tokens from a `message_delta` event's `usage`, or 0.
  ///
  /// A static rather than a constructor because it answers one narrow question
  /// and returning a whole [TurnUsage] here would invite someone to add it to
  /// the turn's — which double-counts, since the same tokens are already in the
  /// `result`'s `output_tokens`.
  static int thinkingFromMessageDelta(Map<String, dynamic> usage) {
    final details = usage['output_tokens_details'];
    if (details is! Map) return 0;
    return (details['thinking_tokens'] as num?)?.toInt() ?? 0;
  }

  TurnUsage copyWith({int? thinkingTokens, double? costUsd}) => TurnUsage(
    inputTokens: inputTokens,
    outputTokens: outputTokens,
    cacheCreationTokens: cacheCreationTokens,
    cacheReadTokens: cacheReadTokens,
    thinkingTokens: thinkingTokens ?? this.thinkingTokens,
    costUsd: costUsd ?? this.costUsd,
  );

  TurnUsage operator +(TurnUsage other) => TurnUsage(
    inputTokens: inputTokens + other.inputTokens,
    outputTokens: outputTokens + other.outputTokens,
    cacheCreationTokens: cacheCreationTokens + other.cacheCreationTokens,
    cacheReadTokens: cacheReadTokens + other.cacheReadTokens,
    thinkingTokens: thinkingTokens + other.thinkingTokens,
    costUsd: costUsd + other.costUsd,
  );

  @override
  bool operator ==(Object other) =>
      other is TurnUsage &&
      other.inputTokens == inputTokens &&
      other.outputTokens == outputTokens &&
      other.cacheCreationTokens == cacheCreationTokens &&
      other.cacheReadTokens == cacheReadTokens &&
      other.thinkingTokens == thinkingTokens &&
      other.costUsd == costUsd;

  @override
  int get hashCode => Object.hash(inputTokens, outputTokens, cacheCreationTokens, cacheReadTokens, thinkingTokens, costUsd);

  @override
  String toString() =>
      'TurnUsage(in: $inputTokens, out: $outputTokens (thinking $thinkingTokens), '
      'cacheWrite: $cacheCreationTokens, cacheRead: $cacheReadTokens, \$$costUsd)';
}
