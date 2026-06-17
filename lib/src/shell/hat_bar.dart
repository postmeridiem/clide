/// The top window-chrome bar (D-57): drag region, menu bar, project
/// switcher, window controls. Split out of app.dart (T-394).
library;

import 'dart:io' show Platform;

import 'package:clide/builtin/menubar/menubar.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/shell/project_switcher.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

class HatBar extends StatelessWidget {
  const HatBar({super.key, required this.kernel, required this.menuBar});
  final KernelServices kernel;
  final MenuBarController menuBar;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return GestureDetector(
      onPanStart: (_) => kernel.window.startDrag(),
      child: Container(
        height: hatHeight,
        decoration: BoxDecoration(
          color: tokens.chromeBackground,
          border: Border(bottom: BorderSide(color: tokens.chromeBorder, width: 1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _LeftHatContent(tokens: tokens, wc: kernel.window),
            MenuBar(controller: menuBar),
            Expanded(
              child: Center(
                child: ProjectSwitcherButton(kernel: kernel, tokens: tokens),
              ),
            ),
            _RightHatContent(tokens: tokens, wc: kernel.window),
          ],
        ),
      ),
    );
  }
}

class _LeftHatContent extends StatelessWidget {
  const _LeftHatContent({required this.tokens, required this.wc});
  final SurfaceTokens tokens;
  final WindowControls wc;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    // On macOS the native titlebar draws traffic lights; skip duplicates.
    return const SizedBox.shrink();
  }
}

class _RightHatContent extends StatelessWidget {
  const _RightHatContent({required this.tokens, required this.wc});
  final SurfaceTokens tokens;
  final WindowControls wc;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    if (!kIsWeb && Platform.isMacOS) return const SizedBox.shrink();
    return Row(
      children: [
        _WinBtn(icon: const PhosphorIconPainter(0xe32a), onTap: wc.minimize, tokens: tokens),
        _WinBtn(icon: const PhosphorIconPainter(0xe45e), onTap: wc.toggleMaximize, tokens: tokens),
        _WinBtn(icon: PhosphorIcons.byName('x'), onTap: wc.close, tokens: tokens, isClose: true),
      ],
    );
  }
}

class _WinBtn extends StatelessWidget {
  const _WinBtn({required this.icon, required this.onTap, required this.tokens, this.isClose = false});
  final ClideIconPainter icon;
  final VoidCallback onTap;
  final SurfaceTokens tokens;
  final bool isClose;

  @override
  Widget build(BuildContext context) {
    final hoverBg = isClose ? tokens.windowControlCloseHoverBackground : tokens.listItemHoverBackground;
    return ClideTappable(
      onTap: onTap,
      builder: (context, hovered, _) => Container(
        width: 36,
        height: hatHeight,
        color: hovered ? hoverBg : null,
        alignment: Alignment.center,
        child: ClideIcon(icon, size: 14, color: hovered && isClose ? tokens.windowControlCloseHoverForeground : tokens.chromeForeground),
      ),
    );
  }
}
