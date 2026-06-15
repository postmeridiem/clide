/// Horizontal marquee (T-150). Shows `child` statically when it fits the
/// available width; when it's wider, scrolls it leftward in a seamless
/// loop (a second copy follows after `gap`). Clips to its box. Used by
/// the status-bar slot so a long pane status doesn't get truncated.
///
/// Own-the-stack: a `Ticker`-driven `SingleChildScrollView`, no package.
library;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class ClideMarquee extends StatefulWidget {
  const ClideMarquee({super.key, required this.child, this.pxPerSecond = 28, this.gap = 48});

  final Widget child;

  /// Scroll speed when overflowing.
  final double pxPerSecond;

  /// Space between the looped copies.
  final double gap;

  @override
  State<ClideMarquee> createState() => _ClideMarqueeState();
}

class _ClideMarqueeState extends State<ClideMarquee> with SingleTickerProviderStateMixin {
  final GlobalKey _childKey = GlobalKey();
  final ScrollController _scroll = ScrollController();
  late final Ticker _ticker = createTicker(_tick);

  double _contentWidth = 0;
  double _viewportWidth = 0;
  double _offset = 0;
  Duration _last = Duration.zero;

  /// Honour reduced motion (T-284): the same `MediaQuery.disableAnimations`
  /// flag the running indicator gates on (T-273). When set, the marquee never
  /// scrolls — it shows the child statically (clipped) — so reduced-motion
  /// users get no motion and `pumpAndSettle` isn't wedged by a perpetual ticker.
  bool _reduced = false;

  bool get _overflow => _contentWidth > _viewportWidth + 0.5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduced != _reduced) {
      setState(() => _reduced = reduced);
      _syncTicker();
    }
  }

  @override
  void didUpdateWidget(ClideMarquee old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final w = _childKey.currentContext?.size?.width ?? 0;
    if ((w - _contentWidth).abs() > 0.5) {
      setState(() => _contentWidth = w);
    }
    _syncTicker();
  }

  /// Start the scroll ticker only when the content overflows AND motion is
  /// allowed; otherwise stop it and reset to the start.
  void _syncTicker() {
    final shouldRun = _overflow && !_reduced;
    if (shouldRun && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
      _offset = 0;
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  void _tick(Duration elapsed) {
    if (!_overflow || _reduced || !_scroll.hasClients) return;
    final dt = _last == Duration.zero ? 0.0 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final span = _contentWidth + widget.gap;
    if (span <= 0) return;
    _offset = (_offset + widget.pxPerSecond * dt) % span;
    final max = _scroll.position.maxScrollExtent;
    _scroll.jumpTo(_offset.clamp(0, max));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          _viewportWidth = constraints.maxWidth;
          return SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                KeyedSubtree(key: _childKey, child: widget.child),
                if (_overflow && !_reduced) ...[SizedBox(width: widget.gap), widget.child],
              ],
            ),
          );
        },
      ),
    );
  }
}
