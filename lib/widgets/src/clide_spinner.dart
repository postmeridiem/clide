/// A compact in-progress spinner: the clide logo mark, monochrome, rotating in
/// 3D about its vertical axis (T-296).
///
/// Reuses `assets/logo/logo.svg` as the single source of truth for the mark
/// (tinted to one colour via a srcIn [ColorFilter]) rather than re-coding the
/// geometry, and spins it with a perspective Y-rotation. Honours
/// reduced-motion: when animations are disabled it shows the static, front-on
/// mark. Animation is one [AnimationController] (no timers) so tests advance it
/// with bounded pumps.
library;

import 'package:clide/widgets/src/clide_settings.dart';
import 'dart:math' as math;

import 'package:clide/widgets/src/clide_svg_view.dart';
import 'package:flutter/widgets.dart';

class ClideSpinner extends StatefulWidget {
  const ClideSpinner({super.key, this.size = 14, this.color, this.period = const Duration(milliseconds: 1500), this.semanticLabel});

  final double size;

  /// Mark colour; defaults to the theme's foreground (monochrome on the chrome).
  final Color? color;

  /// Time for one full rotation.
  final Duration period;

  /// Optional AT label (e.g. 'running'); omit when a parent announces status.
  final String? semanticLabel;

  @override
  State<ClideSpinner> createState() => _ClideSpinnerState();
}

class _ClideSpinnerState extends State<ClideSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: widget.period);
  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _sync();
  }

  void _sync() {
    if (_reducedMotion) {
      _ctrl.stop();
      _ctrl.value = 0;
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? ClideSettings.theme.of(context).surface.globalForeground;
    // Tint every stroke of the multi-colour logo to one colour, keeping alpha.
    final mark = ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: ClideSvgView.asset('assets/logo/logo.svg', width: widget.size, height: widget.size),
    );
    final child = _reducedMotion
        ? mark
        : AnimatedBuilder(
            animation: _ctrl,
            child: mark,
            builder: (_, child) => Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015) // perspective
                ..rotateY(_ctrl.value * 2 * math.pi),
              child: child,
            ),
          );
    return Semantics(
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel == null,
      child: SizedBox(width: widget.size, height: widget.size, child: child),
    );
  }
}
