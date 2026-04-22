import 'package:clide_app/kernel/src/theme/controller.dart';
import 'package:flutter/widgets.dart';

import 'clide_divider.dart';
import 'clide_icon.dart';
import 'clide_text.dart';
import 'icons/x.dart';

/// Shared chrome for any pane that sits in a tab or split: a title
/// strip at the top, an optional close button, and the pane body
/// underneath. `ClidePtyView`, diff views, canvas tabs, graph tabs —
/// everything with a "pane header" surface reuses this.
class ClidePaneChrome extends StatelessWidget {
  const ClidePaneChrome({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.leading,
    this.onClose,
    this.trailing,
  });

  /// Primary label in the header — typically the pane kind + an
  /// abbreviated path / session name (`terminal — ~/clide`).
  final String title;

  /// Optional secondary line (cwd hint, session id, status).
  final String? subtitle;

  /// Icon or badge drawn before the title.
  final Widget? leading;

  /// Main pane content.
  final Widget child;

  /// If provided, renders an `x` close button on the right. Primary
  /// Claude panes deliberately pass `null` so the user can't hide the
  /// primary (D-041).
  final VoidCallback? onClose;

  /// Extra trailing widgets (status indicator, menu button, etc.).
  /// Drawn before the close button when both are present.
  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return ColoredBox(
      color: tokens.panelBackground,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(
            title: title,
            subtitle: subtitle,
            leading: leading,
            onClose: onClose,
            trailing: trailing,
          ),
          const ClideDivider(),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Semantics(
      button: true,
      label: 'Close pane',
      onTap: widget.onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hover ? tokens.tabCloseHover : null,
            ),
            child: ClideIcon(
              const CloseIcon(),
              size: 10,
              color: tokens.panelHeaderForeground,
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.onClose,
    required this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final VoidCallback? onClose;
  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'pane header: $title',
      child: ColoredBox(
        color: tokens.panelHeader,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 6)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClideText(
                      title,
                      fontSize: 12,
                      color: tokens.panelHeaderForeground,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      ClideText(
                        subtitle!,
                        fontSize: 11,
                        muted: true,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...trailing!.map(
                (w) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: w,
                ),
              ),
              if (onClose != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _CloseButton(onPressed: onClose!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
