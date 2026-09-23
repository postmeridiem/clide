/// Settings control for the agent spawn allowlist (D-115): the commands a
/// Claude session may start in a pane without the in-app confirm.
///
/// Stored at [kSpawnAllowKey], an app-scope key — a repo's settings can never
/// supply or extend it. Entries are matched word for word against the argv
/// an agent asks to run ([spawnAllowlisted]); a trailing `*` allows further
/// arguments.
library;

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// App-scope settings key holding the allowlist (a list of strings).
const String kSpawnAllowKey = 'app.agent.spawnAllow';

const _ns = 'builtin.claude';

/// The allowlist as stored; non-strings are ignored.
List<String> readSpawnAllow(SettingsStore settings) => [...?settings.get<List>(kSpawnAllowKey)?.whereType<String>()];

class SpawnAllowControl extends StatefulWidget {
  const SpawnAllowControl({super.key});

  @override
  State<SpawnAllowControl> createState() => _SpawnAllowControlState();
}

class _SpawnAllowControlState extends State<SpawnAllowControl> {
  final TextEditingController _entry = TextEditingController();
  final FocusNode _focus = FocusNode(debugLabel: 'add-spawn-allow');
  SettingsStore? _settings;

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

  Future<void> _add(SettingsStore settings) async {
    // Collapse runs of whitespace: entries match word for word.
    final entry = _entry.text.trim().split(RegExp(r'\s+')).join(' ');
    _entry.clear();
    final current = readSpawnAllow(settings);
    if (entry.isEmpty || entry == '*' || current.contains(entry)) return;
    await settings.set<List<String>>(kSpawnAllowKey, [...current, entry]);
  }

  Future<void> _remove(SettingsStore settings, String entry) => settings.set<List<String>>(kSpawnAllowKey, [
    for (final e in readSpawnAllow(settings))
      if (e != entry) e,
  ]);

  String _s(String key, String placeholder) => ClideSettings.i18n.string(context, key, namespace: _ns, placeholder: placeholder);

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (settings == null) return const SizedBox.shrink();
    final tokens = ClideSettings.theme.of(context).surface;
    final entries = readSpawnAllow(settings);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (entries.isEmpty)
          ClideText(
            _s('settings.claude.spawnAllow.empty', 'None yet — every command an agent starts asks you first.'),
            fontSize: clideFontCaption,
            color: tokens.globalTextMuted,
          )
        else
          for (final e in entries) _row(context, settings, tokens, e),
        const SizedBox(height: 10),
        _addRow(context, settings, tokens),
      ],
    );
  }

  Widget _row(BuildContext context, SettingsStore settings, SurfaceTokens tokens, String entry) {
    final label =
        ClideKernel.maybeOf(context)?.i18n.interpolated(
          'settings.claude.spawnAllow.remove',
          namespace: _ns,
          placeholder: 'Remove {command}',
          replacers: [I18nReplacer(from: '{command}', replace: entry)],
        ) ??
        'Remove $entry';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: ClideText(entry, fontFamily: ClideSettings.fonts.monoOf(context), color: tokens.globalForeground, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: label,
            excludeSemantics: true,
            child: ClideTappable(
              cursor: SystemMouseCursors.click,
              onTap: () => _remove(settings, entry),
              builder: (ctx, hovered, _) => ClideIcon(PhosphorIcons.byName('trash'), size: 14, color: hovered ? tokens.statusError : tokens.globalTextMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addRow(BuildContext context, SettingsStore settings, SurfaceTokens tokens) {
    final addLabel = _s('settings.claude.spawnAllow.add', 'Add command');
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
            child: ClideEditable(
              controller: _entry,
              focusNode: _focus,
              style: TextStyle(fontFamily: ClideSettings.fonts.monoOf(context), fontSize: clideFontMono, color: tokens.globalForeground),
              cursorColor: tokens.globalFocus,
              backgroundCursorColor: tokens.globalTextMuted,
              maxLines: 1,
              onSubmitted: (_) => _add(settings),
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
            onTap: () => _add(settings),
            builder: (ctx, hovered, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: hovered ? tokens.listItemHoverBackground : tokens.buttonBackground, borderRadius: BorderRadius.circular(4)),
              child: ClideText(addLabel, color: tokens.buttonForeground, fontSize: clideFontCaption),
            ),
          ),
        ),
      ],
    );
  }
}
