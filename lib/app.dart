import 'package:clide/builtin/welcome/src/welcome_view.dart';
import 'package:clide/extension/src/contribution.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
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
      title: 'clide',
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

  @override
  void initState() {
    super.initState();
    _keyFocus = FocusNode()..requestFocus();
  }

  @override
  void dispose() {
    _keyFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return DefaultTextStyle(
      style: TextStyle(
        color: tokens.globalForeground,
        fontSize: 15,
        fontWeight: clideUiDefaultWeight,
        fontFamily: clideUiFamily,
        fontFamilyFallback: clideUiFamilyFallback,
      ),
      child: KeyboardListener(
        focusNode: _keyFocus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: ColoredBox(
          color: tokens.globalBackground,
          child: DialogHost(
            router: widget.services.dialog,
            child: Stack(
              children: [
                const Positioned.fill(child: RootLayout()),
                const ClidePalette(),
                const Positioned.fill(child: _WelcomeOverlay()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onKey(KeyEvent event) {
    final binding = KeybindingResolver.fromKeyEvent(
      event,
      HardwareKeyboard.instance,
    );
    if (binding == null) return;
    final commandId = widget.services.keybindings.commandFor(binding);
    if (commandId == null) return;
    widget.services.commands.execute(commandId);
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
        final sidebarSize = a.sizeOf(Slots.sidebar) ?? 240;
        final contextSize = a.sizeOf(Slots.contextPanel) ?? 280;
        final statusHeight = a.sizeOf(Slots.statusbar) ?? 26;

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
                      child: Column(children: [
                        ColumnHat.left(windowControls: kernel.window),
                        Expanded(child: SlotHost(slot: Slots.sidebar)),
                      ]),
                    ),
                    DragResizeHandle(
                      arrangement: a,
                      slot: Slots.sidebar,
                      axis: Axis.horizontal,
                    ),
                  ],
                  Expanded(child: Column(children: [
                    ColumnHat.center(
                      windowControls: kernel.window,
                      project: kernel.project.current?.path.split('/').last,
                      branch: null,
                    ),
                    const Expanded(child: SlotHost(slot: Slots.workspace)),
                  ])),
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
                      child: Column(children: [
                        ColumnHat.right(windowControls: kernel.window),
                        Expanded(child: SlotHost(slot: Slots.contextPanel)),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
            if (statusVisible)
              Container(
                height: statusHeight,
                decoration: BoxDecoration(border: Border(top: BorderSide(color: ClideTheme.of(ctx).surface.dividerColor))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (sidebarVisible && !sidebarCollapsed)
                      SizedBox(width: sidebarSize, child: _BottomRail(slot: Slots.sidebar))
                    else if (sidebarVisible && sidebarCollapsed)
                      const SizedBox(width: ClideSpine.width),
                    Expanded(child: const StatusbarHost()),
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

class SlotHost extends StatelessWidget {
  const SlotHost({super.key, required this.slot});
  final SlotId slot;

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideTheme.of(context).surface;
    return ListenableBuilder(
      listenable: Listenable.merge([kernel.panels, kernel.i18n]),
      builder: (ctx, _) {
        final tabs = kernel.panels.tabsFor(slot);
        if (tabs.isEmpty) {
          return Container(color: tokens.panelBackground);
        }
        final activeId = kernel.panels.activeTabIn(slot) ?? tabs.first.id;
        final active = tabs.firstWhere(
          (t) => t.id == activeId,
          orElse: () => tabs.first,
        );

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
                  for (final t in tabs) ClideTabItem(id: t.id, title: _resolveTitle(ctx, t)),
                ],
                activeId: active.id,
                onSelect: (id) => kernel.panels.activateTab(slot, id),
              ),
              ClideDivider(),
              Expanded(child: active.build(ctx)),
            ],
          ),
        );
      },
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
      color: tokens.sidebarBackground,
      alignment: Alignment.topLeft,
      child: active.build(context),
    );
  }
}

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
        final primary = claude ?? active;

        if (!editorOpen || editorTab == null) {
          return Container(color: tokens.panelBackground, child: primary.build(ctx));
        }

        final ratio = kernel.arrangement.editorRatio;
        return Container(
          color: tokens.panelBackground,
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final totalHeight = constraints.maxHeight;
              final editorHeight = (totalHeight * ratio).clamp(60.0, totalHeight - 60.0);
              return Column(
                children: [
                  SizedBox(height: editorHeight, child: editorTab.build(ctx)),
                  _EditorDragHandle(arrangement: kernel.arrangement, totalHeight: totalHeight),
                  Expanded(child: primary.build(ctx)),
                ],
              );
            },
          ),
        );
      },
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
  double? _dragStartRatio;
  double? _dragStartY;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return MouseRegion(
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
        child: Container(height: 4, color: _hovered ? tokens.panelActiveBorder : tokens.panelBorder),
      ),
    );
  }
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
        if (tabs.isEmpty) return Container(color: tokens.statusBarBackground);
        final activeId = kernel.panels.activeTabIn(slot) ?? tabs.first.id;
        return Container(
          color: tokens.statusBarBackground,
          child: ClideIconRail(
            items: [
              for (final t in tabs)
                ClideIconRailItem(
                  id: t.id,
                  icon: _iconFor(slot, t),
                  tooltip: SlotHost._resolveTitle(ctx, t),
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
        return Container(
          color: tokens.statusBarBackground,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (final item in left) item.build(ctx),
              const Spacer(),
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
