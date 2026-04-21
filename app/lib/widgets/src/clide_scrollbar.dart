import 'package:clide_app/kernel/src/theme/controller.dart';
import 'package:flutter/widgets.dart';

/// Thin themed scrollbar. Tier-0 shell; more refined scrolling (velocity
/// multiplier, keyboard nav) lands with the editor.
class ClideScrollbar extends StatelessWidget {
  const ClideScrollbar({
    super.key,
    required this.controller,
    required this.child,
    this.axis = Axis.vertical,
  });

  final ScrollController controller;
  final Widget child;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return ScrollbarTheme(
      slider: tokens.scrollbarSlider,
      sliderHover: tokens.scrollbarSliderHover,
      track: tokens.scrollbarTrack,
      child: RawScrollbar(
        controller: controller,
        thumbColor: tokens.scrollbarSlider,
        thickness: 8,
        radius: const Radius.circular(4),
        child: child,
      ),
    );
  }
}

class ScrollbarTheme extends InheritedWidget {
  const ScrollbarTheme({
    super.key,
    required this.slider,
    required this.sliderHover,
    required this.track,
    required super.child,
  });

  final Color slider;
  final Color sliderHover;
  final Color track;

  @override
  bool updateShouldNotify(ScrollbarTheme old) =>
      slider != old.slider ||
      sliderHover != old.sliderHover ||
      track != old.track;
}
