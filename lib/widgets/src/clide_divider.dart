import 'package:clide/kernel/src/theme/controller.dart';
import 'package:flutter/widgets.dart';

class ClideDivider extends StatelessWidget {
  const ClideDivider({
    super.key,
    this.axis = Axis.horizontal,
    this.thickness = 1,
  });

  final Axis axis;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    final color = ClideTheme.of(context).surface.dividerColor;
    return Container(
      width: axis == Axis.vertical ? thickness : null,
      height: axis == Axis.horizontal ? thickness : null,
      color: color,
    );
  }
}
