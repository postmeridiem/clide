/// What Clide has cost, shown where his words are (T-556, D-107).
///
/// The companion spends the same subscription quota that rate-limits the
/// primary session. Putting the number in the popout — rather than in settings,
/// or the status bar, or nowhere — means the trade-off is legible **at the
/// moment you are reading what you paid for**, which is the only moment it is
/// actually a trade-off rather than a statistic.
///
/// ## Why the split and not just a total
///
/// A bare number is a curiosity. Cache reads are roughly a tenth the price of
/// fresh input, so a large total that is mostly cache reads is cheap and a small
/// one that is mostly cache *writes* is not — the total alone cannot tell those
/// apart, and the total alone is what would mislead.
///
/// Thinking gets its own place for a different reason. Haiku 4.5 thinks on every
/// turn and no flag stops it; measured, it took 96 of 103 output tokens on a
/// one-line quip. If Clide spends most of his output budget thinking rather than
/// speaking, that is an argument about the design, and this is the only surface
/// that can make it.
///
/// ## The dollar figure is an equivalent, not an invoice
///
/// `total_cost_usd` is real and it is what the API would charge — but under
/// subscription auth **nothing is billed**. The true currency is quota, which
/// upstream does not expose in any file, CLI or API (see T-141: `/usage` is
/// TUI-only). Stating the number without that caveat would be read as a bill,
/// so the caveat rides with it rather than living in a doc nobody opens.
library;

import 'package:clide/builtin/claude/src/claude_status.dart' show formatTokenCount;
import 'package:clide/builtin/claude/src/turn_signals.dart';
import 'package:clide/widgets/src/clide_settings.dart';
import 'package:clide/widgets/src/clide_text.dart';
import 'package:clide/widgets/src/clide_tooltip.dart';
import 'package:clide/widgets/src/typography.dart';
import 'package:flutter/widgets.dart';

/// Format the spend as the two lines the popout shows.
///
/// Pure, and exposed for testing: the phrasing is the substance of this file and
/// asserting it through a rendered widget tree would test Flutter instead.
({String headline, String split}) formatCompanionUsage({required TurnUsage total, required int turns, required String Function(String, String) t}) {
  final headline = [
    t('usage.turns', '$turns').trim(),
    t('usage.tokens', formatTokenCount(total.totalTokens)).trim(),
    t('usage.equivalent', '\$${total.costUsd.toStringAsFixed(2)}').trim(),
  ].join('  ·  ');

  final split = [
    t('usage.cacheRead', formatTokenCount(total.cacheReadTokens)).trim(),
    t('usage.cacheWrite', formatTokenCount(total.cacheCreationTokens)).trim(),
    // Spoken before thinking: what he said is the thing, what it took to say it
    // is the commentary.
    t('usage.spoken', formatTokenCount(total.spokenTokens)).trim(),
    t('usage.thinking', formatTokenCount(total.thinkingTokens)).trim(),
  ].join('  ·  ');

  return (headline: headline, split: split);
}

/// The stat itself. Renders nothing at all before his first turn — a row of
/// zeros reads as a broken instrument rather than as an idle one.
class CompanionUsageLine extends StatelessWidget {
  const CompanionUsageLine({super.key, required this.total, required this.turns});

  final TurnUsage total;
  final int turns;

  @override
  Widget build(BuildContext context) {
    if (turns == 0) return const SizedBox.shrink();
    final tokens = ClideSettings.theme.of(context).surface;

    // Written out one call per key rather than looped over a table, because the
    // i18n coverage test greps the source for literal keys (T-530) — a key
    // assembled from a variable is invisible to it, and a key nobody can see is
    // one nobody notices going untranslated.
    String t(String key, String n) => switch (key) {
      'usage.turns' => ClideSettings.i18n.interpolated(
        context,
        'usage.turns',
        namespace: 'builtin.clide-companion',
        placeholder: '$n turns',
        replacers: [I18nReplacer(from: '{n}', replace: n)],
      ),
      'usage.tokens' => ClideSettings.i18n.interpolated(
        context,
        'usage.tokens',
        namespace: 'builtin.clide-companion',
        placeholder: '$n tokens',
        replacers: [I18nReplacer(from: '{n}', replace: n)],
      ),
      'usage.equivalent' => ClideSettings.i18n.interpolated(
        context,
        'usage.equivalent',
        namespace: 'builtin.clide-companion',
        placeholder: '≈$n equivalent',
        replacers: [I18nReplacer(from: '{n}', replace: n)],
      ),
      'usage.cacheRead' => ClideSettings.i18n.interpolated(
        context,
        'usage.cacheRead',
        namespace: 'builtin.clide-companion',
        placeholder: '$n cache read',
        replacers: [I18nReplacer(from: '{n}', replace: n)],
      ),
      'usage.cacheWrite' => ClideSettings.i18n.interpolated(
        context,
        'usage.cacheWrite',
        namespace: 'builtin.clide-companion',
        placeholder: '$n cache write',
        replacers: [I18nReplacer(from: '{n}', replace: n)],
      ),
      'usage.spoken' => ClideSettings.i18n.interpolated(
        context,
        'usage.spoken',
        namespace: 'builtin.clide-companion',
        placeholder: '$n spoken',
        replacers: [I18nReplacer(from: '{n}', replace: n)],
      ),
      _ => ClideSettings.i18n.interpolated(
        context,
        'usage.thinking',
        namespace: 'builtin.clide-companion',
        placeholder: '$n thinking',
        replacers: [I18nReplacer(from: '{n}', replace: n)],
      ),
    };

    final lines = formatCompanionUsage(total: total, turns: turns, t: t);

    final caveat = ClideSettings.i18n.string(
      context,
      'usage.costCaveat',
      namespace: 'builtin.clide-companion',
      placeholder:
          'What the API would charge for this. Under a subscription nothing is billed — '
          'the real cost is quota, shared with your main session, which Claude Code does not report.',
    );

    return Semantics(
      // A pull, not a push (D-20): read on request, never announced. A running
      // total interrupting a screen-reader user mid-output would be the exact
      // failure T-567 avoided for his remarks.
      label: '${lines.headline}. ${lines.split}. $caveat',
      excludeSemantics: true,
      child: ClideTooltip(
        message: caveat,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClideText(lines.headline, color: tokens.globalTextMuted, fontSize: clideFontCaption, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            ClideText(lines.split, color: tokens.globalTextMuted, fontSize: clideFontSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
