/// Clide's conversation, opened over the detail area (T-566, D-107).
///
/// The answer surface. The strip is 112px and stays that way — an earlier
/// attempt grew it to fit long replies and was reverted (T-565): growth is the
/// fiddly half of the T-514 answer-space decision and this is the valuable half.
/// A long answer opens somewhere built for reading, and the strip goes on being
/// a fixed-height ambient surface, which is what it is good at.
///
/// ## It reads his real transcript
///
/// Nothing bespoke. D-107 was amended to drop `--no-session-persistence`, so the
/// companion writes an ordinary `<uuid>.jsonl` like any other session and clide
/// already holds it in a [ConversationController]. **That dissolved T-534**, a
/// ticket for a hand-rolled append-only log written when there was no record of
/// anything Clide said.
///
/// ## The filter runs in the other direction
///
/// The digest decides what Clide may *see* (T-546). This decides what the
/// developer may see *of Clide*, and the answer is: his own words, and the
/// questions put to him. Never the `[observed]` lines — those are the
/// developer's own conversation, and showing it back to them inside Clide's
/// window would be a strange mirror. Never the `[notice]` and `[event]` lines
/// either; those are bookkeeping he was told, not things anyone said.
///
/// Same allow-list discipline as the digest, for the same reason: a new line
/// kind must be invisible here until somebody decides otherwise.
library;

import 'package:clide/builtin/claude/src/conversation_controller.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:clide/builtin/clide_companion/src/ask_box.dart';
import 'package:clide/builtin/clide_companion/src/companion_ledger.dart';
import 'package:clide/builtin/clide_companion/src/companion_usage_line.dart';
import 'package:clide/builtin/clide_companion/src/prompt/companion_reply.dart';
import 'package:clide/widgets/src/clide_settings.dart';
import 'package:clide/widgets/src/clide_text.dart';
import 'package:clide/widgets/src/spacing.dart';
import 'package:clide/widgets/src/typography.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// One line of the popout: something he said, or something we asked him.
class CompanionTurn {
  const CompanionTurn({required this.text, required this.mine});

  final String text;

  /// True when the developer said it. Drives which side it reads from.
  final bool mine;
}

/// The `[direct]` prefix a question carries on the wire (T-546). Stripped for
/// display — the tag is protocol, not something anyone typed.
const _directPrefix = '[direct] user:';

/// Turn his session's items into the exchange, newest last.
///
/// Exposed for testing, and because the filter is the interesting part of this
/// file: everything else is layout.
List<CompanionTurn> companionExchange(List<ConversationItem> items) {
  final out = <CompanionTurn>[];
  for (final item in items) {
    switch (item) {
      case UserMessage(:final text):
        // Only what we asked him. The digest lines are the developer's own
        // conversation and belong in the pane they came from.
        if (!text.trimLeft().startsWith(_directPrefix)) continue;
        final q = text.trimLeft().substring(_directPrefix.length).trim();
        if (q.isNotEmpty) out.add(CompanionTurn(text: q, mine: true));
      case AssistantTextMessage(:final text, :final synthetic):
        // Synthetic prose is the CLI talking locally, not him.
        if (synthetic) continue;
        // Through the same parser the bubble uses, so the face tag never shows
        // here either — and so silence stays silent rather than rendering as an
        // empty row.
        final reply = parseCompanionReply(text);
        if (reply.speaks) out.add(CompanionTurn(text: reply.say, mine: false));
      default:
        continue;
    }
  }
  return out;
}

/// The popout itself. Shown through the dialog router, over the detail area.
class CompanionPopout extends StatefulWidget {
  const CompanionPopout({super.key, required this.conversation, required this.onDismiss, required this.onAsk, this.draft, this.canAsk = true, this.ledger});

  /// His session's conversation. Listened to, so a reply arriving while the
  /// popout is open lands in it.
  final ConversationController? conversation;

  final VoidCallback onDismiss;
  final ValueChanged<String> onAsk;

  /// Owned by the caller so a half-typed question survives dismissal. Losing
  /// what someone was in the middle of writing is the kind of small betrayal
  /// that makes a surface untrustworthy.
  final TextEditingController? draft;

  final bool canAsk;

  /// What he has spent this run (T-556). Null where there is nothing to report
  /// — a test harness, or a popout opened before the extension is up.
  final CompanionLedger? ledger;

  @override
  State<CompanionPopout> createState() => _CompanionPopoutState();
}

class _CompanionPopoutState extends State<CompanionPopout> {
  final _focus = FocusNode(debugLabel: 'CompanionPopout');

  @override
  void initState() {
    super.initState();
    widget.conversation?.addListener(_onConversation);
    // Focus so Esc reaches us without the user having to click first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _onConversation() => setState(() {});

  @override
  void didUpdateWidget(CompanionPopout old) {
    super.didUpdateWidget(old);
    // His session can be replaced under an open popout — a restart follows a
    // `/clear` on the primary, a workspace switch, or any brief change (a
    // rename, a locale, an edited self-description). Without moving the
    // listener the window keeps reading a conversation nobody writes to any
    // more: the answer to a question typed right here would never appear.
    if (old.conversation == widget.conversation) return;
    old.conversation?.removeListener(_onConversation);
    widget.conversation?.addListener(_onConversation);
  }

  @override
  void dispose() {
    widget.conversation?.removeListener(_onConversation);
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) return KeyEventResult.ignored;
    widget.onDismiss();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final turns = companionExchange(widget.conversation?.items ?? const []);

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: GestureDetector(
        // A tap on the scrim dismisses; the panel below stops the gesture, so a
        // tap inside never does.
        behavior: HitTestBehavior.opaque,
        onTap: widget.onDismiss,
        child: ColoredBox(
          color: const Color(0x99000000),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.panelBackground,
                    border: Border.all(color: tokens.syntaxString),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(clideInsetStandard),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(child: turns.isEmpty ? _Empty() : _Exchange(turns: turns)),
                        // Between his words and the box you ask more of him:
                        // the last thing read before spending again.
                        if (widget.ledger != null) ...[
                          const SizedBox(height: clideInsetStandard),
                          ListenableBuilder(
                            listenable: widget.ledger!,
                            builder: (_, _) => CompanionUsageLine(total: widget.ledger!.total, turns: widget.ledger!.turns),
                          ),
                        ],
                        const SizedBox(height: clideInsetStandard),
                        ClideAskBox(
                          onAsk: widget.onAsk,
                          enabled: widget.canAsk,
                          controller: widget.draft,
                          hint: ClideSettings.i18n.string(context, 'strip.ask.hint', namespace: 'builtin.clide-companion', placeholder: 'ask Clide…'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nothing said yet. Stated plainly rather than left blank — an empty panel
/// reads as broken, and "he has not said anything" is a true and unalarming
/// thing to read.
class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return Center(
      child: ClideText(
        ClideSettings.i18n.string(context, 'popout.empty', namespace: 'builtin.clide-companion', placeholder: 'Nothing said yet.'),
        color: tokens.globalTextMuted,
        fontSize: clideFontCaption,
      ),
    );
  }
}

/// The exchange, **latest first**.
///
/// Reversed on purpose (T-514): the useful thing is the last thing he said, not
/// the first. `reverse: true` also means the list opens at the newest without
/// having to scroll to an offset, and it is what makes lazy loading cheap —
/// older turns build only as they are scrolled to.
class _Exchange extends StatelessWidget {
  const _Exchange({required this.turns});

  final List<CompanionTurn> turns;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      itemCount: turns.length,
      itemBuilder: (context, i) => _Turn(turn: turns[turns.length - 1 - i]),
    );
  }
}

class _Turn extends StatelessWidget {
  const _Turn({required this.turn});

  final CompanionTurn turn;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: turn.mine ? Alignment.centerRight : Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.listItemBackground,
            // His words carry his green edge; the developer's carry none, so who
            // said what is readable without a label.
            border: turn.mine ? null : Border.all(color: tokens.syntaxString),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: clideInsetText, vertical: clideInsetStandard),
            child: ClideText(turn.text, color: turn.mine ? tokens.globalTextMuted : tokens.globalForeground, fontSize: clideFontCaption),
          ),
        ),
      ),
    );
  }
}
