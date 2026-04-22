import 'package:clide_app/extension/src/contribution.dart';
import 'package:clide_app/kernel/kernel.dart';
import 'package:clide_app/widgets/widgets.dart';
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
        fontSize: 14,
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
            if (statusVisible)
              SizedBox(
                height: statusHeight,
                child: const StatusbarHost(),
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
      child: Column(
        children: [
          Expanded(child: active.build(context)),
          ClideIconRail(
            items: [
              for (final t in tabs)
                ClideIconRailItem(
                  id: t.id,
                  icon: _iconFor(t),
                  tooltip: SlotHost._resolveTitle(context, t),
                ),
            ],
            activeId: activeId,
            onSelect: onSelect,
          ),
        ],
      ),
    );
  }

  static ClideIconPainter _iconFor(TabContribution t) {
    if (t.icon is ClideIconPainter) return t.icon as ClideIconPainter;
    return switch (t.id) {
      'files.tree' => const FolderIcon(),
      'git.panel' => const GitBranchIcon(),
      'pql.panel' => const SearchIcon(),
      'problems.panel' => const WarningIcon(),
      _ => const DotIcon(),
    };
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
      child: Column(
        children: [
          Expanded(child: active.build(context)),
          ClideIconRail(
            items: [
              for (final t in tabs)
                ClideIconRailItem(
                  id: t.id,
                  icon: _iconFor(t),
                  tooltip: SlotHost._resolveTitle(context, t),
                ),
            ],
            activeId: activeId,
            onSelect: onSelect,
          ),
        ],
      ),
    );
  }

  static ClideIconPainter _iconFor(TabContribution t) {
    if (t.icon is ClideIconPainter) return t.icon as ClideIconPainter;
    return switch (t.id) {
      'markdown.viewer' => const DotIcon(),
      'graph.view' => const SearchIcon(),
      _ => const DotIcon(),
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
          child: Row(
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
