/// The box you ask Clide things in (T-564, D-107).
///
/// The affordance that turns him from an ambience into something you can use.
/// Everything behind it already exists: the `[direct]` tag and its formatter
/// (T-546), the brief that makes a direct line the one case where silence is
/// wrong (T-532), and a live session to send it to (T-545).
///
/// ## Why not [ClideFilterBox]
///
/// It is the only other single-line input in the tree and it is a *filter*: it
/// debounces, it carries a clear button, and it speaks the `filter.set` /
/// `filter.state` bus grammar T-270 defined for CLI-addressable filter boxes.
/// Reusing it here would publish questions on the filter channel and collide
/// with that addressing. The visual grammar is deliberately the same, so the two
/// look like siblings; if a third single-line input ever appears, the chrome is
/// what should be extracted, not this.
///
/// ## Telling the two composers apart
///
/// There are now two places to type on one screen, reaching two different
/// models — one of which can act on the repository and one of which cannot. A
/// user who types a task in here and waits is having a bad time.
///
/// The wireframe's answer is better than a label: **the face reacts.** Focusing
/// this releases Clide's lean and brings his pupils forward — the `ADDRESSED`
/// state from the T-514 spike, whose note reads *"the lean releasing IS the
/// acknowledgement — no chrome needed"*. Position does the rest: his box is in
/// the context column, attached to his face, in his green.
library;

import 'package:clide/widgets/src/clide_settings.dart';
import 'package:clide/widgets/src/clide_text.dart';
import 'package:clide/widgets/src/typography.dart';
import 'package:flutter/widgets.dart';

/// Height of the input row. Shallow on purpose — it is permanent chrome in a
/// strip that already costs every detail view its height (D-48).
const kAskBoxHeight = 26.0;

class ClideAskBox extends StatefulWidget {
  const ClideAskBox({super.key, required this.onAsk, this.onFocusChanged, this.hint = 'ask Clide…', this.enabled = true, this.controller, this.focusNode});

  /// Supplied when something outside needs to put the cursor here — the
  /// `companion.focus` verb and its keybinding (T-567). A node rather than a
  /// tick threaded down through two widgets: focusing is what a `FocusNode` is
  /// for, and the caller already has to own one to call it.
  final FocusNode? focusNode;

  /// Supplied when the caller needs the text to outlive this widget — the
  /// popout's draft survives being dismissed and reopened (T-566), because
  /// losing a half-typed question is the kind of small betrayal that makes a
  /// surface untrustworthy. Null means the box owns its own.
  final TextEditingController? controller;

  /// Called with the question when the user submits a non-empty one.
  final ValueChanged<String> onAsk;

  /// Focus gained or lost, so the face can acknowledge being addressed.
  final ValueChanged<bool>? onFocusChanged;

  /// Placeholder. A catalog string at the call site (D-21/D-102) — this default
  /// is the developer fallback, and it must tolerate ~30% growth in Dutch.
  final String hint;

  /// False while there is no session to ask. The box stays visible rather than
  /// vanishing: a control that disappears reads as a bug, where a dimmed one
  /// reads as "not now".
  final bool enabled;

  @override
  State<ClideAskBox> createState() => _ClideAskBoxState();
}

class _ClideAskBoxState extends State<ClideAskBox> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  /// Only dispose what we made. Caller-supplied ones outlive us by design.
  late final bool _ownsController;
  late final bool _ownsFocus;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
    _ownsFocus = widget.focusNode == null;
    _focus = widget.focusNode ?? FocusNode();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    widget.onFocusChanged?.call(_focus.hasFocus);
    setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    if (_ownsFocus) _focus.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  /// Submit, and clear. Clearing is deliberate: the answer arrives in the bubble
  /// above, so a question left sitting in the box would read as unsent.
  void _submit(String raw) {
    final text = raw.trim();
    if (text.isEmpty || !widget.enabled) return;
    _controller.clear();
    widget.onAsk(text);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    // His green when he is listening, ordinary border otherwise — the same
    // colour the bubble uses, so the pair reads as one surface that is his.
    final border = _focus.hasFocus ? tokens.syntaxString : tokens.globalBorder;
    final muted = tokens.globalTextMuted;

    return Semantics(
      textField: true,
      enabled: widget.enabled,
      label: widget.hint,
      child: SizedBox(
        height: kAskBoxHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            // Opaque, not just bordered. The face paints full-bleed behind the
            // whole strip, so an unfilled box has rain running through the text
            // — the glyphs move, and moving glyphs behind a caret is unreadable.
            // The same fill the bubble uses, so the pair reads as one surface
            // that is his rather than two frames laid on the weather.
            color: tokens.listItemBackground,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                if (_controller.text.isEmpty) ClideText(widget.hint, color: muted, fontSize: clideFontCaption),
                EditableText(
                  controller: _controller,
                  focusNode: _focus,
                  readOnly: !widget.enabled,
                  style: TextStyle(
                    color: widget.enabled ? tokens.globalForeground : muted,
                    fontSize: clideFontCaption,
                    fontFamily: ClideSettings.fonts.uiOf(context),
                  ),
                  cursorColor: tokens.syntaxString,
                  backgroundCursorColor: muted,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: _submit,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
