/// The hat bar's project switcher: current-project label opening a
/// recents + file-actions dropdown. Split out of app.dart (T-394).
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:clide/clide.dart' show clideName;
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ProjectSwitcherButton extends StatelessWidget {
  const ProjectSwitcherButton({super.key, required this.kernel, required this.tokens});
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
              ClideText(
                label,
                fontSize: 12,
                color: hovered ? tokens.globalForeground : tokens.chromeForeground,
                fontFamily: ClideSettings.fonts.monoOf(context),
              ),
              const SizedBox(width: 4),
              ClideIcon(PhosphorIcons.byName('caret-down'), size: 8, color: tokens.chromeForeground),
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
    final tokens = ClideSettings.theme.of(context).surface;
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
                  itemBuilder: (ctx, i) => _RecentProjectRow(project: filtered[i], tokens: tokens, onTap: () => _openProject(filtered[i].path)),
                ),
              ),
            ] else
              const Padding(padding: EdgeInsets.all(12), child: ClideText('No recent projects.', muted: true)),
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: tokens.dividerColor)),
              ),
              child: Column(
                children: [
                  _ActionRow(
                    label: 'Open Local Project',
                    shortcut: Platform.isMacOS ? '⌘O' : 'Ctrl+O',
                    tokens: tokens,
                    onTap: () => _runFileCommand('file.openFolder'),
                  ),
                  _ActionRow(
                    label: 'New Window',
                    shortcut: Platform.isMacOS ? '⌘⇧N' : 'Ctrl+Shift+N',
                    tokens: tokens,
                    onTap: () => _runFileCommand('file.newWindow'),
                  ),
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
            ClideIcon(PhosphorIcons.byName('folder'), size: 14, color: tokens.globalTextMuted),
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
                          child: ClideText(
                            project.relativePath,
                            muted: true,
                            fontSize: 12,
                            fontFamily: ClideSettings.fonts.monoOf(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ClideText('  ·  ', muted: true, fontSize: 12),
                        ClideIcon(PhosphorIcons.byName('git-branch'), size: 10, color: tokens.globalTextMuted),
                        const SizedBox(width: 3),
                        ClideText(project.branch!, muted: true, fontSize: 12, fontFamily: ClideSettings.fonts.monoOf(context)),
                      ],
                    )
                  else
                    ClideText(
                      project.relativePath,
                      muted: true,
                      fontSize: 12,
                      fontFamily: ClideSettings.fonts.monoOf(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
              ClideText(shortcut!, fontSize: 12, color: tokens.globalTextMuted, fontFamily: ClideSettings.fonts.monoOf(context)),
          ],
        ),
      ),
    );
  }
}
