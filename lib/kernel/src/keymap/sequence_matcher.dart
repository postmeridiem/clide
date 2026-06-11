/// Stateful multi-chord matcher (D-82, T-205).
///
/// Wraps a [Keymap]'s stateless [Keymap.match] query with a pending-chord
/// buffer, a Vim repeat-count prefix, and the prefix/timeout bookkeeping a
/// real key handler needs. It is deliberately headless: it neither reads
/// the keyboard nor swallows events. The consumer (the editor's
/// `Focus.onKeyEvent`, T-206) feeds it chords and acts on the [SeqResult] —
/// the global key handler can't, because it's a passive `KeyboardListener`
/// that can't consume events (D-82).
library;

import 'package:flutter/widgets.dart' show Intent, immutable;

import 'key_chord.dart';
import 'keymap.dart';

enum SeqOutcome {
  /// A binding's full sequence matched — fire [SeqResult.intent],
  /// [SeqResult.count] times.
  fired,

  /// The buffer is a live prefix of a longer binding (or a pure count so
  /// far). The consumer should swallow the key and wait for more input;
  /// start/refresh a timeout and call [SequenceMatcher.flush] when it
  /// expires.
  pending,

  /// The buffer matches nothing. [SeqResult.passKey] is the lone key the
  /// consumer should let through to normal text handling (insert a char);
  /// null when a multi-chord sequence simply broke and is discarded.
  unmatched,
}

@immutable
class SeqResult {
  const SeqResult.fired(Intent this.intent, this.count) : outcome = SeqOutcome.fired, passKey = null;
  const SeqResult.pending() : outcome = SeqOutcome.pending, intent = null, count = 1, passKey = null;
  const SeqResult.unmatched(this.passKey) : outcome = SeqOutcome.unmatched, intent = null, count = 1;

  final SeqOutcome outcome;
  final Intent? intent;
  final int count;
  final KeyChord? passKey;
}

class SequenceMatcher {
  SequenceMatcher({required Keymap Function() keymap, required Map<String, bool> Function() context, this.captureCounts = true})
    : _keymap = keymap,
      _context = context;

  final Keymap Function() _keymap;
  final Map<String, bool> Function() _context;

  /// When true, a leading digit run (`5` in `5j`) is captured as a repeat
  /// count rather than treated as a key. `0` is never a leading count
  /// digit — in Vim it's the line-start motion.
  final bool captureCounts;

  final List<KeyChord> _pending = [];
  int _count = 0;
  Intent? _pendingExact;

  /// Number of chords buffered (excludes any count prefix).
  int get pendingLength => _pending.length;

  /// The effective repeat count (>= 1).
  int get count => _count == 0 ? 1 : _count;

  /// Whether any input is buffered (a count and/or a partial sequence).
  bool get hasPending => _pending.isNotEmpty || _count > 0;

  void reset() {
    _pending.clear();
    _count = 0;
    _pendingExact = null;
  }

  /// Feed the next chord. See [SeqOutcome] for how to act on the result.
  SeqResult feed(KeyChord chord) {
    // Count prefix — only between sequences, never mid-sequence.
    if (captureCounts && _pending.isEmpty) {
      final d = chord.digit;
      if (d != null && !(d == 0 && _count == 0)) {
        _count = _count * 10 + d;
        return const SeqResult.pending();
      }
    }

    _pending.add(chord);
    final m = _keymap().match(_pending, _context());

    if (m.exact != null && !m.isPrefix) {
      final r = SeqResult.fired(m.exact!, count);
      reset();
      return r;
    }
    if (m.isPrefix) {
      // A longer binding could still complete. If an exact match also
      // exists (`d` while `dd` is bound), stash it to fire on timeout.
      _pendingExact = m.exact;
      return const SeqResult.pending();
    }

    // Nothing matches and nothing extends the buffer.
    if (_pending.length == 1) {
      final only = _pending.first;
      reset();
      return SeqResult.unmatched(only);
    }
    // A multi-chord sequence broke; discard it but let the last chord
    // start a fresh sequence (matches Vim's behaviour).
    final last = _pending.last;
    reset();
    return feed(last);
  }

  /// Resolve a wait (timeout elapsed, focus lost, …). Fires a buffered
  /// exact match if one is pending (the `d`-vs-`dd` case); otherwise lets
  /// a lone buffered key through; otherwise a no-op.
  SeqResult flush() {
    final exact = _pendingExact;
    final c = count;
    final lone = _pending.length == 1 ? _pending.first : null;
    reset();
    if (exact != null) return SeqResult.fired(exact, c);
    if (lone != null) return SeqResult.unmatched(lone);
    return const SeqResult.pending();
  }
}
