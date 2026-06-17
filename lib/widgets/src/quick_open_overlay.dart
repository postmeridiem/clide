import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/src/clide_settings.dart';
import 'package:clide/widgets/src/clide_text.dart';
import 'package:clide/widgets/src/typography.dart';
import 'package:flutter/widgets.dart';

/// Quick-open file finder overlay (T-51). A fuzzy file picker, distinct
/// from the command palette: it loads the workspace file list via
/// `files.walk`, filters with a subsequence fuzzy match, shows recents
/// when the query is empty, and opens the selection via
/// [openWorkspaceFile] (`.md` → markdown reader, else editor).
///
/// Mirrors `ClidePalette`'s structure and keymap-driven navigation —
/// the overlay publishes the `quickOpen.open` scope flag and binds the
/// `quickOpen.*` intents while open.
class QuickOpenOverlay extends StatefulWidget {
  const QuickOpenOverlay({super.key});

  @override
  State<QuickOpenOverlay> createState() => _QuickOpenOverlayState();
}

class _QuickOpenOverlayState extends State<QuickOpenOverlay> {
  final _input = TextEditingController();
  final _focus = FocusNode(debugLabel: 'QuickOpenOverlay.input');
  final _itemKeys = <int, GlobalKey>{};

  QuickOpenController? _quickOpen;
  KeymapService? _keymap;
  KernelServices? _services;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final kernel = ClideKernel.of(context);
    _services = kernel;
    if (!identical(_quickOpen, kernel.quickOpen)) {
      _quickOpen?.removeListener(_onChanged);
      _quickOpen = kernel.quickOpen;
      _quickOpen!.addListener(_onChanged);
      _syncFromController();
    }
    _keymap = kernel.keymap;
    final isOpen = _quickOpen?.isOpen ?? false;
    _keymap?.setScopeFlag('quickOpen.open', isOpen);
    if (isOpen) {
      _ensureFilesLoaded();
      if (!_focus.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && (_quickOpen?.isOpen ?? false)) _focus.requestFocus();
        });
      }
    }
  }

  @override
  void dispose() {
    _quickOpen?.removeListener(_onChanged);
    _keymap?.clearScopeFlag('quickOpen.open');
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool _loadedForThisOpen = false;

  void _onChanged() {
    final isOpen = _quickOpen?.isOpen ?? false;
    _keymap?.setScopeFlag('quickOpen.open', isOpen);
    if (isOpen) {
      _ensureFilesLoaded();
      _focus.requestFocus();
    } else {
      _loadedForThisOpen = false;
    }
    _syncFromController();
  }

  void _syncFromController() {
    final f = _quickOpen?.filter ?? '';
    if (_input.text != f) {
      _input.value = TextEditingValue(
        text: f,
        selection: TextSelection.collapsed(offset: f.length),
      );
    }
  }

  /// Fetch the workspace file list once per open via `files.walk`.
  Future<void> _ensureFilesLoaded() async {
    if (_loadedForThisOpen) return;
    _loadedForThisOpen = true;
    final services = _services;
    final controller = _quickOpen;
    if (services == null || controller == null) return;
    controller.setLoading(true);
    try {
      final res = await services.ipc.request('files.walk', args: const {});
      if (!res.ok || !controller.isOpen) return;
      final raw = res.data['files'];
      final files = raw is List ? raw.map((e) => '$e').toList() : <String>[];
      controller.setFiles(files, truncated: res.data['truncated'] == true);
    } catch (_) {
      // Leave the list empty; recents still show on empty query.
    } finally {
      controller.setLoading(false);
    }
  }

  Object? _selectNext(QuickOpenSelectNextIntent _) {
    _quickOpen?.selectNext();
    _scrollSelectedIntoView();
    return null;
  }

  Object? _selectPrev(QuickOpenSelectPreviousIntent _) {
    _quickOpen?.selectPrevious();
    _scrollSelectedIntoView();
    return null;
  }

  Object? _accept(QuickOpenAcceptIntent _) {
    _openSelected();
    return null;
  }

  Object? _dismiss(DismissIntent _) {
    _quickOpen?.close();
    return null;
  }

  void _openSelected() {
    final controller = _quickOpen;
    final services = _services;
    if (controller == null || services == null) return;
    final path = controller.selectedPath;
    controller.close();
    _input.clear();
    if (path != null) openWorkspaceFile(services, path);
  }

  void _scrollSelectedIntoView() {
    final idx = _quickOpen?.selectedIndex;
    if (idx == null) return;
    final ctx = _itemKeys[idx]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 120), alignment: 0.5);
  }

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideTheme.of(context).surface;
    return ListenableBuilder(
      listenable: kernel.quickOpen,
      builder: (ctx, _) {
        final controller = kernel.quickOpen;
        if (!controller.isOpen) return const SizedBox.shrink();
        final results = controller.filtered();
        final selected = controller.selectedIndex;
        final emptyQuery = controller.filter.trim().isEmpty;
        return Positioned(
          top: 60,
          left: 0,
          right: 0,
          child: Center(
            child: Actions(
              actions: <Type, Action<Intent>>{
                QuickOpenSelectNextIntent: CallbackAction<QuickOpenSelectNextIntent>(onInvoke: _selectNext),
                QuickOpenSelectPreviousIntent: CallbackAction<QuickOpenSelectPreviousIntent>(onInvoke: _selectPrev),
                QuickOpenAcceptIntent: CallbackAction<QuickOpenAcceptIntent>(onInvoke: _accept),
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
                        onChanged: controller.setFilter,
                        onSubmitted: (_) => _openSelected(),
                      ),
                    ),
                    if (emptyQuery && results.isEmpty)
                      _Hint(controller.isLoading ? 'Loading files…' : 'No recent files', tokens)
                    else if (results.isEmpty)
                      _Hint('No matching files', tokens)
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: results.length,
                          itemBuilder: (ctx, i) {
                            final path = results[i];
                            final key = _itemKeys.putIfAbsent(i, () => GlobalKey());
                            return _QuickOpenItem(
                              key: key,
                              path: path,
                              highlighted: i == selected,
                              onTap: () {
                                controller.close();
                                _input.clear();
                                openWorkspaceFile(kernel, path);
                              },
                            );
                          },
                        ),
                      ),
                    if (controller.truncated) _Hint('Results limited — large workspace', tokens),
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

class _Hint extends StatelessWidget {
  const _Hint(this.text, this.tokens);
  final String text;
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: ClideText(text, fontSize: clideFontCaption, color: tokens.globalTextMuted),
  );
}

class _QuickOpenItem extends StatefulWidget {
  const _QuickOpenItem({super.key, required this.path, required this.highlighted, required this.onTap});

  final String path;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  State<_QuickOpenItem> createState() => _QuickOpenItemState();
}

class _QuickOpenItemState extends State<_QuickOpenItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final selected = widget.highlighted;
    // Split the basename from its directory so the filename reads first.
    final slash = widget.path.lastIndexOf('/');
    final name = slash < 0 ? widget.path : widget.path.substring(slash + 1);
    final dir = slash < 0 ? '' : widget.path.substring(0, slash);
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
              ClideText(name, color: selected ? tokens.listItemSelectedForeground : tokens.listItemForeground),
              const SizedBox(width: 8),
              Expanded(
                child: ClideText(
                  dir,
                  fontSize: clideFontCaption,
                  fontFamily: ClideSettings.fonts.monoOf(context),
                  color: tokens.globalTextMuted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
