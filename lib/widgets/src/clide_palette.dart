import 'package:clide/extension/src/contribution.dart' show CommandContribution;
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/src/clide_settings.dart';
import 'package:clide/widgets/src/clide_text.dart';
import 'package:clide/widgets/src/typography.dart';
import 'package:flutter/widgets.dart';

/// The localized display title for a command (T-462): resolves [titleKey] in
/// [i18nNamespace] when both are set, else the English title (then id). Shared
/// by the command palette and the menu bar so both localize identically.
String localizedCommandTitle(BuildContext context, CommandContribution cmd) {
  final k = cmd.titleKey;
  final ns = cmd.i18nNamespace;
  if (k != null && ns != null) {
    return ClideSettings.i18n.string(context, k, namespace: ns, placeholder: cmd.title ?? cmd.command);
  }
  return cmd.title ?? cmd.command;
}

class ClidePalette extends StatefulWidget {
  const ClidePalette({super.key});

  @override
  State<ClidePalette> createState() => _ClidePaletteState();
}

class _ClidePaletteState extends State<ClidePalette> {
  final _input = TextEditingController();
  final _focus = FocusNode(debugLabel: 'ClidePalette.input');
  final _itemKeys = <int, GlobalKey>{};

  PaletteController? _palette;
  KeymapService? _keymap;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final kernel = ClideKernel.of(context);
    if (!identical(_palette, kernel.palette)) {
      _palette?.removeListener(_onPaletteChanged);
      _palette = kernel.palette;
      _palette!.addListener(_onPaletteChanged);
      _syncFromController();
    }
    _keymap = kernel.keymap;
    // Sync the initial state: if the palette was opened before this
    // widget mounted (e.g., open()-then-pumpWidget in a test), no
    // listener fires for the "already open" condition. Mirror what
    // _onPaletteChanged would have done.
    final isOpen = _palette?.isOpen ?? false;
    _keymap?.setScopeFlag('palette.open', isOpen);
    if (isOpen && !_focus.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (_palette?.isOpen ?? false)) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _palette?.removeListener(_onPaletteChanged);
    _keymap?.clearScopeFlag('palette.open');
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onPaletteChanged() {
    final isOpen = _palette?.isOpen ?? false;
    _keymap?.setScopeFlag('palette.open', isOpen);
    if (isOpen) _focus.requestFocus();
    _syncFromController();
  }

  void _syncFromController() {
    final f = _palette?.filter ?? '';
    if (_input.text != f) {
      _input.value = TextEditingValue(
        text: f,
        selection: TextSelection.collapsed(offset: f.length),
      );
    }
  }

  Object? _selectNext(PaletteSelectNextIntent _) {
    _palette?.selectNext();
    _scrollSelectedIntoView();
    return null;
  }

  Object? _selectPrev(PaletteSelectPreviousIntent _) {
    _palette?.selectPrevious();
    _scrollSelectedIntoView();
    return null;
  }

  Object? _accept(PaletteAcceptIntent _) {
    _palette?.acceptSelected();
    _input.clear();
    return null;
  }

  Object? _dismiss(DismissIntent _) {
    _palette?.close();
    return null;
  }

  void _scrollSelectedIntoView() {
    final idx = _palette?.selectedIndex;
    if (idx == null) return;
    final key = _itemKeys[idx];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 120), alignment: 0.5);
  }

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideSettings.theme.of(context).surface;
    return ListenableBuilder(
      listenable: kernel.palette,
      builder: (ctx, _) {
        if (!kernel.palette.isOpen) return const SizedBox.shrink();
        // Localize titles for both the fuzzy filter and the rendered rows (T-462).
        kernel.palette.titleResolver = (cmd) => localizedCommandTitle(ctx, cmd);
        final filtered = kernel.palette.filtered();
        final selected = kernel.palette.selectedIndex;
        return Positioned(
          top: 60,
          left: 0,
          right: 0,
          child: Center(
            child: Actions(
              actions: <Type, Action<Intent>>{
                PaletteSelectNextIntent: CallbackAction<PaletteSelectNextIntent>(onInvoke: _selectNext),
                PaletteSelectPreviousIntent: CallbackAction<PaletteSelectPreviousIntent>(onInvoke: _selectPrev),
                PaletteAcceptIntent: CallbackAction<PaletteAcceptIntent>(onInvoke: _accept),
                DismissIntent: CallbackAction<DismissIntent>(onInvoke: _dismiss),
              },
              child: Container(
                width: 480,
                constraints: const BoxConstraints(maxHeight: 360),
                decoration: BoxDecoration(
                  color: tokens.dropdownBackground,
                  border: Border.all(color: tokens.dropdownBorder),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [BoxShadow(color: tokens.shadowAmbient, blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: EditableText(
                        controller: _input,
                        focusNode: _focus,
                        style: TextStyle(fontFamily: ClideSettings.fonts.monoOf(context), fontSize: clideFontMono, color: tokens.dropdownForeground),
                        cursorColor: tokens.globalFocus,
                        backgroundCursorColor: tokens.globalFocus,
                        maxLines: 1,
                        onChanged: (v) => kernel.palette.setFilter(v),
                        // Enter on the input forwards to the palette
                        // accept intent — keeps the legacy single-key
                        // submit working alongside arrow-driven nav.
                        onSubmitted: (_) {
                          kernel.palette.acceptSelected();
                          _input.clear();
                        },
                      ),
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final cmd = filtered[i];
                          final key = _itemKeys.putIfAbsent(i, () => GlobalKey());
                          return _PaletteItem(
                            key: key,
                            title: localizedCommandTitle(ctx, cmd),
                            command: cmd.command,
                            binding: cmd.defaultBinding,
                            highlighted: i == selected,
                            onTap: () {
                              kernel.palette.invoke(cmd.command);
                              _input.clear();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PaletteItem extends StatefulWidget {
  const _PaletteItem({super.key, required this.title, required this.command, required this.onTap, required this.highlighted, this.binding});

  final String title;
  final String command;
  final String? binding;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  State<_PaletteItem> createState() => _PaletteItemState();
}

class _PaletteItemState extends State<_PaletteItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final selected = widget.highlighted;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: selected
              ? tokens.listItemSelectedBackground
              : _hover
              ? tokens.listItemHoverBackground
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(child: ClideText(widget.title, color: selected ? tokens.listItemSelectedForeground : tokens.listItemForeground)),
              if (widget.binding != null)
                ClideText(widget.binding!, fontSize: clideFontCaption, fontFamily: ClideSettings.fonts.monoOf(context), color: tokens.globalTextMuted),
            ],
          ),
        ),
      ),
    );
  }
}
