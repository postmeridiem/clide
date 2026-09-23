import 'package:clide/extension/src/contribution.dart';
import 'package:clide/src/daemon/window_commands.dart' show WindowHost;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The OS tray / Dock, and the window lifecycle behind it (D-110).
///
/// Two halves. The item registry holds [TrayItemContribution]s so extensions
/// can declare tray entries. The native bridge drives the per-platform half
/// over the `clide/tray` channel: on Linux and Windows a headless loader owns
/// one shared tray icon for every clide window; on macOS the Dock is the
/// surface. Dart owns the policy (close-to-tray, labels, the workspace name);
/// native only renders and reports.
///
/// Every native call degrades to `false` where the platform has no handler
/// (tests, web, a runner without the tray half), so callers never need to
/// guard.
class TrayRegistry extends ChangeNotifier implements WindowHost {
  TrayRegistry({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('clide/tray');

  final MethodChannel _channel;

  // -- item registry ---------------------------------------------------------

  final Map<String, TrayItemContribution> _items = {};

  void add(TrayItemContribution item) {
    _items[item.id] = item;
    notifyListeners();
  }

  void remove(String id) {
    if (_items.remove(id) != null) notifyListeners();
  }

  Iterable<TrayItemContribution> get items {
    final sorted = _items.values.toList()..sort((a, b) => a.priority.compareTo(b.priority));
    return sorted;
  }

  // -- native bridge ---------------------------------------------------------

  final ValueNotifier<bool> _available = ValueNotifier(false);

  /// Whether something can bring a hidden window back — a tray host with a
  /// running loader, or the Dock. Reported by native; false until it does.
  /// Close-to-tray only takes effect while this is true.
  ValueListenable<bool> get available => _available;

  bool _attached = false;

  /// Start listening for native reports. Idempotent; called by the extension
  /// that owns the tray policy once the binding exists.
  void attachNative() {
    if (_attached) return;
    _attached = true;
    _channel.setMethodCallHandler(_onNativeCall);
    // Native may have learned availability before we listened — ask.
    _invoke<bool>('isAvailable').then((v) => _available.value = v ?? false);
  }

  Future<Object?> _onNativeCall(MethodCall call) async {
    if (call.method == 'availability') {
      final args = call.arguments;
      _available.value = args is Map ? args['available'] == true : args == true;
    }
    return null;
  }

  /// Whether the window's close hides it instead of quitting. Native still
  /// quits when nothing could bring the window back.
  Future<bool> setCloseToTray(bool enabled) async => await _invoke<bool>('setCloseToTray', enabled) ?? false;

  /// This window's workspace, as the tray menu names it.
  Future<bool> setWorkspace(String? path) async => await _invoke<bool>('setWorkspace', path) ?? false;

  /// Localized labels for the shared menu (native has no catalog).
  Future<bool> setLabels(Map<String, String> labels) async => await _invoke<bool>('setLabels', labels) ?? false;

  /// Draw the eye to the tray once — the icon spins a turn (Linux), the Dock
  /// icon bounces (macOS). Cosmetic: callers throttle, native absorbs bursts.
  Future<bool> pulse() async => await _invoke<bool>('pulse') ?? false;

  @override
  Future<bool> show() async => await _invoke<bool>('show') ?? false;

  @override
  Future<bool> hide() async => await _invoke<bool>('hide') ?? false;

  @override
  Future<bool> quit({required bool all}) async => await _invoke<bool>(all ? 'quitAll' : 'quit') ?? false;

  Future<T?> _invoke<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  void dispose() {
    if (_attached) _channel.setMethodCallHandler(null);
    _available.dispose();
    super.dispose();
  }
}
