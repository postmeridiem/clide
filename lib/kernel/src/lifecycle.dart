/// App lifecycle observation (T-541) — is the window actually being looked at?
///
/// A new capability for this codebase: nothing observed `AppLifecycleState`
/// before, so anything that animates or polls kept doing so while the window was
/// minimised. That is a defect the user feels as fan noise and battery, and it
/// is not the companion's alone — a terminal repaint, the graph's simulation and
/// any future poll want the same answer. So it lives here rather than inside the
/// widget that happened to need it first.
///
/// Deliberately a small, boring service: it reports, it does not decide. Whether
/// a given surface *should* quiesce when hidden is that surface's business (and,
/// for the companion, the user's — `app.companion.suspendWhenMinimised`).
library;

import 'package:flutter/widgets.dart';

/// Watches the platform's lifecycle and reports whether the window is visible.
///
/// A `ChangeNotifier` rather than a stream, to match the other kernel services
/// and because the interesting question ("is it visible right now?") wants a
/// current value, not a history.
class AppLifecycle extends ChangeNotifier with WidgetsBindingObserver {
  AppLifecycle({WidgetsBinding? binding}) : _binding = binding;

  final WidgetsBinding? _binding;

  /// Resolved once in [start]; null when there is no binding at all.
  WidgetsBinding? _bind;

  bool _started = false;

  /// The binding, or null if none has been initialized.
  ///
  /// A guarded read because Flutter offers no non-throwing accessor — `instance`
  /// throws rather than returning null. Worth the ugliness: the kernel boots in
  /// contexts with no widget layer (headless IPC, plain `dart`/`test` files),
  /// and making `KernelServices.boot` require a binding would be a regression in
  /// what the kernel is for.
  static WidgetsBinding? _resolveBinding() {
    try {
      return WidgetsBinding.instance;
    } catch (_) {
      return null;
    }
  }

  /// Last state the platform reported.
  ///
  /// Starts at [AppLifecycleState.resumed]: the app is on screen when it boots,
  /// and assuming otherwise would have every consumer start suspended and stay
  /// that way until the first transition — which on a window nobody minimises
  /// never comes.
  AppLifecycleState _state = AppLifecycleState.resumed;

  AppLifecycleState get state => _state;

  /// Whether the window is on screen at all.
  ///
  /// **`inactive` counts as visible**, and that is the load-bearing decision
  /// here. On desktop, clicking another application makes clide `inactive` while
  /// it stays fully visible beside it; treating that as hidden would freeze
  /// animation in a window the user is looking straight at — a far more
  /// noticeable defect than the one this exists to fix.
  ///
  /// `hidden` is what a minimise reports; `paused` is the mobile analogue;
  /// `detached` means there is no view to draw into.
  ///
  /// Verified rather than assumed, because a rung that never fires reads as
  /// done while doing nothing. On Linux/GTK (X11 under XWayland, which is what
  /// `make run` selects) minimising reports `resumed → inactive → hidden`, and
  /// restoring reports `hidden → inactive → resumed` — so `hidden` does arrive,
  /// and `inactive` appears in passing on both transitions. That transit is the
  /// second reason `inactive` must not suspend: treating it as hidden would
  /// flicker the surface off and on every time the window is restored.
  bool get visible => switch (_state) {
    AppLifecycleState.resumed || AppLifecycleState.inactive => true,
    AppLifecycleState.hidden || AppLifecycleState.paused || AppLifecycleState.detached => false,
  };

  /// Begin observing. Idempotent.
  ///
  /// With no binding this is a no-op and [visible] stays true — headless clide
  /// has no window, so nothing should be suspending on its account.
  void start() {
    if (_started) return;
    final binding = _binding ?? _resolveBinding();
    if (binding == null) return;

    _started = true;
    _bind = binding;
    binding.addObserver(this);
    // Seed from the binding rather than assuming: an observer added after the
    // app was already backgrounded would otherwise believe it was visible until
    // the next transition.
    final current = binding.lifecycleState;
    if (current != null && current != _state) {
      _state = current;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == _state) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_started) {
      _bind?.removeObserver(this);
      _bind = null;
      _started = false;
    }
    super.dispose();
  }
}
