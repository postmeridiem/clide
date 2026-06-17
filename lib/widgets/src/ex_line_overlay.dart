import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/src/clide_settings.dart';
import 'package:clide/widgets/src/clide_text.dart';
import 'package:clide/widgets/src/typography.dart';
import 'package:flutter/widgets.dart';

/// The Vim ex command-line overlay (T-407): a transient one-line `:` prompt
/// that runs the fixed v1 command table ([parseExCommand]). Modeled on the
/// quick-open chrome but single-line and result-less.
///
/// It is NOT a vim mode — while open it publishes the `exline.open` scope flag
/// (so `vim.yaml` can bind Esc → dismiss for it alone) and dismisses back to
/// normal mode with no mode churn. The `:` and `ZZ` entries open it / run
/// `:wq` from the keymap; this widget owns the input, dispatch, and the
/// rejected-command hint. Always mounted (like quick-open); inert unless the
/// keymap opens it, which only `vim.yaml` does.
class ExLineOverlay extends StatefulWidget {
  const ExLineOverlay({super.key});

  @override
  State<ExLineOverlay> createState() => _ExLineOverlayState();
}

class _ExLineOverlayState extends State<ExLineOverlay> {
  final _input = TextEditingController();
  final _focus = FocusNode(debugLabel: 'ExLineOverlay.input');

  ExLineController? _exLine;
  KeymapService? _keymap;
  KernelServices? _services;

  /// True after a rejected (unknown) command, until the user edits the input.
  /// Drives the red border + hint instead of a timed flash (test-friendly).
  bool _rejected = false;
  int _seenInvalidNonce = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final kernel = ClideKernel.of(context);
    _services = kernel;
    if (!identical(_exLine, kernel.exLine)) {
      _exLine?.removeListener(_onChanged);
      _exLine = kernel.exLine;
      _seenInvalidNonce = _exLine!.invalidNonce;
      _exLine!.addListener(_onChanged);
      _syncFromController();
    }
    _keymap = kernel.keymap;
    final isOpen = _exLine?.isOpen ?? false;
    _keymap?.setScopeFlag('exline.open', isOpen);
    if (isOpen && !_focus.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (_exLine?.isOpen ?? false)) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _exLine?.removeListener(_onChanged);
    _keymap?.clearScopeFlag('exline.open');
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    final controller = _exLine;
    final isOpen = controller?.isOpen ?? false;
    _keymap?.setScopeFlag('exline.open', isOpen);
    if (isOpen) {
      _focus.requestFocus();
    } else {
      _rejected = false;
    }
    if (controller != null && controller.invalidNonce != _seenInvalidNonce) {
      _seenInvalidNonce = controller.invalidNonce;
      _rejected = true;
    }
    _syncFromController();
  }

  void _syncFromController() {
    final text = _exLine?.input ?? '';
    if (_input.text != text) {
      _input.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    if (mounted) setState(() {});
  }

  void _onInputChanged(String value) {
    if (_rejected) setState(() => _rejected = false);
    _exLine?.setInput(value);
  }

  Future<void> _submit() async {
    final controller = _exLine;
    final services = _services;
    if (controller == null || services == null) return;
    final cmd = parseExCommand(controller.input);
    switch (cmd) {
      case ExNoop():
        controller.close();
      case ExUnknown():
        controller.flashInvalid(); // stay open; the hint + border show
      case ExEdit(:final query):
        controller.close();
        services.quickOpen.open(seed: query.isEmpty ? null : query);
      case ExWrite():
        controller.close();
        await exWriteActive(services.ipc);
      case ExQuit():
        controller.close();
        await exQuitActive(services.ipc);
      case ExWriteQuit():
        controller.close();
        await exWriteQuitActive(services.ipc);
      case ExGoto(:final line):
        controller.close();
        await exGotoLineActive(services.ipc, line);
    }
  }

  Object? _dismiss(DismissIntent _) {
    _exLine?.close();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideSettings.theme.of(context).surface;
    return ListenableBuilder(
      listenable: kernel.exLine,
      builder: (ctx, _) {
        if (!kernel.exLine.isOpen) return const SizedBox.shrink();
        return Positioned(
          top: 60,
          left: 0,
          right: 0,
          child: Center(
            child: Actions(
              actions: <Type, Action<Intent>>{DismissIntent: CallbackAction<DismissIntent>(onInvoke: _dismiss)},
              child: Container(
                width: 480,
                decoration: BoxDecoration(
                  color: tokens.dropdownBackground,
                  border: Border.all(color: _rejected ? tokens.statusError : tokens.dropdownBorder),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [BoxShadow(color: tokens.shadowAmbient, blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          ClideText(':', fontFamily: ClideSettings.fonts.monoOf(context), color: tokens.globalTextMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: EditableText(
                              controller: _input,
                              focusNode: _focus,
                              style: TextStyle(fontFamily: ClideSettings.fonts.monoOf(context), fontSize: clideFontMono, color: tokens.dropdownForeground),
                              cursorColor: tokens.globalFocus,
                              backgroundCursorColor: tokens.globalFocus,
                              maxLines: 1,
                              onChanged: _onInputChanged,
                              onSubmitted: (_) => _submit(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_rejected)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ClideText('Not an editor command', fontSize: clideFontCaption, color: tokens.statusError),
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
