import 'dart:math' as math;

import 'package:clide/kernel/src/theme/controller.dart';
import 'package:flutter/widgets.dart';

class ClideSpine extends StatefulWidget {
  const ClideSpine({
    super.key,
    required this.label,
    required this.onExpand,
    this.side = SpineSide.left,
    this.badgeCount = 0,
  });

  final String label;
  final VoidCallback onExpand;
  final SpineSide side;
  final int badgeCount;

  static const double width = 12;

  @override
  State<ClideSpine> createState() => _ClideSpineState();
}

enum SpineSide { left, right }

class _ClideSpineState extends State<ClideSpine> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final borderSide = BorderSide(color: tokens.dividerColor);

    return Semantics(
      button: true,
      label: '${widget.label} — click to expand',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onExpand,
          child: Container(
            width: ClideSpine.width,
            decoration: BoxDecoration(
              color: _hovered ? tokens.sidebarItemHover : tokens.sidebarBackground,
              border: Border(
                left: widget.side == SpineSide.right ? borderSide : BorderSide.none,
                right: widget.side == SpineSide.left ? borderSide : BorderSide.none,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Transform.rotate(
                    angle: widget.side == SpineSide.left ? -math.pi / 2 : math.pi / 2,
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 9,
                        color: tokens.globalTextMuted,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                ),
                if (widget.badgeCount > 0)
                  Positioned(
                    top: 4,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: tokens.statusInfo,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
