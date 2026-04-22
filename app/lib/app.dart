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
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
          PageRouteBuilder<T>(
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
            child: const RootLayout(),
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
        final contextVisible = a.isVisible(Slots.contextPanel);
        final statusVisible = a.isVisible(Slots.statusbar);
        final sidebarSize = a.sizeOf(Slots.sidebar) ?? 240;
        final contextSize = a.sizeOf(Slots.contextPanel) ?? 280;
        final statusHeight = a.sizeOf(Slots.statusbar) ?? 26;

        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  if (sidebarVisible) ...[
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
                  if (contextVisible) ...[
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
        return Container(
          color: tokens.panelBackground,
          child: Column(
            children: [
              ClideTabBar(
                items: [
                  for (final t in tabs)
                    ClideTabItem(id: t.id, title: _resolveTitle(ctx, t)),
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

  String _resolveTitle(BuildContext context, TabContribution t) {
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

class StatusbarHost extends StatelessWidget {
  const StatusbarHost({super.key});

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideTheme.of(context).surface;
    return ListenableBuilder(
      listenable: kernel.panels,
      builder: (ctx, _) {
        final items = kernel.panels
            .contributionsFor(Slots.statusbar)
            .whereType<StatusItemContribution>()
            .toList();
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
