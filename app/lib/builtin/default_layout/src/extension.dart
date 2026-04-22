import 'package:clide/clide.dart';
import 'package:clide_app/extension/extension.dart';
import 'package:clide_app/kernel/kernel.dart';

class DefaultLayoutExtension extends ClideExtension {
  @override
  String get id => 'builtin.default-layout';
  @override
  String get title => 'Default layout';
  @override
  String get version => '0.2.0';

  LayoutPresetContribution? _preset;
  ClideExtensionContext? _ctx;

  @override
  List<ContributionPoint> get contributions => [
        _preset ?? classicPreset(),
        CommandContribution(
          id: 'layout.reset',
          command: 'layout.reset',
          title: 'Layout: Reset to Classic',
          run: _reset,
        ),
        CommandContribution(
          id: 'palette.toggle',
          command: 'palette.toggle',
          title: 'Command Palette',
          defaultBinding: 'ctrl+shift+p',
          run: _togglePalette,
        ),
        // Collapse toggles (D-051, D-054)
        CommandContribution(
          id: 'sidebar.collapse',
          command: 'sidebar.collapse',
          title: 'Toggle Sidebar Collapse',
          defaultBinding: 'ctrl+shift+1',
          run: _collapseSidebar,
        ),
        CommandContribution(
          id: 'context.collapse',
          command: 'context.collapse',
          title: 'Toggle Context Panel Collapse',
          defaultBinding: 'ctrl+shift+3',
          run: _collapseContext,
        ),
        // Panel focus (D-054)
        CommandContribution(
          id: 'panel.focus.left',
          command: 'panel.focus.left',
          title: 'Focus Left Panel',
          defaultBinding: 'ctrl+1',
          run: _focusLeft,
        ),
        CommandContribution(
          id: 'panel.focus.middle',
          command: 'panel.focus.middle',
          title: 'Focus Middle Panel',
          defaultBinding: 'ctrl+2',
          run: _focusMiddle,
        ),
        CommandContribution(
          id: 'panel.focus.right',
          command: 'panel.focus.right',
          title: 'Focus Right Panel',
          defaultBinding: 'ctrl+3',
          run: _focusRight,
        ),
        // Focus mode (D-052, D-054)
        CommandContribution(
          id: 'panel.focusMode',
          command: 'panel.focusMode',
          title: 'Toggle Focus Mode',
          defaultBinding: 'ctrl+.',
          run: _toggleFocusMode,
        ),
        CommandContribution(
          id: 'panel.focusMode.exit',
          command: 'panel.focusMode.exit',
          title: 'Exit Focus Mode',
          defaultBinding: 'escape',
          run: _exitFocusMode,
        ),
        // Editor split (D-049, D-054)
        CommandContribution(
          id: 'editor.open',
          command: 'editor.open',
          title: 'Open Editor',
          defaultBinding: 'ctrl+e',
          run: _openEditor,
        ),
        CommandContribution(
          id: 'editor.close',
          command: 'editor.close',
          title: 'Close Editor',
          defaultBinding: 'ctrl+w',
          run: _closeEditor,
        ),
        // Sidebar section switching (D-054): alt+1 through alt+5
        for (var i = 0; i < 5; i++)
          CommandContribution(
            id: 'sidebar.section.${i + 1}',
            command: 'sidebar.section.${i + 1}',
            title: 'Sidebar: Section ${i + 1}',
            defaultBinding: 'alt+${i + 1}',
            run: (args) => _switchSidebarSection(i),
          ),
      ];

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _ctx = ctx;
    _preset = classicPreset();
    ctx.arrangement.registerSlotsInto(ctx.panels, _preset!);
    ctx.arrangement.applyPreset(_preset!);
  }

  Future<IpcResponse> _reset(List<String> args) async {
    final preset = _preset;
    final ctx = _ctx;
    if (preset == null || ctx == null) return _notActivated();
    ctx.arrangement.applyPreset(preset);
    return IpcResponse.ok(id: '', data: {'preset': preset.id});
  }

  Future<IpcResponse> _togglePalette(List<String> args) async {
    final ctx = _ctx;
    if (ctx == null) return _notActivated();
    ctx.palette.toggle();
    return IpcResponse.ok(id: '', data: {'open': ctx.palette.isOpen});
  }

  Future<IpcResponse> _collapseSidebar(List<String> args) async {
    final ctx = _ctx;
    if (ctx == null) return _notActivated();
    ctx.arrangement.toggleCollapsed(Slots.sidebar);
    final collapsed = ctx.arrangement.isCollapsed(Slots.sidebar);
    return IpcResponse.ok(id: '', data: {'collapsed': collapsed});
  }

  Future<IpcResponse> _collapseContext(List<String> args) async {
    final ctx = _ctx;
    if (ctx == null) return _notActivated();
    ctx.arrangement.toggleCollapsed(Slots.contextPanel);
    final collapsed = ctx.arrangement.isCollapsed(Slots.contextPanel);
    return IpcResponse.ok(id: '', data: {'collapsed': collapsed});
  }

  Future<IpcResponse> _focusLeft(List<String> args) async {
    final ctx = _ctx;
    if (ctx == null) return _notActivated();
    if (ctx.arrangement.isCollapsed(Slots.sidebar)) {
      ctx.arrangement.setCollapsed(Slots.sidebar, false);
    }
    final active = ctx.panels.activeTabIn(Slots.sidebar);
    if (active != null) {
      ctx.focus.setActive(slot: Slots.sidebar, contributionId: active);
    }
    return IpcResponse.ok(id: '', data: {'focused': 'sidebar'});
  }

  Future<IpcResponse> _focusMiddle(List<String> args) async {
    final ctx = _ctx;
    if (ctx == null) return _notActivated();
    final active = ctx.panels.activeTabIn(Slots.workspace);
    if (active != null) {
      ctx.focus.setActive(slot: Slots.workspace, contributionId: active);
    }
    return IpcResponse.ok(id: '', data: {'focused': 'workspace'});
  }

  Future<IpcResponse> _focusRight(List<String> args) async {
    final ctx = _ctx;
    if (ctx == null) return _notActivated();
    if (ctx.arrangement.isCollapsed(Slots.contextPanel)) {
      ctx.arrangement.setCollapsed(Slots.contextPanel, false);
    }
    final active = ctx.panels.activeTabIn(Slots.contextPanel);
    if (active != null) {
      ctx.focus.setActive(slot: Slots.contextPanel, contributionId: active);
    }
    return IpcResponse.ok(id: '', data: {'focused': 'context'});
  }

  Future<IpcResponse> _toggleFocusMode(List<String> args) async {
    final ctx = _ctx;
    if (ctx == null) return _notActivated();
    final activeSlot = ctx.focus.activeSlot ?? Slots.workspace;
    ctx.arrangement.toggleFocusMode(activeSlot);
    return IpcResponse.ok(id: '', data: {'focusMode': ctx.arrangement.isInFocusMode});
  }

  Future<IpcResponse> _exitFocusMode(List<String> args) async {
    final ctx = _ctx;
    if (ctx == null) return _notActivated();
    if (ctx.arrangement.isInFocusMode) {
      ctx.arrangement.exitFocusMode();
      return IpcResponse.ok(id: '', data: {'focusMode': false});
    }
    if (ctx.arrangement.editorOpen) {
      ctx.arrangement.closeEditor();
      return IpcResponse.ok(id: '', data: {'editorOpen': false});
    }
    if (ctx.palette.isOpen) {
      ctx.palette.toggle();
      return IpcResponse.ok(id: '', data: {'palette': false});
    }
    return IpcResponse.ok(id: '', data: {});
  }

  Future<IpcResponse> _openEditor(List<String> args) async {
    final ctx = _ctx;
    if (ctx == null) return _notActivated();
    ctx.arrangement.openEditor();
    return IpcResponse.ok(id: '', data: {'editorOpen': true});
  }

  Future<IpcResponse> _closeEditor(List<String> args) async {
    final ctx = _ctx;
    if (ctx == null) return _notActivated();
    if (ctx.arrangement.editorOpen) {
      ctx.arrangement.closeEditor();
      return IpcResponse.ok(id: '', data: {'editorOpen': false});
    }
    return IpcResponse.ok(id: '', data: {});
  }

  Future<IpcResponse> _switchSidebarSection(int index) async {
    final ctx = _ctx;
    if (ctx == null) return _notActivated();
    if (ctx.arrangement.isCollapsed(Slots.sidebar)) {
      ctx.arrangement.setCollapsed(Slots.sidebar, false);
    }
    final tabs = ctx.panels.tabsFor(Slots.sidebar);
    if (index < tabs.length) {
      ctx.panels.activateTab(Slots.sidebar, tabs[index].id);
      return IpcResponse.ok(id: '', data: {'section': tabs[index].id});
    }
    return IpcResponse.ok(id: '', data: {});
  }

  static IpcResponse _notActivated() => IpcResponse.err(
        id: '',
        error: IpcError(
          code: IpcExitCode.toolError,
          kind: IpcErrorKind.toolError,
          message: 'not activated',
        ),
      );
}
