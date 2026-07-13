import 'dart:io' show Directory, Platform;

import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/daemon/env_path_commands.dart' show envPathChannel;
import 'package:clide/src/env/path_preset.dart';
import 'package:clide/src/env/shell_env.dart' show loginShellPathOrNull;
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

const _ns = 'builtin.tools-settings';

String _s(BuildContext context, String key, String placeholder) => ClideSettings.i18n.string(context, key, namespace: _ns, placeholder: placeholder);

/// Settings control for the per-workspace PATH preset (D-106, T-511): an
/// ordered list of directories prepended to the PATH of everything clide
/// spawns for this repo — hosted Claude sessions and terminal panes alike.
///
/// The preset keys off the REPO identity ([presetRootFor]): opened from a
/// linked worktree (e.g. `.worktrees/<name>`) the control edits the main
/// repo's preset and says so. Writes go to the user-scope settings key the
/// `clide env path` verbs use, published on [envPathChannel] (D-6 parity);
/// the store notifier keeps this control live for CLI edits.
class PathPresetControl extends StatefulWidget {
  const PathPresetControl({super.key});

  @override
  State<PathPresetControl> createState() => _PathPresetControlState();
}

class _PathPresetControlState extends State<PathPresetControl> {
  final TextEditingController _entry = TextEditingController();
  final FocusNode _focus = FocusNode(debugLabel: 'add-path-entry');
  SettingsStore? _settings;

  /// Capture-from-login-shell results; null until the button is pressed.
  List<String>? _suggestions;
  bool _addRejected = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = ClideKernel.maybeOf(context)?.settings;
    if (identical(settings, _settings)) return;
    _settings?.removeListener(_onChange);
    _settings = settings;
    _settings?.addListener(_onChange);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _settings?.removeListener(_onChange);
    _entry.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<String> _dirs(KernelServices services, String cwd) => presetDirsFrom((k) => services.settings.get<Object>(k), cwd);

  Future<void> _write(KernelServices services, String cwd, List<String> dirs, String action) async {
    final key = pathPresetKey(cwd);
    final write = dirs.isEmpty ? services.settings.removeAt(SettingsScope.app, key) : services.settings.setAt(SettingsScope.app, key, dirs);
    services.messages.publish('ui', envPathChannel, {'action': action, 'root': presetRootFor(cwd), 'dirs': dirs});
    await write;
  }

  /// Expand a leading `~/`, require an absolute path (mirrors the `env path`
  /// verb's guard), strip trailing slashes. Null = rejected.
  String? _normalizeEntry(String raw) {
    var d = raw.trim();
    if (d == '~' || d.startsWith('~/')) {
      final home = Platform.environment['HOME'];
      if (home == null || home.isEmpty) return null;
      d = d == '~' ? home : '$home${d.substring(1)}';
    }
    if (d.isEmpty || !(d.startsWith('/') || RegExp(r'^[A-Za-z]:[/\\]').hasMatch(d))) return null;
    // One dir per entry — an embedded PATH separator would smuggle extra
    // (possibly empty → CWD) tokens into the joined PATH.
    final body = RegExp(r'^[A-Za-z]:').hasMatch(d) ? d.substring(2) : d;
    if (body.contains(':') || body.contains(';')) return null;
    while (d.length > 1 && d.endsWith('/')) {
      d = d.substring(0, d.length - 1);
    }
    return d;
  }

  Future<void> _add(KernelServices services, String cwd, [String? suggestion]) async {
    final raw = suggestion ?? _entry.text;
    if (raw.trim().isEmpty) return;
    final d = _normalizeEntry(raw);
    if (d == null) {
      setState(() => _addRejected = true);
      return;
    }
    final dirs = _dirs(services, cwd);
    if (suggestion == null) _entry.clear();
    setState(() {
      _addRejected = false;
      _suggestions?.remove(raw);
      _suggestions?.remove(d);
    });
    if (dirs.contains(d)) return;
    await _write(services, cwd, [...dirs, d], 'add');
  }

  Future<void> _move(KernelServices services, String cwd, int index, int delta) async {
    final dirs = _dirs(services, cwd);
    final to = index + delta;
    if (to < 0 || to >= dirs.length) return;
    final out = [...dirs];
    final d = out.removeAt(index);
    out.insert(to, d);
    await _write(services, cwd, out, 'set');
  }

  Future<void> _remove(KernelServices services, String cwd, String dir) async {
    final kept = _dirs(services, cwd).where((d) => d != dir).toList();
    await _write(services, cwd, kept, 'remove');
  }

  void _capture(List<String> current) {
    final missing = missingLoginShellDirs(loginPath: loginShellPathOrNull(), processPath: Platform.environment['PATH'] ?? '');
    setState(() => _suggestions = missing.where((d) => !current.contains(d)).toList());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final services = ClideKernel.maybeOf(context);
    final cwd = services?.settings.projectDir?.path;
    if (services == null || cwd == null) {
      return ClideText(_s(context, 'path.noWorkspace', 'Open a workspace to set its PATH preset.'), fontSize: clideFontCaption, color: tokens.globalTextMuted);
    }

    final root = presetRootFor(cwd);
    final dirs = _dirs(services, cwd);
    final suggestions = _suggestions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (root != cwd)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                ClideText(_s(context, 'path.sharedRoot', 'Worktree — preset shared with'), fontSize: clideFontCaption, color: tokens.globalTextMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: ClideText(
                    root,
                    fontSize: clideFontCaption,
                    muted: true,
                    fontFamily: ClideSettings.fonts.monoOf(context),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        if (dirs.isEmpty)
          ClideText(
            _s(context, 'path.empty', 'No preset entries — spawned shells get the resolved login-shell PATH as-is.'),
            fontSize: clideFontCaption,
            color: tokens.globalTextMuted,
          )
        else
          for (var i = 0; i < dirs.length; i++) _row(context, services, cwd, tokens, dirs, i),
        const SizedBox(height: 10),
        _addRow(context, services, cwd, tokens),
        if (_addRejected)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: ClideText(_s(context, 'path.invalid', 'Enter an absolute path (or ~/…).'), fontSize: clideFontCaption, color: tokens.statusError),
          ),
        const SizedBox(height: 10),
        _captureButton(context, tokens, dirs),
        if (suggestions != null && suggestions.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ClideText(
              _s(context, 'path.captureNone', 'Nothing to suggest — the login-shell PATH is already covered.'),
              fontSize: clideFontCaption,
              color: tokens.globalTextMuted,
            ),
          ),
        if (suggestions != null)
          for (final d in suggestions) _suggestionRow(context, services, cwd, tokens, d),
      ],
    );
  }

  Widget _row(BuildContext context, KernelServices services, String cwd, SurfaceTokens tokens, List<String> dirs, int index) {
    final dir = dirs[index];
    final exists = Directory(dir).existsSync();
    final removeLabel = _s(context, 'path.remove', 'Remove');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: ClideText(
              dir,
              fontSize: clideFontMono,
              fontFamily: ClideSettings.fonts.monoOf(context),
              color: exists ? tokens.globalForeground : tokens.statusWarning,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!exists) ...[
            const SizedBox(width: 6),
            ClideText(_s(context, 'path.missing', 'missing'), fontSize: clideFontCaption, color: tokens.statusWarning),
          ],
          const SizedBox(width: 8),
          _iconButton(context, 'arrow-up', '${_s(context, 'path.moveUp', 'Move up')}: $dir', index == 0 ? null : () => _move(services, cwd, index, -1)),
          const SizedBox(width: 6),
          _iconButton(
            context,
            'arrow-down',
            '${_s(context, 'path.moveDown', 'Move down')}: $dir',
            index == dirs.length - 1 ? null : () => _move(services, cwd, index, 1),
          ),
          const SizedBox(width: 6),
          _iconButton(context, 'trash', '$removeLabel: $dir', () => _remove(services, cwd, dir), color: tokens.statusError),
        ],
      ),
    );
  }

  Widget _suggestionRow(BuildContext context, KernelServices services, String cwd, SurfaceTokens tokens, String dir) {
    final addLabel = _s(context, 'path.addSuggestion', 'Add suggested entry');
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          _iconButton(context, 'plus-circle', '$addLabel: $dir', () => _add(services, cwd, dir), color: tokens.statusSuccess),
          const SizedBox(width: 8),
          Expanded(
            child: ClideText(dir, fontSize: clideFontMono, fontFamily: ClideSettings.fonts.monoOf(context), muted: true, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _iconButton(BuildContext context, String icon, String semantic, VoidCallback? onTap, {Color? color}) {
    final tokens = ClideSettings.theme.of(context).surface;
    final enabledColor = color ?? tokens.globalForeground;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semantic,
      excludeSemantics: true,
      child: ClideTappable(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onTap: onTap,
        builder: (ctx, hovered, _) =>
            ClideIcon(PhosphorIcons.byName(icon), size: 14, color: onTap == null ? tokens.globalTextMuted : (hovered ? enabledColor : tokens.globalTextMuted)),
      ),
    );
  }

  Widget _addRow(BuildContext context, KernelServices services, String cwd, SurfaceTokens tokens) {
    final addLabel = _s(context, 'path.add', 'Add entry');
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 26,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: tokens.panelBackground,
              border: Border.all(color: _focus.hasFocus ? tokens.panelActiveBorder : tokens.dividerColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: EditableText(
              controller: _entry,
              focusNode: _focus,
              style: TextStyle(fontFamily: ClideSettings.fonts.monoOf(context), fontSize: clideFontMono, color: tokens.globalForeground),
              cursorColor: tokens.globalFocus,
              backgroundCursorColor: tokens.globalTextMuted,
              maxLines: 1,
              onSubmitted: (_) => _add(services, cwd),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: addLabel,
          excludeSemantics: true,
          child: ClideTappable(
            cursor: SystemMouseCursors.click,
            onTap: () => _add(services, cwd),
            builder: (ctx, hovered, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: hovered ? tokens.buttonHoverBackground : tokens.buttonBackground, borderRadius: BorderRadius.circular(4)),
              child: ClideText(addLabel, color: tokens.buttonForeground, fontSize: clideFontCaption),
            ),
          ),
        ),
      ],
    );
  }

  Widget _captureButton(BuildContext context, SurfaceTokens tokens, List<String> dirs) {
    final label = _s(context, 'path.capture', 'Suggest from login shell');
    return Row(
      children: [
        Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: ClideTappable(
            cursor: SystemMouseCursors.click,
            onTap: () => _capture(dirs),
            builder: (ctx, hovered, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: hovered ? tokens.listItemHoverBackground : tokens.panelBackground,
                border: Border.all(color: tokens.dividerColor),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ClideText(label, color: tokens.globalForeground, fontSize: clideFontCaption),
            ),
          ),
        ),
      ],
    );
  }
}
