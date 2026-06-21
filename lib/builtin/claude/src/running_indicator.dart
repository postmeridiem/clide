/// In-flight turn indicator (T-255): a Claude-accent-coloured, animated label shown next to the
/// Stop button while a Claude turn runs. Animated ellipsis (`Pondering` →
/// `Pondering.` → `..` → `...`) plus a verb that rotates every few seconds.
///
/// The verbs are clide-owned, NOT the Claude Code CLI's: that list is a TUI
/// cosmetic the stream-json protocol doesn't expose, and reusing the bundled
/// strings is a licensing gray area — a curated list keeps us self-contained
/// (own-the-rendering-stack, D-75). Animation is driven off a single
/// [AnimationController]'s value (no timers) so tests advance it with bounded
/// pumps; reduced-motion shows a static verb and the a11y label stays stable.
library;

import 'package:clide/builtin/claude/src/conversation_view.dart' show claudeAccent;
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// Curated, on-brand present participles. Muted and tasteful — not the CLI's.
const List<String> runningVerbs = [
  'Pondering',
  'Conjuring',
  'Brewing',
  'Tinkering',
  'Noodling',
  'Percolating',
  'Computing',
  'Wrangling',
  'Untangling',
  'Synthesizing',
  'Cogitating',
  'Whirring',
  'Mincing',
  'Boiling',
  'Humming',
  'Buzzing',
  'Magicking',
  'Cliding',
  'Zooming',
  'Bouncing',
];

/// Seconds each verb is shown before rotating to the next.
const int _secondsPerWord = 4;

class RunningIndicator extends StatefulWidget {
  const RunningIndicator({super.key, this.shuffle = true});

  /// Randomize the rotation order per turn so you don't always see the same
  /// sequence. Off in tests for deterministic assertions.
  final bool shuffle;

  @override
  State<RunningIndicator> createState() => _RunningIndicatorState();
}

class _RunningIndicatorState extends State<RunningIndicator> with SingleTickerProviderStateMixin {
  /// The verbs for this turn — a shuffled copy in production, the canonical
  /// order in tests. Same length, so the period is unchanged.
  late final List<String> _verbs = widget.shuffle ? (List<String>.of(runningVerbs)..shuffle()) : runningVerbs;

  // One full pass over every verb; value 0→1 maps linearly to elapsed seconds.
  static final int _periodSeconds = runningVerbs.length * _secondsPerWord;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(seconds: _periodSeconds),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduced) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    // The animated text is decorative; AT gets one stable label.
    return Semantics(
      label: ClideSettings.i18n.string(context, 'running.semantics', namespace: 'builtin.claude', placeholder: 'Claude is running'),
      child: ExcludeSemantics(
        child: reduced
            ? ClideText('${_verb(context, _verbs.first)}…', color: claudeAccent, fontSize: clideFontMeta)
            : AnimatedBuilder(
                animation: _c,
                builder: (ctx, _) {
                  final elapsed = _c.value * _periodSeconds;
                  final dots = '.' * (elapsed.floor() % 4);
                  final word = _verbs[(elapsed ~/ _secondsPerWord) % _verbs.length];
                  return ClideText('${_verb(ctx, word)}$dots', color: claudeAccent, fontSize: clideFontMeta);
                },
              ),
      ),
    );
  }

  /// Localize a verb through the catalog; the English word doubles as the key
  /// suffix and the fallback, so a missing translation degrades to English.
  String _verb(BuildContext context, String word) =>
      ClideSettings.i18n.string(context, 'running.verb.${word.toLowerCase()}', namespace: 'builtin.claude', placeholder: word);
}
