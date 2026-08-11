/// The Clide strip (T-526, D-107) — the companion's surface at the bottom of
/// the context column.
///
/// Placement was settled by the T-514 wireframe spike: a horizontal strip
/// sharing the context column rather than a rail of its own. This owns the
/// strip's **internal composition** so Epic E fills regions rather than
/// renegotiating layout — face across the back, speech bubble beside it, input
/// row beneath.
///
/// The face is drawn full-bleed behind the content rather than boxed into a
/// left-hand region. Rain density is the load signal and is read as how many
/// columns are lit, so it needs the whole width; `faceAlignX: -1` keeps the
/// glyphs at the left where the wireframe puts them while the field still spans
/// the strip.
library;

import 'package:clide/builtin/clide_companion/src/ask_box.dart';
import 'package:clide/builtin/clide_companion/src/clide_face.dart';
import 'package:clide/builtin/clide_companion/src/face_state.dart';
import 'package:clide/builtin/clide_companion/src/session_load.dart';
import 'package:clide/widgets/src/clide_settings.dart';
import 'package:clide/widgets/src/clide_text.dart';
import 'package:clide/widgets/src/spacing.dart';
import 'package:clide/widgets/src/typography.dart';
import 'package:flutter/widgets.dart';

/// Resting height of the strip.
///
/// T-528 makes this persisted and adds grow-to-cap while Clide is answering;
/// until then it is fixed. Deliberately shallow — this is height taken from
/// every detail view in the column, on every ticket, decision, file and graph.
const kClideStripHeight = 112.0;

/// Width reserved for the face before the bubble starts. The face paints behind
/// the whole strip; this only keeps the bubble from overlapping the glyphs.
const _faceGutter = 116.0;

/// Below this the strip drops the bubble and shows the face alone — at the
/// context panel's 220px minimum there is not enough width for both to be
/// legible, and a cramped bubble reads worse than none.
const _bubbleMinWidth = 150.0;

class ClideStrip extends StatefulWidget {
  const ClideStrip({
    super.key,
    this.state = FaceState.idle,
    this.load = SessionLoad.calm,
    this.gaze = Gaze.none,
    this.busyFor,
    this.message,
    this.onAsk,
    this.onExpand,
    this.canAsk = true,
    this.askHint,
    this.debugFreezeAt,
    this.debugClockLabel,
  });

  /// Called with a question typed into his box (T-564). Null hides the input
  /// entirely — the strip is then the display-only surface it was before.
  final ValueChanged<String>? onAsk;

  /// Whether there is a session to ask. False dims the box rather than removing
  /// it: a control that vanishes reads as a bug.
  final bool canAsk;

  /// Open his conversation over the detail area (T-566). Null hides the
  /// affordance — the strip is then bubble-and-input only.
  final VoidCallback? onExpand;

  /// Placeholder for the input, resolved through the catalog by the host
  /// (D-21/D-102). Null takes [ClideAskBox]'s own English fallback.
  final String? askHint;

  /// Face state — Clide's own. Epic D drives this; until then it rests at
  /// [FaceState.idle].
  final FaceState state;

  /// The primary session's load, which is what the rain reports (D-107
  /// commitment 5). T-539 drives this from `busyStream`.
  final SessionLoad load;

  final Gaze gaze;
  final Duration? busyFor;

  /// What Clide is currently saying, if anything. Epic D produces it; Epic E
  /// owns the richer surface. Null shows no bubble.
  final String? message;

  @visibleForTesting
  final Duration? debugFreezeAt;

  @visibleForTesting
  final String? debugClockLabel;

  @override
  State<ClideStrip> createState() => _ClideStripState();
}

class _ClideStripState extends State<ClideStrip> {
  /// True while his box has focus. Drives [Gaze.forward] — the `ADDRESSED`
  /// widget.state from the T-514 spike, where the lean releasing *is* the
  /// acknowledgement that you are talking to him rather than about him.
  bool _addressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;

    return SizedBox(
      height: kClideStripHeight,
      child: DecoratedBox(
        // Anchors the strip to the body above it; without a hairline the strip
        // reads as floating and the perceived alignment slips.
        decoration: BoxDecoration(
          color: tokens.panelBackground,
          border: Border(top: BorderSide(color: tokens.dividerColor)),
        ),
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final width = constraints.maxWidth;
            final showBubble = width - _faceGutter >= _bubbleMinWidth;

            return Stack(
              children: [
                // Full-bleed: the rain gets the whole strip even though the
                // glyphs sit left.
                Positioned.fill(
                  child: ClideFace(
                    state: widget.state,
                    load: widget.load,
                    gaze: _addressed ? Gaze.forward : widget.gaze,
                    busyFor: widget.busyFor,
                    faceAlignX: -1,
                    debugFreezeAt: widget.debugFreezeAt,
                    debugClockLabel: widget.debugClockLabel,
                  ),
                ),
                if (showBubble)
                  Positioned(
                    left: _faceGutter,
                    right: clideInsetText,
                    top: clideInsetStandard,
                    bottom: clideInsetStandard,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // The bubble takes what it needs and the input keeps its
                        // row: a remark that grew without bound would push his
                        // box off the strip, which is the one control here.
                        Expanded(child: _Bubble(message: widget.message)),
                        if (widget.onAsk != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: ClideAskBox(
                                  onAsk: widget.onAsk!,
                                  enabled: widget.canAsk,
                                  hint: widget.askHint ?? 'ask Clide…',
                                  onFocusChanged: (has) => setState(() => _addressed = has),
                                ),
                              ),
                              if (widget.onExpand != null) ...[const SizedBox(width: 4), _ExpandButton(onTap: widget.onExpand!)],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Opens his conversation. Deliberately small and beside the input rather than
/// in the bubble — the bubble is display-only (D-78), and a control inside a
/// display surface is the composition mistake that rule exists to prevent.
class _ExpandButton extends StatelessWidget {
  const _ExpandButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return Semantics(
      button: true,
      label: 'Open Clide\'s conversation',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          height: kAskBoxHeight,
          width: kAskBoxHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.listItemBackground,
              border: Border.all(color: tokens.globalBorder),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: ClideText('⌃', color: tokens.globalTextMuted, fontSize: clideFontCaption),
            ),
          ),
        ),
      ),
    );
  }
}

/// Clide's speech bubble. Display-only — the input affordance is Epic E's, and
/// interactive controls belong in their own region rather than inline in a
/// display surface (the D-78 principle, applied here as composition).
class _Bubble extends StatelessWidget {
  const _Bubble({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    final tokens = ClideSettings.theme.of(context).surface;

    return Align(
      alignment: Alignment.topLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.listItemBackground,
          // The same green as the rain, so the bubble reads as Clide's rather
          // than as one more framed panel — a divider-grey edge made it look
          // like chrome that happened to contain text.
          border: Border.all(color: tokens.syntaxString),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: clideInsetText, vertical: clideInsetStandard),
          child: ClideText(message!, color: tokens.globalForeground, fontSize: clideFontCaption, maxLines: 3, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
