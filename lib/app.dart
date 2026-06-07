import 'dart:async';
import 'dart:io' show Platform;

import 'package:clide/builtin/menubar/menubar.dart';
import 'package:clide/builtin/welcome/src/welcome_view.dart';
import 'package:clide/clide.dart' show clideName;
import 'package:clide/extension/src/contribution.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ClideApp extends StatelessWidget {
  const ClideApp({super.key, required this.services});

  final KernelServices services;

  @override
  Widget build(BuildContext context) {
    return ClideKernel(
      services: services,
      child: ClideTheme(
        controller: services.theme,
        child: _AppRoot(services: services),
      ),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot({required this.services});
  final KernelServices services;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      debugShowCheckedModeBanner: false,
      title: clideName,
      color: const Color(0xFF000000),
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (ctx, _, __) => builder(ctx),
      ),
      home: _RootShell(services: services),
    );
  }
}

class _RootShell extends StatefulWidget {
  const _RootShell({required this.services});
  final KernelServices services;

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> {
  late final FocusNode _keyFocus;
  final MenuBarController _menuBar = MenuBarController();

  @override
  void initState() {
    super.initState();
    _keyFocus = FocusNode()..requestFocus();
    widget.services.textZoom.addListener(_onZoom);
  }

  @override
  void dispose() {
    widget.services.textZoom.removeListener(_onZoom);
    _menuBar.dispose();
    _keyFocus.dispose();
    super.dispose();
  }

  void _onZoom() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return DefaultTextStyle(
      style: TextStyle(
        color: tokens.globalForeground,
        fontSize: 15,
        height: clideLineHeight,
        fontWeight: clideUiDefaultWeight,
        fontFamily: clideUiFamily,
        fontFamilyFallback: clideUiFamilyFallback,
      ),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(widget.services.textZoom.scale)),
        child: Actions(
          actions: <Type, Action<Intent>>{
            TextScaleIncreaseIntent: CallbackAction<TextScaleIncreaseIntent>(
              onInvoke: (_) {
                widget.services.textZoom.increase();
                return null;
              },
            ),
            TextScaleDecreaseIntent: CallbackAction<TextScaleDecreaseIntent>(
              onInvoke: (_) {
                widget.services.textZoom.decrease();
                return null;
              },
            ),
            TextScaleResetIntent: CallbackAction<TextScaleResetIntent>(
              onInvoke: (_) {
                widget.services.textZoom.reset();
                return null;
              },
            ),
            InvokeCommandIntent: CallbackAction<InvokeCommandIntent>(
              onInvoke: (intent) {
                widget.services.commands.execute(intent.commandId);
                return null;
              },
            ),
            PaletteOpenIntent: CallbackAction<PaletteOpenIntent>(
              onInvoke: (_) {
                widget.services.palette.open();
                return null;
              },
            ),
            QuickOpenIntent: CallbackAction<QuickOpenIntent>(
              onInvoke: (_) {
                widget.services.quickOpen.open();
                return null;
              },
            ),
            FindInFilesIntent: CallbackAction<FindInFilesIntent>(
              onInvoke: (_) {
                widget.services.arrangement.setVisible(Slots.sidebar, true);
                widget.services.arrangement.setCollapsed(Slots.sidebar, false);
                widget.services.panels.activateTab(Slots.sidebar, 'search.findInFiles');
                return null;
              },
            ),
            FocusNextPanelIntent: CallbackAction<FocusNextPanelIntent>(
              onInvoke: (_) {
                widget.services.focus.focusNextSlot();
                return null;
              },
            ),
            FocusPreviousPanelIntent: CallbackAction<FocusPreviousPanelIntent>(
              onInvoke: (_) {
                widget.services.focus.focusPreviousSlot();
                return null;
              },
            ),
          },
          child: KeyboardListener(
            focusNode: _keyFocus,
            autofocus: true,
            onKeyEvent: _onKey,
            child: ColoredBox(
              color: tokens.globalBackground,
              child: ClideResizeBorder(
                windowControls: widget.services.window,
                child: Column(
                  children: [
                    _HatBar(kernel: widget.services, menuBar: _menuBar),
                    Expanded(
                      child: DialogHost(
                        router: widget.services.dialog,
                        child: Stack(
                          children: [
                            const Positioned.fill(child: RootLayout()),
                            const ClidePalette(),
                            const QuickOpenOverlay(),
                            const Positioned.fill(child: _WelcomeOverlay()),
                            const ToastOverlay(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onKey(KeyEvent event) {
    if (_handleMenuMnemonic(event)) return;
    final intent = widget.services.keymap.resolveEvent(event, HardwareKeyboard.instance);
    if (intent == null) return;
    // Dispatch the intent. Try the focused context first so feature
    // widgets (palette, editor, …) get a chance to handle their own
    // intents; fall back to the app root's Actions for global ones
    // (text scale, generic command bridge).
    final ctx = FocusManager.instance.primaryFocus?.context ?? context;
    Actions.maybeInvoke(ctx, intent);
  }

  /// `Alt+<mnemonic>` opens (or toggles) the matching application menu (T-48).
  /// Returns true when consumed so it never falls through to keymap resolution.
  bool _handleMenuMnemonic(KeyEvent event) {
    if (event is! KeyDownEvent || !HardwareKeyboard.instance.isAltPressed) return false;
    final label = event.logicalKey.keyLabel.toLowerCase();
    if (label.length != 1) return false;
    final idx = _menuBar.indexForMnemonic(label);
    if (idx == null) return false;
    _menuBar.toggle(idx);
    return true;
  }
}

class RootLayout extends StatelessWidget {
  const RootLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([kernel.panels, kernel.arrangement]),
      builder: (ctx, _) {
        final a = kernel.arrangement;
        final sidebarVisible = a.isVisible(Slots.sidebar);
        final sidebarCollapsed = a.isCollapsed(Slots.sidebar);
        final contextVisible = a.isVisible(Slots.contextPanel);
        final contextCollapsed = a.isCollapsed(Slots.contextPanel);
        final statusVisible = a.isVisible(Slots.statusbar);
        final sidebarSize = a.sizeOf(Slots.sidebar) ?? 400;
        final contextSize = a.sizeOf(Slots.contextPanel) ?? 420;
        final statusHeight = a.sizeOf(Slots.statusbar) ?? 26;
        // Bottom output dock (T-54 / D-87): pushes the workspace up when open,
        // capped at half the window so Claude stays the largest surface (the
        // D-47 amendment).
        final dockVisible = a.isVisible(Slots.dock);
        final dockMax = (((MediaQuery.of(ctx).size.height) - statusHeight) * 0.5).clamp(80.0, double.infinity).toDouble();
        final dockHeight = dockVisible ? ((a.sizeOf(Slots.dock) ?? 200).clamp(0.0, dockMax)).toDouble() : 0.0;

        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  if (sidebarVisible && sidebarCollapsed)
                    ClideSpine(
                      label: _sidebarSpineLabel(kernel),
                      side: SpineSide.left,
                      onExpand: () => a.setCollapsed(Slots.sidebar, false),
                    )
                  else if (sidebarVisible) ...[
                    SizedBox(
                      width: sidebarSize,
                      child: SlotHost(slot: Slots.sidebar),
                    ),
                    DragResizeHandle(
                      arrangement: a,
                      slot: Slots.sidebar,
                      axis: Axis.horizontal,
                    ),
                  ],
                  const Expanded(child: SlotHost(slot: Slots.workspace)),
                  if (contextVisible && contextCollapsed)
                    ClideSpine(
                      label: 'context',
                      side: SpineSide.right,
                      onExpand: () => a.setCollapsed(Slots.contextPanel, false),
                    )
                  else if (contextVisible) ...[
                    DragResizeHandle(
                      arrangement: a,
                      slot: Slots.contextPanel,
                      axis: Axis.horizontal,
                    ),
                    SizedBox(
                      width: contextSize,
                      child: SlotHost(slot: Slots.contextPanel),
                    ),
                  ],
                ],
              ),
            ),
            if (dockVisible)
              SizedBox(
                height: dockHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: ClideTheme.of(ctx).surface.chromeBorder))),
                  child: SlotHost(slot: Slots.dock),
                ),
              ),
            if (statusVisible)
              Container(
                height: statusHeight,
                decoration: BoxDecoration(border: Border(top: BorderSide(color: ClideTheme.of(ctx).surface.chromeBorder))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (sidebarVisible && !sidebarCollapsed)
                      SizedBox(width: sidebarSize, child: _BottomRail(slot: Slots.sidebar))
                    else if (sidebarVisible && sidebarCollapsed)
                      const SizedBox(width: ClideSpine.width),
                    const Expanded(child: StatusbarHost()),
                    if (contextVisible && !contextCollapsed)
                      SizedBox(width: contextSize, child: _BottomRail(slot: Slots.contextPanel))
                    else if (contextVisible && contextCollapsed)
                      const SizedBox(width: ClideSpine.width),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  static String _sidebarSpineLabel(KernelServices kernel) {
    final activeTab = kernel.panels.activeTabIn(Slots.sidebar);
    if (activeTab == null) return 'overview';
    final tabs = kernel.panels.tabsFor(Slots.sidebar);
    for (final t in tabs) {
      if (t.id == activeTab) return t.title.toLowerCase();
    }
    return 'overview';
  }
}

class _HatBar extends StatelessWidget {
  const _HatBar({required this.kernel, required this.menuBar});
  final KernelServices kernel;
  final MenuBarController menuBar;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
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
                child: _ProjectSwitcherButton(kernel: kernel, tokens: tokens),
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
    return Row(children: [
      _WinBtn(icon: const PhosphorIconPainter(0xe32a), onTap: wc.minimize, tokens: tokens),
      _WinBtn(icon: const PhosphorIconPainter(0xe45e), onTap: wc.toggleMaximize, tokens: tokens),
      _WinBtn(icon: PhosphorIcons.xMark, onTap: wc.close, tokens: tokens, isClose: true),
    ]);
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
        child: ClideIcon(
          icon,
          size: 14,
          color: hovered && isClose ? tokens.windowControlCloseHoverForeground : tokens.chromeForeground,
        ),
      ),
    );
  }
}

class _ProjectSwitcherButton extends StatelessWidget {
  const _ProjectSwitcherButton({required this.kernel, required this.tokens});
  final KernelServices kernel;
  final SurfaceTokens tokens;

  void _openSwitcher() {
    kernel.dialog.show<String>((ctx, dismiss) {
      return _ProjectSwitcherDropdown(kernel: kernel, onDismiss: dismiss);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: kernel.project,
      builder: (ctx, _) {
        final name = kernel.project.current?.path.split('/').last;
        final label = name != null ? '$clideName > $name' : clideName;
        return ClideTappable(
          onTap: _openSwitcher,
          builder: (context, hovered, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClideText(label, fontSize: 12, color: hovered ? tokens.globalForeground : tokens.chromeForeground, fontFamily: clideMonoFamily),
              const SizedBox(width: 4),
              ClideIcon(PhosphorIcons.caretDown, size: 8, color: tokens.chromeForeground),
            ],
          ),
        );
      },
    );
  }
}

class _ProjectSwitcherDropdown extends StatefulWidget {
  const _ProjectSwitcherDropdown({required this.kernel, required this.onDismiss});
  final KernelServices kernel;
  final void Function([String?]) onDismiss;

  @override
  State<_ProjectSwitcherDropdown> createState() => _ProjectSwitcherDropdownState();
}

class _ProjectSwitcherDropdownState extends State<_ProjectSwitcherDropdown> {
  String _filter = '';
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode()..requestFocus();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _openProject(String path) async {
    final ok = await widget.kernel.project.open(path);
    if (ok) {
      widget.kernel.panels.activateTab(Slots.workspace, 'claude.primary');
      widget.onDismiss();
    }
  }

  // File actions now live as commands (file.openFolder / file.newWindow /
  // file.closeWorkspace) owned by the menu-bar extension (T-48). The switcher
  // dismisses itself and dispatches the command so both surfaces share one
  // implementation.
  void _runFileCommand(String command) {
    widget.onDismiss();
    unawaited(widget.kernel.commands.execute(command));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onDismiss();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final recents = widget.kernel.project.recents;
    final lf = _filter.toLowerCase();
    final filtered = lf.isEmpty ? recents : recents.where((r) => r.name.toLowerCase().contains(lf) || r.path.toLowerCase().contains(lf)).toList();

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 420),
        decoration: BoxDecoration(
          color: tokens.dropdownBackground,
          border: Border.all(color: tokens.dropdownBorder),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClideFilterBox(hint: 'Search projects…', onChanged: (v) => setState(() => _filter = v)),
            if (filtered.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ClideText('Recent Projects', fontSize: clideFontCaption, color: tokens.globalTextMuted),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _RecentProjectRow(
                    project: filtered[i],
                    tokens: tokens,
                    onTap: () => _openProject(filtered[i].path),
                  ),
                ),
              ),
            ] else
              const Padding(padding: EdgeInsets.all(12), child: ClideText('No recent projects.', muted: true)),
            Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: tokens.dividerColor))),
              child: Column(
                children: [
                  _ActionRow(
                      label: 'Open Local Project',
                      shortcut: Platform.isMacOS ? '⌘O' : 'Ctrl+O',
                      tokens: tokens,
                      onTap: () => _runFileCommand('file.openFolder')),
                  _ActionRow(
                      label: 'New Window', shortcut: Platform.isMacOS ? '⌘⇧N' : 'Ctrl+Shift+N', tokens: tokens, onTap: () => _runFileCommand('file.newWindow')),
                  if (widget.kernel.project.isOpen)
                    _ActionRow(label: 'Close Project', shortcut: '', tokens: tokens, onTap: () => _runFileCommand('file.closeWorkspace')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentProjectRow extends StatelessWidget {
  const _RecentProjectRow({required this.project, required this.tokens, required this.onTap});
  final RecentProject project;
  final SurfaceTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClideTappable(
      onTap: onTap,
      builder: (context, hovered, _) => Container(
        color: hovered ? tokens.listItemHoverBackground : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            ClideIcon(PhosphorIcons.folder, size: 14, color: tokens.globalTextMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClideText(project.name, fontSize: 14),
                  if (project.branch != null)
                    Row(
                      children: [
                        // Elide a long path instead of overflowing the row
                        // (matches the welcome recents row; T-160 discipline).
                        Flexible(
                          child: ClideText(project.relativePath,
                              muted: true, fontSize: 12, fontFamily: clideMonoFamily, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        ClideText('  ·  ', muted: true, fontSize: 12),
                        ClideIcon(PhosphorIcons.gitBranch, size: 10, color: tokens.globalTextMuted),
                        const SizedBox(width: 3),
                        ClideText(project.branch!, muted: true, fontSize: 12, fontFamily: clideMonoFamily),
                      ],
                    )
                  else
                    ClideText(project.relativePath, muted: true, fontSize: 12, fontFamily: clideMonoFamily, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            ClideText(project.timeAgo, muted: true, fontSize: 11),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.label, this.shortcut, required this.tokens, required this.onTap});
  final String label;
  final String? shortcut;
  final SurfaceTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClideTappable(
      onTap: onTap,
      builder: (context, hovered, _) => Container(
        color: hovered ? tokens.listItemHoverBackground : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(child: ClideText(label, fontSize: 14)),
            if (shortcut != null && shortcut!.isNotEmpty) ClideText(shortcut!, fontSize: 12, color: tokens.globalTextMuted, fontFamily: clideMonoFamily),
          ],
        ),
      ),
    );
  }
}

class SlotHost extends StatefulWidget {
  const SlotHost({super.key, required this.slot});
  final SlotId slot;

  @override
  State<SlotHost> createState() => _SlotHostState();
}

class _SlotHostState extends State<SlotHost> {
  late final FocusScopeNode _scope = FocusScopeNode(debugLabel: 'SlotScope:${widget.slot.value}');
  FocusTracker? _tracker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final kernel = ClideKernel.of(context);
    if (!identical(_tracker, kernel.focus)) {
      _tracker?.unregisterSlotScope(widget.slot, _scope);
      _tracker = kernel.focus;
      _tracker!.registerSlotScope(widget.slot, _scope);
    }
  }

  @override
  void dispose() {
    _tracker?.unregisterSlotScope(widget.slot, _scope);
    _scope.dispose();
    super.dispose();
  }

  void _onFocusChange(bool hasFocus) {
    if (!hasFocus || _tracker == null) return;
    final kernel = ClideKernel.of(context);
    final activeId = kernel.panels.activeTabIn(widget.slot);
    if (activeId != null) {
      _tracker!.setActive(slot: widget.slot, contributionId: activeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideTheme.of(context).surface;
    return FocusScope(
      node: _scope,
      onFocusChange: _onFocusChange,
      child: FocusTraversalGroup(
        child: ListenableBuilder(
          listenable: Listenable.merge([kernel.panels, kernel.i18n]),
          builder: (ctx, _) {
            final tabs = kernel.panels.tabsFor(widget.slot);
            if (tabs.isEmpty) {
              return Container(color: tokens.panelBackground);
            }
            final activeId = kernel.panels.activeTabIn(widget.slot) ?? tabs.first.id;
            final active = tabs.firstWhere(
              (t) => t.id == activeId,
              orElse: () => tabs.first,
            );
            return _SlotBody(slot: widget.slot, tabs: tabs, active: active, activeId: activeId);
          },
        ),
      ),
    );
  }
}

class _SlotBody extends StatelessWidget {
  const _SlotBody({required this.slot, required this.tabs, required this.active, required this.activeId});
  final SlotId slot;
  final List<TabContribution> tabs;
  final TabContribution active;
  final String activeId;

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideTheme.of(context).surface;

    if (slot == Slots.sidebar) {
      return _SidebarSlot(
        tabs: tabs,
        active: active,
        activeId: activeId,
        onSelect: (id) => kernel.panels.activateTab(slot, id),
      );
    }

    if (slot == Slots.contextPanel) {
      return _ContextSlot(
        tabs: tabs,
        active: active,
        activeId: activeId,
        onSelect: (id) => kernel.panels.activateTab(slot, id),
      );
    }

    if (slot == Slots.workspace) {
      return _WorkspaceSlot(tabs: tabs, active: active);
    }

    return Container(
      color: tokens.panelBackground,
      child: Column(
        children: [
          ClideTabBar(
            items: [
              for (final t in tabs) ClideTabItem(id: t.id, title: _resolveTitle(context, t)),
            ],
            activeId: active.id,
            onSelect: (id) => kernel.panels.activateTab(slot, id),
          ),
          ClideDivider(),
          Expanded(child: active.build(context)),
        ],
      ),
    );
  }

  static String _resolveTitle(BuildContext context, TabContribution t) {
    final key = t.titleKey;
    final ns = t.i18nNamespace;
    if (key == null || ns == null) return t.title;
    return ClideKernel.of(context).i18n.string(
          key,
          namespace: ns,
          placeholder: t.title,
        );
  }
}

class _SidebarSlot extends StatelessWidget {
  const _SidebarSlot({
    required this.tabs,
    required this.active,
    required this.activeId,
    required this.onSelect,
  });

  final List<TabContribution> tabs;
  final TabContribution active;
  final String activeId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Container(
      color: tokens.chromeBackground,
      alignment: Alignment.topLeft,
      padding: const EdgeInsets.fromLTRB(2, 2, 0, 0),
      child: active.build(context),
    );
  }
}

// Stable identity for the workspace's primary pane (Claude). Opening the
// editor reparents it from a direct child into a Column/Expanded; without a
// stable key Flutter disposes + rebuilds the subtree, and the Claude
// conversation's SelectableRegion then runs a pending selection update
// against now-inactive elements ("selectable not in this registrar" /
// "renderObject of inactive element"). The GlobalKey makes Flutter MOVE the
// element instead, preserving the selection subtree.
final GlobalKey _kWorkspacePrimary = GlobalKey(debugLabel: 'workspace.primary');

class _WorkspaceSlot extends StatelessWidget {
  const _WorkspaceSlot({required this.tabs, required this.active});

  final List<TabContribution> tabs;
  final TabContribution active;

  static const _editorTabId = 'editor.active';
  static const _claudeTabId = 'claude.primary';

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideTheme.of(context).surface;
    return ListenableBuilder(
      listenable: kernel.arrangement,
      builder: (ctx, _) {
        final editorOpen = kernel.arrangement.editorOpen;
        final editorTab = tabs.where((t) => t.id == _editorTabId).firstOrNull;

        final claude = tabs.where((t) => t.id == _claudeTabId).firstOrNull;
        final primaryPane = KeyedSubtree(key: _kWorkspacePrimary, child: (claude ?? active).build(ctx));

        // A non-Claude, non-editor workspace tab being the active one (e.g.
        // diff.view revealed by `clide ui open diff`, T-233) shows in the split
        // region above Claude — "review alongside the conversation" — with a
        // close affordance back to full-Claude. Only when Claude exists below
        // it; with no Claude pane the active tab just takes the whole slot, as
        // before. The editor keeps its own editorOpen-gated split.
        final reveal = (claude != null && active.id != _claudeTabId && active.id != _editorTabId) ? active : null;
        final topTab = reveal ?? (editorOpen ? editorTab : null);

        if (topTab == null) {
          return Container(color: tokens.panelBackground, child: primaryPane);
        }

        final ratio = kernel.arrangement.editorRatio;
        return Container(
          color: tokens.panelBackground,
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final totalHeight = constraints.maxHeight;
              final topHeight = (totalHeight * ratio).clamp(60.0, totalHeight - 60.0);
              return Column(
                children: [
                  SizedBox(
                    height: topHeight,
                    child: reveal != null
                        ? _RevealedTab(
                            tab: reveal,
                            onClose: () => kernel.panels.activateTab(Slots.workspace, _claudeTabId),
                          )
                        : topTab.build(ctx),
                  ),
                  _EditorDragHandle(arrangement: kernel.arrangement, totalHeight: totalHeight),
                  Expanded(child: primaryPane),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// A non-Claude workspace tab revealed in the split region above Claude
/// (T-233): a thin chrome header (title + close) over the tab's body, so the
/// user can review it alongside the conversation and dismiss it back to
/// full-Claude. The editor uses its own split path and never renders here.
class _RevealedTab extends StatelessWidget {
  const _RevealedTab({required this.tab, required this.onClose});

  final TabContribution tab;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Column(
      children: [
        Container(
          height: 28,
          padding: const EdgeInsets.only(left: 10, right: 4),
          color: tokens.panelHeader,
          child: Row(
            children: [
              Expanded(
                child: ClideText(
                  _SlotBody._resolveTitle(context, tab),
                  fontSize: clideFontCaption,
                  color: tokens.panelHeaderForeground,
                  maxLines: 1,
                ),
              ),
              Semantics(
                button: true,
                label: 'Close',
                excludeSemantics: true,
                onTap: onClose,
                child: ClideTappable(
                  onTap: onClose,
                  tooltip: 'Close',
                  builder: (_, hovered, __) => Padding(
                    padding: const EdgeInsets.all(6),
                    child: ClideIcon(PhosphorIcons.xMark, size: 12, color: hovered ? tokens.globalForeground : tokens.globalTextMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: tab.build(context)),
      ],
    );
  }
}

class _EditorDragHandle extends StatefulWidget {
  const _EditorDragHandle({required this.arrangement, required this.totalHeight});

  final LayoutArrangement arrangement;
  final double totalHeight;

  @override
  State<_EditorDragHandle> createState() => _EditorDragHandleState();
}

class _EditorDragHandleState extends State<_EditorDragHandle> {
  bool _hovered = false;
  bool _focused = false;
  double? _dragStartRatio;
  double? _dragStartY;

  // Editor split is a 0..1 fraction; the kernel clamps to 0.15..0.70.
  // 2% per fine step, 10% per Shift step keeps keyboard feel close to
  // the pixel-based DragResizeHandle.
  static const double _stepFine = 0.02;
  static const double _stepCoarse = 0.10;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final lineColor = (_hovered || _focused) ? tokens.panelActiveBorder : tokens.panelBorder;

    final ratio = widget.arrangement.editorRatio;
    String pct(double r) => '${(r.clamp(0.15, 0.70) * 100).round()}%';
    return Semantics(
      container: true,
      slider: true,
      label: 'Editor split',
      value: pct(ratio),
      // increase/decrease actions require matching increased/decreased
      // values, or Flutter asserts on every semantics flush.
      increasedValue: pct(ratio + _stepFine),
      decreasedValue: pct(ratio - _stepFine),
      onIncrease: () => _bump(_stepFine),
      onDecrease: () => _bump(-_stepFine),
      child: FocusableActionDetector(
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowUp): _EditorBumpIntent(-_stepFine),
          SingleActivator(LogicalKeyboardKey.arrowDown): _EditorBumpIntent(_stepFine),
          SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): _EditorBumpIntent(-_stepCoarse),
          SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): _EditorBumpIntent(_stepCoarse),
        },
        actions: <Type, Action<Intent>>{
          _EditorBumpIntent: CallbackAction<_EditorBumpIntent>(
            onInvoke: (intent) {
              _bump(intent.delta);
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeRow,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Listener(
            onPointerDown: (e) {
              _dragStartRatio = widget.arrangement.editorRatio;
              _dragStartY = e.position.dy;
            },
            onPointerMove: (e) {
              final startR = _dragStartRatio;
              final startY = _dragStartY;
              if (startR == null || startY == null || widget.totalHeight <= 0) return;
              final deltaRatio = (e.position.dy - startY) / widget.totalHeight;
              widget.arrangement.setEditorRatio(startR + deltaRatio);
            },
            onPointerUp: (_) {
              _dragStartRatio = null;
              _dragStartY = null;
            },
            child: Container(height: 4, color: lineColor),
          ),
        ),
      ),
    );
  }

  void _bump(double delta) {
    widget.arrangement.setEditorRatio(widget.arrangement.editorRatio + delta);
  }
}

class _EditorBumpIntent extends Intent {
  const _EditorBumpIntent(this.delta);
  final double delta;
}

class _ContextSlot extends StatelessWidget {
  const _ContextSlot({
    required this.tabs,
    required this.active,
    required this.activeId,
    required this.onSelect,
  });

  final List<TabContribution> tabs;
  final TabContribution active;
  final String activeId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Container(
      color: tokens.panelBackground,
      alignment: Alignment.topLeft,
      padding: const EdgeInsets.only(right: 2),
      child: active.build(context),
    );
  }
}

class _BottomRail extends StatelessWidget {
  const _BottomRail({required this.slot});
  final SlotId slot;

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideTheme.of(context).surface;
    return ListenableBuilder(
      listenable: kernel.panels,
      builder: (ctx, _) {
        final tabs = kernel.panels.tabsFor(slot);
        if (tabs.isEmpty) return Container(color: tokens.chromeBackground);
        final activeId = kernel.panels.activeTabIn(slot) ?? tabs.first.id;
        return Container(
          color: tokens.chromeBackground,
          child: ClideIconRail(
            items: [
              for (final t in tabs)
                ClideIconRailItem(
                  id: t.id,
                  icon: _iconFor(slot, t),
                  tooltip: _SlotBody._resolveTitle(ctx, t),
                ),
            ],
            activeId: activeId,
            onSelect: (id) => kernel.panels.activateTab(slot, id),
          ),
        );
      },
    );
  }

  static ClideIconPainter _iconFor(SlotId slot, TabContribution t) {
    if (t.icon is ClideIconPainter) return t.icon as ClideIconPainter;
    if (slot == Slots.sidebar) {
      return switch (t.id) {
        'files.tree' => PhosphorIcons.folder,
        'git.panel' => PhosphorIcons.gitBranch,
        'pql.panel' => PhosphorIcons.magnifyingGlass,
        'problems.panel' => PhosphorIcons.warningCircle,
        'decisions.panel' => PhosphorIcons.lightbulb,
        'tickets.panel' => PhosphorIcons.ticket,
        _ => PhosphorIcons.circlesFour,
      };
    }
    return switch (t.id) {
      'markdown.viewer' => PhosphorIcons.eye,
      'graph.view' => PhosphorIcons.graph,
      'pql.backlinks' => PhosphorIcons.link,
      _ => PhosphorIcons.circlesFour,
    };
  }
}

class StatusbarHost extends StatelessWidget {
  const StatusbarHost({super.key});

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideTheme.of(context).surface;
    return ListenableBuilder(
      listenable: kernel.panels,
      builder: (ctx, _) {
        final items = kernel.panels.contributionsFor(Slots.statusbar).whereType<StatusItemContribution>().toList();
        final left = items.where((i) => i.priority < 100).toList();
        final right = items.where((i) => i.priority >= 100).toList();
        // Two explicit columns within the center (workspace) bar: the LEFT
        // group lives in an Expanded so it absorbs all free space and is
        // start-aligned, and the RIGHT group (tool status, theme switcher)
        // trails it at intrinsic width — so it hugs the workspace block's
        // right edge by construction, no Spacer to fight a flex item (T-239).
        // Left items with flex > 0 wrap in Flexible(loose) so they yield width
        // when tight (T-160).
        return Container(
          color: tokens.chromeBackground,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (final item in left)
                      if (item.flex > 0) Flexible(flex: item.flex, fit: FlexFit.loose, child: item.build(ctx)) else item.build(ctx),
                  ],
                ),
              ),
              for (final item in right) item.build(ctx),
            ],
          ),
        );
      },
    );
  }
}

class _WelcomeOverlay extends StatelessWidget {
  const _WelcomeOverlay();

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    return ListenableBuilder(
      listenable: kernel.project,
      builder: (ctx, _) {
        if (kernel.project.isOpen) return const SizedBox.shrink();
        final tokens = ClideTheme.of(ctx).surface;
        return ColoredBox(
          color: tokens.globalBackground,
          child: const WelcomeView(),
        );
      },
    );
  }
}
