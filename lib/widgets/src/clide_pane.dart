/// Behaviour-only wrapper every pane uses (T-150). No chrome — that's
/// [ClidePaneChrome]'s job. ClidePane handles cross-pane uniformity:
/// surfacing the pane's `statusWidget` to the bottom status bar while the
/// pane is focused, via [FocusTracker.setStatusWidget].
///
/// The widget lives with the pane; ClidePane only conveys it to the
/// shared slot while this pane is the shown one (its contribution is
/// focused and, for multi-pane contributions, it's the `active` sub-tab),
/// and re-conveys whenever `statusWidget` changes. A backgrounded pane
/// keeps its content locally and re-conveys on regaining focus.
library;

import 'package:clide/kernel/src/facade.dart';
import 'package:clide/kernel/src/focus.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class ClidePane extends StatefulWidget {
  const ClidePane({super.key, required this.contributionId, required this.child, this.statusWidget, this.active = true});

  /// The workspace contribution id this pane belongs to (what
  /// [FocusTracker.activeContributionId] reports when it's focused).
  final String contributionId;

  /// Status-bar content to surface while focused, or null for none.
  final Widget? statusWidget;

  /// For contributions hosting multiple panes (e.g. Claude's sub-tabs),
  /// whether this is the visible one. Only the active pane conveys.
  final bool active;

  final Widget child;

  @override
  State<ClidePane> createState() => _ClidePaneState();
}

class _ClidePaneState extends State<ClidePane> {
  FocusTracker? _focus;
  bool _wired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_wired) {
      _wired = true;
      _focus = ClideKernel.of(context).focus..addListener(_sync);
    }
    _sync();
  }

  @override
  void didUpdateWidget(ClidePane old) {
    super.didUpdateWidget(old);
    if (old.statusWidget != widget.statusWidget || old.active != widget.active || old.contributionId != widget.contributionId) {
      _sync();
    }
  }

  bool get _shown => widget.active && _focus?.activeContributionId == widget.contributionId;

  // Convey our status while shown. Re-entrancy is bounded: setStatusWidget
  // notifies (→ _sync again), but the identical-widget guard there makes
  // the second pass a no-op.
  void _sync() {
    if (_shown) _convey(widget.statusWidget);
  }

  // Push [w] to the focus tracker's status slot. setStatusWidget notifies
  // focus listeners (the status-bar item rebuilds) — but didChangeDependencies
  // and didUpdateWidget run during the build phase, where a synchronous notify
  // would markNeedsBuild-during-build. So defer the convey to after the frame
  // when we're mid-build, and re-check focus then (it may have moved).
  void _convey(Widget? w) {
    final focus = _focus;
    if (focus == null) return;
    void apply() {
      if (focus.activeContributionId == widget.contributionId) {
        focus.setStatusWidget(widget.contributionId, w);
      }
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  @override
  void dispose() {
    if (_shown) _convey(null);
    _focus?.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
