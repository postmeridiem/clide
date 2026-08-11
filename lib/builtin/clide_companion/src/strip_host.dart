/// Mounts the Clide strip, or does not, and feeds it the weather (T-527, T-539).
///
/// Exists so `slot_host.dart` stays ignorant of the companion beyond "put this
/// here": the shell should not know what a kill switch is, and the companion
/// should not need the shell edited every time its visibility rules change.
///
/// Disabled means **gone**, not hidden — the 112px goes back to the detail view
/// (D-107 commitment 1, and the shape the user asked for: "off is off for the
/// repo"). Minimising is a different control with a different key (T-528), and
/// removes the strip just as completely; what differs is that the rail button
/// survives it, so there is something left to click.
library;

import 'dart:async';

import 'package:clide/builtin/clide_companion/src/clide_strip.dart';
import 'package:clide/builtin/clide_companion/src/companion_state.dart';
import 'package:clide/builtin/clide_companion/src/companion_lifecycle.dart';
import 'package:clide/builtin/clide_companion/src/companion_popout.dart';
import 'package:clide/widgets/src/clide_settings.dart';
import 'package:clide/builtin/clide_companion/src/companion_voice.dart';
import 'package:clide/builtin/clide_companion/src/extension.dart';
import 'package:clide/kernel/src/facade.dart' show ClideKernel;
import 'package:flutter/widgets.dart';

class ClideStripHost extends StatelessWidget {
  const ClideStripHost({super.key});

  @override
  Widget build(BuildContext context) {
    return CompanionStateBuilder(builder: (context, state) => state.stripVisible ? _Suspendable(state: state) : const SizedBox.shrink());
  }
}

/// Stops the strip animating while the window is minimised (T-541).
///
/// `TickerMode` rather than unmounting or parking the ticker by hand, because
/// the requirement is **restore, not restart**: muting leaves the field exactly
/// as it was, so coming back continues instead of reseeding and looking like the
/// rain just started. Nobody can see a frozen frame while the window is
/// minimised, which is exactly why freezing is right here and draining is right
/// for dormancy (T-540) — there, the user may be watching when it happens.
///
/// Honours `app.companion.suspendWhenMinimised`, which has existed since T-527
/// and until now was read by nobody.
class _Suspendable extends StatelessWidget {
  const _Suspendable({required this.state});

  final CompanionState state;

  @override
  Widget build(BuildContext context) {
    final lifecycle = ClideKernel.maybeOf(context)?.lifecycle;
    if (lifecycle == null) return _Strip(state: state);

    return ListenableBuilder(
      listenable: lifecycle,
      builder: (context, child) => TickerMode(enabled: lifecycle.visible || !state.suspendWhenMinimised, child: child!),
      child: _Strip(state: state),
    );
  }
}

/// Turns a start instant into a running counter.
///
/// The widget below it deliberately does not time turns (the T-521 contract) —
/// it renders whatever `busyFor` it is handed, and a widget that inferred
/// elapsed time from when it happened to notice a prop change would drift by
/// however long noticing took. So the instant comes from the adapter, which
/// stamped it, and the *ticking* happens here.
///
/// One tick a second, only while a turn is running: the counter's granularity is
/// seconds, so anything faster is redraws nobody can read. While busy the face is
/// already animating at frame rate, so this adds nothing measurable; while idle
/// there is no timer at all, which is what keeps it out of the power ladder's way
/// (D-107 commitment 4).
class _Strip extends StatefulWidget {
  const _Strip({required this.state});

  final CompanionState state;

  @override
  State<_Strip> createState() => _StripState();
}

class _StripState extends State<_Strip> {
  Timer? _tick;

  /// Clide's own session: what he is saying and how he looks (T-548).
  ///
  /// Bound here rather than delivered over the bus. A remark spans nothing — it
  /// travels from his session to the widget beside it — and T-561 removed the
  /// last channel that carried something this local.
  late final CompanionVoice _voice;

  @override
  void initState() {
    super.initState();
    _voice = CompanionVoice(moodEnabled: () => widget.state.moodChannel)..start();
    _voice.addListener(_onVoice);
    _syncTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Captured, not re-resolved. `_extension` walks the element tree, and
      // dispose() runs after deactivation where that lookup is illegal — which
      // is exactly how this first broke six unrelated app tests.
      _subscribed = _extension;
      _subscribed?.openRequests.addListener(_onOpenRequested);
      _subscribed?.focusRequests.addListener(_onFocusRequested);
    });
  }

  void _onVoice() {
    if (!mounted) return;
    setState(() {});
    // Recorded where it is rendered, so `clide companion.say` and the bubble
    // cannot disagree about what he last said (T-567).
    _extension?.lastRemark = _voice.say;
  }

  /// Honour a request from the CLI or a keybinding (T-567).
  void _onOpenRequested() => _openPopout();
  void _onFocusRequested() => _askFocus.requestFocus();

  /// The strip input's focus, owned here so `companion.focus` can put the cursor
  /// in it without reaching into the widget.
  final _askFocus = FocusNode(debugLabel: 'ClideAsk');

  /// The extension we attached listeners to, held so they can be removed without
  /// another tree lookup.
  ClideCompanionExtension? _subscribed;

  @override
  void didUpdateWidget(_Strip old) {
    super.didUpdateWidget(old);
    if (old.state.busySince != widget.state.busySince) _syncTimer();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _subscribed?.openRequests.removeListener(_onOpenRequested);
    _subscribed?.focusRequests.removeListener(_onFocusRequested);
    _draft.dispose();
    _askFocus.dispose();
    _voice
      ..removeListener(_onVoice)
      ..dispose();
    super.dispose();
  }

  void _syncTimer() {
    _tick?.cancel();
    _tick = null;
    if (widget.state.busySince == null) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  /// Elapsed for the current turn, or null when idle.
  ///
  /// Null rather than a frozen last value: a counter that stops but stays on
  /// screen reads as a turn still running, which is the opposite of what it
  /// would be saying.
  Duration? get _busyFor {
    final since = widget.state.busySince;
    if (since == null) return null;
    final elapsed = DateTime.now().difference(since);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  @override
  Widget build(BuildContext context) => ClideStrip(
    load: widget.state.load,
    busyFor: _busyFor,
    state: _voice.face,
    message: _voice.say,
    canAsk: _companion?.running ?? false,
    askHint: ClideSettings.i18n.string(context, 'strip.ask.hint', namespace: 'builtin.clide-companion', placeholder: 'ask Clide…'),
    onAsk: _ask,
    onExpand: _openPopout,
    askFocusNode: _askFocus,
  );

  /// Draft for the popout's input, owned here rather than by the popout so a
  /// half-typed question survives being dismissed and reopened (T-566).
  final _draft = TextEditingController();

  /// Open his conversation over the detail area.
  ///
  /// The session is read **inside** the builder, under a listener on the
  /// controller, rather than captured when the window opens. A restart swaps the
  /// `ManagedSession` — and with it the conversation — and a popout holding the
  /// old one goes quietly stale: still showing the previous transcript, never
  /// showing the answer to whatever was typed into it next. The controller
  /// itself is stable for the extension's lifetime, so it is safe to listen to
  /// for as long as the window is up.
  void _openPopout() {
    final kernel = ClideKernel.maybeOf(context);
    if (kernel == null) return;
    final companion = _companion;
    kernel.dialog.show<Object>((ctx, dismiss) {
      CompanionPopout build() =>
          CompanionPopout(conversation: companion?.session?.conversation, draft: _draft, canAsk: companion?.running ?? false, onAsk: _ask, onDismiss: dismiss);
      if (companion == null) return build();
      return ListenableBuilder(listenable: companion, builder: (_, _) => build());
    });
  }

  /// Clide's session controller, via the extension that owns it.
  ///
  /// Reached through the registry rather than a new bus channel: the session is
  /// the extension's to own (T-545), and a hop would be the mistake T-561
  /// removed — a message that spans nothing, going out to the bus and coming
  /// straight back to one widget.
  ClideCompanionExtension? get _extension => ClideKernel.maybeOf(context)?.extensions.all.whereType<ClideCompanionExtension>().firstOrNull;

  CompanionSessionController? get _companion => _extension?.sessionController;

  void _ask(String question) => _companion?.ask(question);
}
