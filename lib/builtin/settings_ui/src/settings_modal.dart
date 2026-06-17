import 'package:clide/builtin/settings_ui/src/settings_category_view.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The schema-driven Settings panel shell (T-445, epic T-444).
///
/// A centered modal over the dimmed app (hosted by [DialogHost] via
/// `ctx.dialog.show`), built from the `modalSurface*` tokens (D-7, no
/// Material). It frames the two regions the epic fills in:
///
/// - the **category rail** on the left (interactive navigation lands in
///   T-447; the list is data-driven from the registered schemas), and
/// - the **scrolling carded panel** on the right (the schema field renderer
///   is [SettingsCategoryView], T-448).
///
/// Categories come from the kernel [SettingsRegistry]; until one registers a
/// schema the panel shows its empty state. Dismiss with the close button, Esc,
/// or a barrier tap (the last handled by [DialogHost]).
///
/// Wireframe: `docs/design/wireframes/settings/settings-screen.png`.
class SettingsModal extends StatefulWidget {
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
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal> {
  /// Selected category id; null falls back to the first registered category.
  /// The rail sets this in T-447.
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final i = ClideKernel.of(context).i18n;
    final tokens = ClideTheme.of(context).surface;
    final title = i.string('modal.title', namespace: SettingsModal.ns, placeholder: 'Settings');

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onDismiss();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        container: true,
        label: title,
        explicitChildNodes: true,
        child: ClideSurface(
          width: SettingsModal._width,
          height: SettingsModal._height,
          color: tokens.modalSurfaceBackground,
          border: tokens.modalSurfaceBorder,
          borderRadius: BorderRadius.circular(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(title: title, onClose: widget.onDismiss),
              const ClideDivider(),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(width: SettingsModal._railWidth, child: _CategoryRail()),
                    const ClideDivider(axis: Axis.vertical),
                    Expanded(child: _SettingsPanel(selectedId: _selectedId)),
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
          decoration: BoxDecoration(
            color: hovered ? tokens.listItemHoverBackground : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClideIcon(const CloseIcon(), size: 16, color: tokens.globalForeground),
        ),
      ),
    );
  }
}

/// Left rail. The interactive category list lands in T-447; for now it shows
/// only its section header.
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

/// Right panel — renders the selected category's schema (or the first
/// registered one) via [SettingsCategoryView]; the empty state shows when no
/// category is registered. The region recedes to panelBackground so the
/// panelHeader cards pop (surface.md).
class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final registry = ClideKernel.of(context).settingsRegistry;
    return ColoredBox(
      color: tokens.panelBackground,
      child: ListenableBuilder(
        listenable: registry,
        builder: (context, _) {
          final categories = registry.categories;
          if (categories.isEmpty) return const _EmptyState();
          final selected = (selectedId == null ? null : registry.byId(selectedId!)) ?? categories.first;
          return SettingsCategoryView(category: selected);
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
