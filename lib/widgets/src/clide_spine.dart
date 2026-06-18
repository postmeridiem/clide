import 'package:clide/widgets/src/clide_settings.dart';
import 'dart:math' as math;

import 'package:clide/widgets/src/clide_tappable.dart';
import 'package:flutter/widgets.dart';

class ClideSpine extends StatelessWidget {
  const ClideSpine({super.key, required this.label, required this.onExpand, this.side = SpineSide.left, this.badgeCount = 0});

  final String label;
  final VoidCallback onExpand;
  final SpineSide side;
  final int badgeCount;

  static const double width = 12;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final borderSide = BorderSide(color: tokens.dividerColor);

    final expandSuffix = ClideSettings.i18n.string(context, 'spine.expandSuffix', namespace: 'core', placeholder: 'click to expand');
    return Semantics(
      button: true,
      label: '$label — $expandSuffix',
      child: ClideTappable(
        onTap: onExpand,
        builder: (context, hovered, _) => Container(
          width: ClideSpine.width,
          decoration: BoxDecoration(
            color: hovered ? tokens.sidebarItemHover : tokens.chromeBackground,
            border: Border(left: side == SpineSide.right ? borderSide : BorderSide.none, right: side == SpineSide.left ? borderSide : BorderSide.none),
          ),
          child: Stack(
            children: [
              Center(
                child: Transform.rotate(
                  angle: side == SpineSide.left ? -math.pi / 2 : math.pi / 2,
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 9, color: tokens.globalTextMuted, letterSpacing: 0.5),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: 4,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: tokens.statusInfo, shape: BoxShape.circle),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum SpineSide { left, right }
