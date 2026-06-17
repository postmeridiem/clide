import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The schema-driven Settings panel shell (T-445, epic T-444).
///
/// A centered modal over the dimmed app (hosted by [DialogHost] via
/// `ctx.dialog.show`), built from the `modalSurface*` tokens (D-7, no
/// Material). It frames the two regions the rest of the epic fills in:
///
/// - the **category rail** on the left (navigation lands in T-447; the
///   list is data-driven from the schemas each subsystem registers), and
/// - the **scrolling carded panel** on the right (the schema field
///   renderer is T-448).
///
/// Until any category registers a schema the panel shows its empty state —
/// that is the correct runtime state, not a placeholder. Dismiss with the
/// close button, Esc, or a barrier tap (the last handled by [DialogHost]).
///
/// Wireframe: `docs/design/wireframes/settings/settings-screen.png`.
class SettingsModal extends StatelessWidget {
  const SettingsModal({super.key, required this.onDismiss});

  /// Closes the modal. Wired to the dialog router's `dismiss` by the
  /// opener (see `SettingsUiExtension`).
  final VoidCallback onDismiss;

  static const ns = 'builtin.settings-ui';

  // The modal is a fixed-size desktop surface (the app is a desktop host);
  // the right panel scrolls when its cards exceed the height (surface.md).
  static const double _width = 760;
  static const double _height = 560;
  static const double _railWidth = 196;

  @override
  Widget build(BuildContext context) {
    final i = ClideKernel.of(context).i18n;
    final tokens = ClideTheme.of(context).surface;
    final title = i.string('modal.title', namespace: ns, placeholder: 'Settings');

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          onDismiss();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        container: true,
        label: title,
        explicitChildNodes: true,
        child: ClideSurface(
          width: _width,
          height: _height,
          color: tokens.modalSurfaceBackground,
          border: tokens.modalSurfaceBorder,
          borderRadius: BorderRadius.circular(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(title: title, onClose: onDismiss),
              const ClideDivider(),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: _railWidth, child: const _CategoryRail()),
                    const ClideDivider(axis: Axis.vertical),
                    const Expanded(child: _SettingsPanel()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Title bar: gear glyph + "Settings" on the left, close ✕ on the right.
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      child: Row(
        children: [
          ClideIcon(const GearIcon(), size: 16, color: tokens.globalForeground),
          const SizedBox(width: 8),
          Expanded(child: ClideText(title, fontSize: 15, fontWeight: FontWeight.w600)),
          _CloseButton(onTap: onClose),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final i = ClideKernel.of(context).i18n;
    final label = i.string('modal.close', namespace: SettingsModal.ns, placeholder: 'Close');
    final hint = i.string('modal.close.hint', namespace: SettingsModal.ns, placeholder: 'Close settings');
    return Semantics(
      button: true,
      label: label,
      hint: hint,
      onTap: onTap,
      excludeSemantics: true,
      child: ClideTappable(
        cursor: SystemMouseCursors.click,
        onTap: onTap,
        builder: (ctx, hovered, pressed) => Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: hovered ? tokens.listItemHoverBackground : null, borderRadius: BorderRadius.circular(4)),
          child: ClideIcon(const CloseIcon(), size: 16, color: tokens.globalForeground),
        ),
      ),
    );
  }
}

/// Left rail. The category list is populated from registered schemas in
/// T-447; for now it shows only its section header.
class _CategoryRail extends StatelessWidget {
  const _CategoryRail();

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final i = ClideKernel.of(context).i18n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClideText(
            i.string('rail.header', namespace: SettingsModal.ns, placeholder: 'Categories'),
            fontSize: clideFontCaption,
            color: tokens.sidebarSectionHeader,
            fontFamily: clideMonoFamily,
          ),
        ],
      ),
    );
  }
}

/// Right panel. The schema-driven field renderer fills this in T-448; with
/// no category registered yet it shows the empty state.
class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel();

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final i = ClideKernel.of(context).i18n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ClideText(
          i.string('panel.empty', namespace: SettingsModal.ns, placeholder: 'No settings categories are registered yet.'),
          color: tokens.globalTextMuted,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
