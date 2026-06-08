import 'dart:async';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'extension.dart' show buildClideMenuTree;
import 'menu_model.dart';

/// Open/close state for the application menu bar (T-48). Owned by the root
/// shell so the Alt-mnemonic key hook and the bar widget share one source of
/// truth. Only one menu is open at a time.
class MenuBarController extends ChangeNotifier {
  int? _openIndex;
  List<String> _mnemonics = const [];

  int? get openIndex => _openIndex;
  bool get isOpen => _openIndex != null;

  /// Set by the bar each build so the Alt hook can map a letter → menu index
  /// without knowing the menu structure. Does not notify (called during build).
  void setMnemonics(List<String> m) => _mnemonics = m;

  /// The menu index whose mnemonic is [ch] (case-insensitive), or null.
  int? indexForMnemonic(String ch) {
    final i = _mnemonics.indexOf(ch.toLowerCase());
    return i < 0 ? null : i;
  }

  void open(int i) {
    if (_openIndex == i) return;
    _openIndex = i;
    notifyListeners();
  }

  void close() {
    if (_openIndex == null) return;
    _openIndex = null;
    notifyListeners();
  }

  void toggle(int i) => _openIndex == i ? close() : open(i);

  void openNext() {
    if (_openIndex == null || _mnemonics.isEmpty) return;
    open((_openIndex! + 1) % _mnemonics.length);
  }

  void openPrev() {
    if (_openIndex == null || _mnemonics.isEmpty) return;
    open((_openIndex! - 1 + _mnemonics.length) % _mnemonics.length);
  }
}

/// The application menu bar: a row of top-level menu buttons (File / View /
/// Help) embedded in the hat. Resolves the curated tree against the live
/// command set on every relevant change so titles, enablement, and keybindings
/// stay current.
class MenuBar extends StatelessWidget {
  const MenuBar({super.key, required this.controller});

  final MenuBarController controller;

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    // Note: we READ the keymap for binding labels but don't LISTEN to it —
    // it notifies during other widgets' builds (scope-flag changes when a
    // dialog/overlay opens), which would mark this sibling dirty mid-build.
    // Labels refresh on the next command/project rebuild, which is enough
    // since keybindings don't change at runtime.
    return ListenableBuilder(
      listenable: Listenable.merge([controller, kernel.commands, kernel.project]),
      builder: (ctx, _) {
        final menus = resolveMenus(
          buildClideMenuTree(),
          kernel.commands,
          kernel,
          bindingLabel: (id) => keymapBindingLabel(kernel.keymap, id),
        );
        controller.setMnemonics([for (final m in menus) m.title[m.mnemonic].toLowerCase()]);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < menus.length; i++) _TopMenuButton(index: i, menu: menus[i], controller: controller, kernel: kernel),
          ],
        );
      },
    );
  }
}

class _TopMenuButton extends StatefulWidget {
  const _TopMenuButton({required this.index, required this.menu, required this.controller, required this.kernel});
  final int index;
  final ResolvedMenu menu;
  final MenuBarController controller;
  final KernelServices kernel;

  @override
  State<_TopMenuButton> createState() => _TopMenuButtonState();
}

/// Adapts the shared [MenuBarController] (single-open across buttons) to the
/// per-button [ClideOverlayController] the primitive drives. Reads/writes go
/// straight through to the bar so there's one source of truth; it notifies when
/// this button's open state flips so the anchored overlay opens/closes in step.
class _MenuOverlayAdapter extends ClideOverlayController {
  _MenuOverlayAdapter(this._bar, this._index) : _last = _bar.openIndex == _index {
    _bar.addListener(_onBar);
  }

  final MenuBarController _bar;
  final int _index;
  bool _last;

  void _onBar() {
    final now = _bar.openIndex == _index;
    if (now != _last) {
      _last = now;
      notifyListeners();
    }
  }

  @override
  bool get isOpen => _bar.openIndex == _index;
  @override
  void open() => _bar.open(_index);
  @override
  void close() => _bar.close();
  @override
  void toggle() => _bar.toggle(_index);

  @override
  void dispose() {
    _bar.removeListener(_onBar);
    super.dispose();
  }
}

class _TopMenuButtonState extends State<_TopMenuButton> {
  late final _MenuOverlayAdapter _overlay = _MenuOverlayAdapter(widget.controller, widget.index);

  @override
  void dispose() {
    _overlay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final open = widget.controller.openIndex == widget.index;
    return ClideAnchoredOverlay(
      controller: _overlay,
      side: ClideAnchorSide.below,
      align: ClideAnchorAlign.start,
      offset: const Offset(0, 2),
      autoFlip: false, // the bar sits at the top; menus always open downward
      rootOverlay: true,
      overlayBuilder: (ctx, ctrl) => ClideMenu(
        onClose: ctrl.close,
        onArrowLeft: widget.controller.openPrev,
        onArrowRight: widget.controller.openNext,
        entries: [
          for (final node in widget.menu.items)
            if (node is ResolvedItem)
              ClideMenuItem(
                label: node.title,
                enabled: node.enabled,
                trailing: node.keybinding != null
                    ? ClideText(node.keybinding!, fontSize: clideFontSmall, fontFamily: clideMonoFamily, color: ClideTheme.of(ctx).surface.globalTextMuted)
                    : null,
                onSelect: () => unawaited(widget.kernel.commands.execute(node.commandId)),
              )
            else
              const ClideMenuSeparator(),
        ],
      ),
      anchor: MouseRegion(
        // Once a menu is open, hovering a sibling switches to it (Zed behavior).
        onEnter: (_) {
          if (widget.controller.isOpen) widget.controller.open(widget.index);
        },
        child: ClideTappable(
          onTap: () => widget.controller.toggle(widget.index),
          builder: (ctx, hovered, _) => Container(
            height: hatHeight,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: clideInsetStandard),
            color: open || hovered ? tokens.listItemHoverBackground : null,
            child: ClideText(
              widget.menu.title,
              fontSize: 12,
              color: open || hovered ? tokens.globalForeground : tokens.chromeForeground,
            ),
          ),
        ),
      ),
    );
  }
}
