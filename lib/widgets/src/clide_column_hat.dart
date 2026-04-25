import 'dart:io' show Platform;

import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/kernel/src/window_controls.dart';
import 'package:clide/widgets/src/clide_icon.dart';
import 'package:clide/widgets/src/clide_tappable.dart';
import 'package:clide/widgets/src/clide_text.dart';
import 'package:clide/widgets/src/icons/phosphor.dart';
import 'package:clide/widgets/src/typography.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

const double hatHeight = 24;

class ColumnHat extends StatelessWidget {
  const ColumnHat._({required this.position, required this.windowControls, this.projectLabel, this.branchLabel});

  final HatPosition position;
  final WindowControls windowControls;
  final String? projectLabel;
  final String? branchLabel;

  factory ColumnHat.left({required WindowControls windowControls}) =>
      ColumnHat._(position: HatPosition.left, windowControls: windowControls);

  factory ColumnHat.center({required WindowControls windowControls, String? project, String? branch}) =>
      ColumnHat._(position: HatPosition.center, windowControls: windowControls, projectLabel: project, branchLabel: branch);

  factory ColumnHat.right({required WindowControls windowControls}) =>
      ColumnHat._(position: HatPosition.right, windowControls: windowControls);

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return GestureDetector(
      onPanStart: (_) => windowControls.startDrag(),
      child: Container(
        height: hatHeight,
        color: tokens.panelHeader,
        child: switch (position) {
          HatPosition.left => _LeftContent(tokens: tokens, wc: windowControls),
          HatPosition.center => _CenterContent(tokens: tokens, project: projectLabel, branch: branchLabel),
          HatPosition.right => _RightContent(tokens: tokens, wc: windowControls),
        },
      ),
    );
  }
}

enum HatPosition { left, center, right }

class _LeftContent extends StatelessWidget {
  const _LeftContent({required this.tokens, required this.wc});
  final SurfaceTokens tokens;
  final WindowControls wc;

  @override
  Widget build(BuildContext context) {
    // On macOS the native titlebar draws traffic lights; skip duplicates.
    return const SizedBox.expand();
  }
}

class _CenterContent extends StatelessWidget {
  const _CenterContent({required this.tokens, this.project, this.branch});
  final SurfaceTokens tokens;
  final String? project;
  final String? branch;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (project != null) parts.add(project!);
    if (branch != null) parts.add(branch!);
    final label = parts.isEmpty ? 'clide' : parts.join(' > ');
    return Center(
      child: ClideText(label, fontSize: 12, color: tokens.globalTextMuted, fontFamily: clideMonoFamily),
    );
  }
}

class _RightContent extends StatelessWidget {
  const _RightContent({required this.tokens, required this.wc});
  final SurfaceTokens tokens;
  final WindowControls wc;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.expand();
    final isMac = !kIsWeb && Platform.isMacOS;
    if (isMac) return const SizedBox.expand();
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _WinButton(icon: const PhosphorIconPainter(0xe32a), onTap: wc.minimize, tokens: tokens),
        _WinButton(icon: const PhosphorIconPainter(0xe45e), onTap: wc.toggleMaximize, tokens: tokens),
        _WinButton(icon: PhosphorIcons.xMark, onTap: wc.close, tokens: tokens, isClose: true),
      ],
    );
  }
}

class _TrafficDot extends StatelessWidget {
  const _TrafficDot({required this.color, required this.onTap});
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClideTappable(
      onTap: onTap,
      builder: (context, hovered, _) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: hovered ? color : color.withAlpha(0xCC),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _WinButton extends StatelessWidget {
  const _WinButton({required this.icon, required this.onTap, required this.tokens, this.isClose = false});
  final ClideIconPainter icon;
  final VoidCallback onTap;
  final SurfaceTokens tokens;
  final bool isClose;

  @override
  Widget build(BuildContext context) {
    final hoverBg = isClose ? const Color(0xFFE81123) : tokens.listItemHoverBackground;
    return ClideTappable(
      onTap: onTap,
      builder: (context, hovered, _) => Container(
        width: 36,
        height: hatHeight,
        color: hovered ? hoverBg : null,
        alignment: Alignment.center,
        child: ClideIcon(icon, size: 14, color: hovered && isClose ? const Color(0xFFFFFFFF) : tokens.globalTextMuted),
      ),
    );
  }
}
