/// The application root shell: global keyboard/intent routing (keymap
/// resolution, double-tap modifiers, menu mnemonics), the hat bar, and
/// the overlay stack (palette, quick-open, welcome, toasts). Split out
/// of app.dart (T-394).
library;

import 'dart:async';

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

  // Global multi-chord matcher for window/tab commands (ctrl+w h, gt …) (T-404).
  // The passive KeyboardListener can't run sequences or consume the second
  // chord (a focused editor/pane swallows it), so this lives at the
  // HardwareKeyboard level where returning true consumes the event before focus
  // dispatch. It only engages for chords that START a multi-chord binding in the
  // active keymap, so single-chord presets (default/vscode/jetbrains) are
  // untouched.
  late final SequenceMatcher _globalSeq;
  Timer? _seqTimeout;

  @override
  void initState() {
    super.initState();
    _keyFocus = FocusNode()..requestFocus();
    widget.services.textZoom.addListener(_onZoom);
    // Re-apply the UI font + language when their settings change (T-460/T-462).
    widget.services.settings.addListener(_onZoom);
    _applyLocale(); // apply the persisted UI language at boot
    _globalSeq = SequenceMatcher(
      keymap: () => widget.services.keymap.keymap ?? Keymap(const []),
      context: () => widget.services.keymap.scope,
      captureCounts: false,
    );
    HardwareKeyboard.instance.addHandler(_onRawKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onRawKey);
    _seqTimeout?.cancel();
    widget.services.textZoom.removeListener(_onZoom);
    widget.services.settings.removeListener(_onZoom);
    _menuBar.dispose();
    _keyFocus.dispose();
    super.dispose();
  }

  void _onZoom() {
    _applyLocale();
    setState(() {});
  }

  /// Apply the persisted UI language (app.locale) to the i18n service. setLocale
  /// is a no-op when the locale is unchanged, so this is safe on every tick.
  void _applyLocale() {
    final raw = widget.services.settings.get<String>(kLocaleSettingKey);
    if (raw == null || raw.isEmpty) return;
    final parts = raw.split(RegExp('[_-]'));
    final loc = parts.length >= 2 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
    widget.services.i18n.setLocale(loc);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    // Resolve the user-selected fonts once (Settings → Appearance, T-460/T-471)
    // and publish them via ClideFonts; the settings listener rebuilds this on a
    // change so descendants re-read live. The UI font flows through the
    // DefaultTextStyle below; mono sites read ClideFonts.monoOf(context).
    final settings = widget.services.settings;
    final uiFont = settings.get<String>(kUiFontSettingKey) ?? clideUiFamily;
    final monoFont = settings.get<String>(kMonoFontSettingKey) ?? clideMonoFamily;
    return ClideSettingsScope(
      ui: uiFont,
      mono: monoFont,
      child: DefaultTextStyle(
        style: TextStyle(
          color: tokens.globalForeground,
          fontSize: 15,
          height: clideLineHeight,
          fontWeight: clideUiDefaultWeight,
          fontFamily: uiFont,
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
              ExLineOpenIntent: CallbackAction<ExLineOpenIntent>(
                onInvoke: (_) {
                  widget.services.exLine.open();
                  return null;
                },
              ),
              ExLineWriteQuitIntent: CallbackAction<ExLineWriteQuitIntent>(
                onInvoke: (_) {
                  // ZZ — save+close the active tab without opening the overlay.
                  unawaited(exWriteQuitActive(widget.services.ipc));
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
                              const ExLineOverlay(),
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
    // Global window/tab sequences (ctrl+w h, gt …) get first claim — handled
    // here so a focused editor/pane can't swallow the second chord (T-404).
    if (_handleGlobalSequence(event)) return true;
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

  /// Feed one key into the global multi-chord matcher (T-404). Returns true to
  /// CONSUME the event (suppressing focus dispatch) while a sequence is being
  /// built or completes; false leaves the normal single-chord [_onKey] path
  /// untouched. Only KeyDown events drive it — a held key must not re-fire a
  /// window command.
  bool _handleGlobalSequence(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final chord = KeyChord.fromKeyEvent(event, HardwareKeyboard.instance);
    if (chord == null) return false;
    final km = widget.services.keymap.keymap;
    if (km == null) return false;
    final scope = widget.services.keymap.scope;
    // Not mid-sequence: only START on a MODIFIED chord that's a sequence prefix
    // (ctrl+w …). Bare-key sequences (gg, dd) are editor/pane-local — the
    // focused widget owns them, so a global grab would steal the first chord
    // before the editor ever saw it. Once pending, the bare second chord (the
    // `h` of `ctrl+w h`) is consumed normally. Single-chord presets are
    // untouched (no prefix → no engage).
    if (!_globalSeq.hasPending) {
      final modified = chord.modifiers.any((m) => m != KeyModifier.shift);
      if (!modified || !km.match([chord], scope).isPrefix) return false;
    }
    final r = _globalSeq.feed(chord);
    switch (r.outcome) {
      case SeqOutcome.pending:
        _armSeqTimeout();
        return true;
      case SeqOutcome.fired:
        _cancelSeqTimeout();
        _dispatchIntent(r.intent!);
        return true;
      case SeqOutcome.unmatched:
        // The sequence broke — drop the buffer and let this lone key through to
        // normal handling (the abandoned prefix, e.g. a bare ctrl+w, simply
        // does nothing rather than firing late).
        _cancelSeqTimeout();
        return false;
    }
  }

  /// After a pending prefix, fire its buffered exact match (bare ctrl+w →
  /// editor.close) if no completing chord arrives in time — the d-vs-dd timeout
  /// (D-82), applied globally.
  void _armSeqTimeout() {
    _seqTimeout?.cancel();
    _seqTimeout = Timer(const Duration(milliseconds: 400), () {
      final r = _globalSeq.flush();
      if (r.outcome == SeqOutcome.fired) _dispatchIntent(r.intent!);
    });
  }

  void _cancelSeqTimeout() {
    _seqTimeout?.cancel();
    _seqTimeout = null;
  }

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
        final tokens = ClideSettings.theme.of(ctx).surface;
        return ColoredBox(color: tokens.globalBackground, child: const WelcomeView());
      },
    );
  }
}
