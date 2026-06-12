/// The application root shell: global keyboard/intent routing (keymap
/// resolution, double-tap modifiers, menu mnemonics), the hat bar, and
/// the overlay stack (palette, quick-open, welcome, toasts). Split out
/// of app.dart (T-394).
library;

import 'package:clide/builtin/menubar/menubar.dart';
import 'package:clide/builtin/welcome/src/welcome_view.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/shell/hat_bar.dart';
import 'package:clide/src/shell/layout.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key, required this.services});
  final KernelServices services;

  @override
  State<RootShell> createState() => RootShellState();
}

class RootShellState extends State<RootShell> {
  late final FocusNode _keyFocus;
  final MenuBarController _menuBar = MenuBarController();
  // Detects double-tapped bare modifiers (e.g. double-Shift → quick-open,
  // JetBrains "Search Everywhere"). Fed from a HardwareKeyboard handler, not
  // the focus tree: a focused editor consumes the chorded key of `Shift+;`,
  // so the gesture must observe every event to know a press wasn't bare
  // (T-341, T-409).
  final ModifierTapTracker _modTap = ModifierTapTracker();

  @override
  void initState() {
    super.initState();
    _keyFocus = FocusNode()..requestFocus();
    widget.services.textZoom.addListener(_onZoom);
    HardwareKeyboard.instance.addHandler(_onRawKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onRawKey);
    widget.services.textZoom.removeListener(_onZoom);
    _menuBar.dispose();
    _keyFocus.dispose();
    super.dispose();
  }

  void _onZoom() => setState(() {});

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
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(widget.services.textZoom.scale)),
        child: Actions(
          actions: <Type, Action<Intent>>{
            TextScaleIncreaseIntent: CallbackAction<TextScaleIncreaseIntent>(
              onInvoke: (_) {
                widget.services.textZoom.increase();
                return null;
              },
            ),
            TextScaleDecreaseIntent: CallbackAction<TextScaleDecreaseIntent>(
              onInvoke: (_) {
                widget.services.textZoom.decrease();
                return null;
              },
            ),
            TextScaleResetIntent: CallbackAction<TextScaleResetIntent>(
              onInvoke: (_) {
                widget.services.textZoom.reset();
                return null;
              },
            ),
            InvokeCommandIntent: CallbackAction<InvokeCommandIntent>(
              onInvoke: (intent) {
                widget.services.commands.execute(intent.commandId);
                return null;
              },
            ),
            PaletteOpenIntent: CallbackAction<PaletteOpenIntent>(
              onInvoke: (_) {
                widget.services.palette.open();
                return null;
              },
            ),
            QuickOpenIntent: CallbackAction<QuickOpenIntent>(
              onInvoke: (_) {
                widget.services.quickOpen.open();
                return null;
              },
            ),
            FindInFilesIntent: CallbackAction<FindInFilesIntent>(
              onInvoke: (_) {
                widget.services.arrangement.setVisible(Slots.sidebar, true);
                widget.services.arrangement.setCollapsed(Slots.sidebar, false);
                widget.services.panels.activateTab(Slots.sidebar, 'search.findInFiles');
                return null;
              },
            ),
            FocusNextPanelIntent: CallbackAction<FocusNextPanelIntent>(
              onInvoke: (_) {
                widget.services.focus.focusNextSlot();
                return null;
              },
            ),
            FocusPreviousPanelIntent: CallbackAction<FocusPreviousPanelIntent>(
              onInvoke: (_) {
                widget.services.focus.focusPreviousSlot();
                return null;
              },
            ),
          },
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
                    HatBar(kernel: widget.services, menuBar: _menuBar),
                    Expanded(
                      child: DialogHost(
                        router: widget.services.dialog,
                        child: Stack(
                          children: [
                            const Positioned.fill(child: RootLayout()),
                            const ClidePalette(),
                            const QuickOpenOverlay(),
                            const Positioned.fill(child: _WelcomeOverlay()),
                            const ToastOverlay(),
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
      ),
    );
  }

  void _onKey(KeyEvent event) {
    if (_handleMenuMnemonic(event)) return;
    final intent = widget.services.keymap.resolveEvent(event, HardwareKeyboard.instance);
    if (intent == null) return;
    _dispatchIntent(intent);
  }

  /// Double-tapped bare modifier (e.g. double-Shift → quick-open). Observed
  /// at the HardwareKeyboard level — before focus dispatch and regardless of
  /// who consumes the event — so a chorded key the focused editor swallows
  /// (the `;` of `Shift+;`) still dirties the press (T-341, T-409). Fires on
  /// the second clean *release*; never consumes anything.
  bool _onRawKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      var mod = KeyChord.modifierForLogicalKey(event.logicalKey);
      // A modifier pressed while a non-modifier is already held (rolled
      // `a`+Shift) is a chord, not a tap.
      if (mod != null && _nonModifierHeld()) mod = null;
      _modTap.down(mod);
    } else if (event is KeyUpEvent) {
      final mod = _modTap.up(KeyChord.modifierForLogicalKey(event.logicalKey), DateTime.now());
      if (mod != null) {
        final seq = [KeyChord.bareModifier(mod), KeyChord.bareModifier(mod)];
        final tapIntent = widget.services.keymap.resolveSequence(seq);
        if (tapIntent != null) _dispatchIntent(tapIntent);
      }
    }
    return false;
  }

  bool _nonModifierHeld() => HardwareKeyboard.instance.logicalKeysPressed.any((k) => KeyChord.modifierForLogicalKey(k) == null);

  void _dispatchIntent(Intent intent) {
    // Try the focused context first so feature widgets (palette, editor, …)
    // get a chance to handle their own intents; fall back to the app root's
    // Actions for global ones (text scale, generic command bridge).
    final ctx = FocusManager.instance.primaryFocus?.context ?? context;
    Actions.maybeInvoke(ctx, intent);
  }

  /// `Alt+<mnemonic>` opens (or toggles) the matching application menu (T-48).
  /// Returns true when consumed so it never falls through to keymap resolution.
  bool _handleMenuMnemonic(KeyEvent event) {
    if (event is! KeyDownEvent || !HardwareKeyboard.instance.isAltPressed) return false;
    final label = event.logicalKey.keyLabel.toLowerCase();
    if (label.length != 1) return false;
    final idx = _menuBar.indexForMnemonic(label);
    if (idx == null) return false;
    _menuBar.toggle(idx);
    return true;
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
        return ColoredBox(color: tokens.globalBackground, child: const WelcomeView());
      },
    );
  }
}
