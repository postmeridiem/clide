import 'dart:async';
import 'dart:io' show Platform, Process, ProcessStartMode;

import 'package:clide/builtin/welcome/src/welcome_view.dart';
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
  double _textScale = 1.0;

  static const double _scaleStep = 0.05;
  static const double _scaleMin = 0.6;
  static const double _scaleMax = 2.0;

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
        height: clideLineHeight,
        fontWeight: clideUiDefaultWeight,
        fontFamily: clideUiFamily,
        fontFamilyFallback: clideUiFamilyFallback,
      ),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(_textScale)),
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
                _HatBar(kernel: widget.services),
                Expanded(
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
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  void _onKey(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final ctrl = HardwareKeyboard.instance.isControlPressed;
      if (ctrl) {
        if (event.logicalKey == LogicalKeyboardKey.equal || event.logicalKey == LogicalKeyboardKey.add) {
          setState(() => _textScale = (_textScale + _scaleStep).clamp(_scaleMin, _scaleMax));
          return;
        }
        if (event.logicalKey == LogicalKeyboardKey.minus) {
          setState(() => _textScale = (_textScale - _scaleStep).clamp(_scaleMin, _scaleMax));
          return;
        }
        if (event.logicalKey == LogicalKeyboardKey.digit0) {
          setState(() => _textScale = 1.0);
          return;
        }
      }
    }
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
        final sidebarSize = a.sizeOf(Slots.sidebar) ?? 400;
        final contextSize = a.sizeOf(Slots.contextPanel) ?? 420;
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

class _HatBar extends StatelessWidget {
  const _HatBar({required this.kernel});
  final KernelServices kernel;

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

class _TrafficDot extends StatelessWidget {
  const _TrafficDot({required this.color, required this.onTap});
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClideTappable(
      onTap: onTap,
      builder: (context, hovered, _) => Container(
        width: 12, height: 12,
        decoration: BoxDecoration(color: hovered ? color : color.withAlpha(0xCC), shape: BoxShape.circle),
      ),
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
    final hoverBg = isClose ? const Color(0xFFE81123) : tokens.listItemHoverBackground;
    return ClideTappable(
      onTap: onTap,
      builder: (context, hovered, _) => Container(
        width: 36, height: hatHeight,
        color: hovered ? hoverBg : null,
        alignment: Alignment.center,
        child: ClideIcon(icon, size: 14, color: hovered && isClose ? const Color(0xFFFFFFFF) : tokens.chromeForeground),
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
        final label = name != null ? 'clide > $name' : 'clide';
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

  void _closeWorkspace() {
    widget.kernel.project.close();
    widget.onDismiss();
  }

  void _newWindow() {
    Process.start(Platform.resolvedExecutable, [], mode: ProcessStartMode.detached);
    widget.onDismiss();
  }

  void _openFolder() async {
    widget.onDismiss();

    try {
      final picked = await widget.kernel.window.pickDirectory();
      if (picked != null) {
        final ok = await widget.kernel.project.open(picked);
        if (ok) {
          widget.kernel.panels.activateTab(Slots.workspace, 'claude.primary');
        } else {
          widget.kernel.dialog.show((ctx, dismiss) => _NotARepoDialog(
            path: picked,
            onDismiss: () => dismiss(),
          ));
        }
      }
      return;
    } on MissingPluginException {
      // Fall through to text dialog.
    }

    widget.kernel.dialog.show<String>((ctx, dismiss) {
      return _OpenFolderDialog(
        onOpen: (path) async {
          final ok = await widget.kernel.project.open(path);
          if (ok) {
            widget.kernel.panels.activateTab(Slots.workspace, 'claude.primary');
            dismiss(path);
          }
        },
        onCancel: () => dismiss(),
      );
    });
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
        width: 380,
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
                  _ActionRow(label: 'Open Local Project', shortcut: 'Ctrl+O', tokens: tokens, onTap: _openFolder),
                  _ActionRow(label: 'New Window', shortcut: 'Ctrl+Shift+N', tokens: tokens, onTap: _newWindow),
                  if (widget.kernel.project.isOpen)
                    _ActionRow(label: 'Close Workspace', shortcut: '', tokens: tokens, onTap: _closeWorkspace),
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
                        ClideText(project.relativePath, muted: true, fontSize: 12, fontFamily: clideMonoFamily),
                        ClideText('  ·  ', muted: true, fontSize: 12),
                        ClideIcon(PhosphorIcons.gitBranch, size: 10, color: tokens.globalTextMuted),
                        const SizedBox(width: 3),
                        ClideText(project.branch!, muted: true, fontSize: 12, fontFamily: clideMonoFamily),
                      ],
                    )
                  else
                    ClideText(project.relativePath, muted: true, fontSize: 12, fontFamily: clideMonoFamily),
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
            if (shortcut != null && shortcut!.isNotEmpty)
              ClideText(shortcut!, fontSize: 12, color: tokens.globalTextMuted, fontFamily: clideMonoFamily),
          ],
        ),
      ),
    );
  }
}

class _OpenFolderDialog extends StatefulWidget {
  const _OpenFolderDialog({required this.onOpen, required this.onCancel});
  final Future<void> Function(String path) onOpen;
  final VoidCallback onCancel;

  @override
  State<_OpenFolderDialog> createState() => _OpenFolderDialogState();
}

class _OpenFolderDialogState extends State<_OpenFolderDialog> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final path = _controller.text.trim();
    if (path.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await widget.onOpen(path);
    } catch (_) {
      if (mounted) setState(() => _error = 'Not a git repository');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Container(
      width: 420,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.modalSurfaceBackground,
        border: Border.all(color: tokens.modalSurfaceBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ClideText('Open project', fontSize: 16, fontWeight: FontWeight.w600),
          const SizedBox(height: 4),
          const ClideText('Enter the path to a git repository.', muted: true, fontSize: 13),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: tokens.panelBackground,
              border: Border.all(color: tokens.globalBorder),
              borderRadius: BorderRadius.circular(4),
            ),
            child: EditableText(
              controller: _controller,
              focusNode: _focus,
              style: TextStyle(color: tokens.globalForeground, fontSize: 14, fontFamily: clideMonoFamily, fontFamilyFallback: clideMonoFamilyFallback),
              cursorColor: tokens.globalForeground,
              backgroundCursorColor: tokens.globalTextMuted,
              onSubmitted: (_) => unawaited(_submit()),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            ClideText(_error!, color: tokens.statusError, fontSize: 12),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ClideButton(label: 'Cancel', onPressed: widget.onCancel),
              const SizedBox(width: 8),
              ClideButton(label: _loading ? 'Opening…' : 'Open', onPressed: _loading ? null : _submit),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotARepoDialog extends StatelessWidget {
  const _NotARepoDialog({required this.path, required this.onDismiss});
  final String path;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Container(
      width: 420,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.modalSurfaceBackground,
        border: Border.all(color: tokens.modalSurfaceBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ClideText('No git repo found', fontSize: 16, fontWeight: FontWeight.w600),
          const SizedBox(height: 8),
          ClideText(path, muted: true, fontSize: 13),
          const SizedBox(height: 8),
          const ClideText(
            'A clide project root requires a git repository.',
            muted: true,
            fontSize: 13,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ClideButton(label: 'OK', onPressed: () => onDismiss()),
            ],
          ),
        ],
      ),
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
      color: tokens.chromeBackground,
      alignment: Alignment.topLeft,
      padding: const EdgeInsets.fromLTRB(2, 2, 0, 0),
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
          color: tokens.chromeBackground,
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
