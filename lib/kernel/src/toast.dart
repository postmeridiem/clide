import 'dart:async';

import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:flutter/foundation.dart';

/// Severity of a toast. Maps to the theme's status tokens at render time
/// (success/warning/error/info) — see `ClideToast`.
enum ToastSeverity { success, warning, error, info }

/// MessageBus channel the [ToastService] consumes. Any component raises a
/// toast by publishing here — it needs no reference to the service. See
/// [publishToast].
const String toastChannel = 'toast';

ToastSeverity _severityFromName(Object? name) => switch (name) {
      'success' => ToastSeverity.success,
      'warning' => ToastSeverity.warning,
      'error' => ToastSeverity.error,
      _ => ToastSeverity.info,
    };

/// Raise a toast by publishing to the MessageBus — the decoupled path:
/// emitters depend only on the bus, never on the [ToastService]. [publisher]
/// is the emitter id (e.g. `builtin.git`), kept for provenance/filtering.
void publishToast(
  MessageBus messages,
  String publisher,
  String message, {
  ToastSeverity severity = ToastSeverity.info,
  Duration? duration,
}) {
  messages.publish(publisher, toastChannel, {
    'message': message,
    'severity': severity.name,
    if (duration != null) 'durationMs': duration.inMilliseconds,
  });
}

/// One live toast. Immutable; the [ToastService] owns the list.
@immutable
class ToastEntry {
  const ToastEntry({required this.id, required this.message, required this.severity});

  /// Monotonic id, unique within a [ToastService] lifetime. Used as the
  /// widget key and the [ToastService.dismiss] handle.
  final int id;
  final String message;
  final ToastSeverity severity;
}

/// Non-modal toast notifications for operation feedback (T-50).
///
/// A MessageBus consumer: it subscribes to the [toastChannel] and turns each
/// published message into a queued toast, so emitters (git, extensions, …)
/// stay decoupled — they publish, they don't hold a reference here. Queues
/// multiple (newest last), auto-dismisses each after a per-severity timeout
/// (errors linger), supports manual dismissal, and caps the visible count.
/// UI-only kernel service (a [ChangeNotifier], like the palette/dialog
/// controllers); the `ToastOverlay` widget renders [entries] bottom-right.
class ToastService extends ChangeNotifier {
  ToastService({required MessageBus messages, this.maxVisible = 4}) : _messages = messages {
    _sub = _messages.subscribe(channel: toastChannel).listen(_onMessage);
  }

  final MessageBus _messages;
  StreamSubscription<Message>? _sub;

  /// Most toasts shown at once; older ones are dropped past this.
  final int maxVisible;

  static const Duration defaultDuration = Duration(seconds: 4);

  /// Errors linger longer — they're more likely to matter and to be missed.
  static const Duration errorDuration = Duration(seconds: 8);

  int _nextId = 0;
  final List<ToastEntry> _entries = [];
  final Map<int, Timer> _timers = {};

  /// Live toasts, oldest first. Unmodifiable.
  List<ToastEntry> get entries => List.unmodifiable(_entries);

  void _onMessage(Message m) {
    final msg = m.data['message'];
    if (msg is! String) return;
    final ms = m.data['durationMs'];
    show(
      msg,
      severity: _severityFromName(m.data['severity']),
      duration: ms is int ? Duration(milliseconds: ms) : null,
    );
  }

  /// Show a toast directly (the queue API the bus handler also calls).
  /// Returns its id (for [dismiss]). A non-positive [duration] (or
  /// `Duration.zero`) makes it sticky — no auto-dismiss.
  int show(String message, {ToastSeverity severity = ToastSeverity.info, Duration? duration}) {
    final id = _nextId++;
    _entries.add(ToastEntry(id: id, message: message, severity: severity));
    while (_entries.length > maxVisible) {
      final dropped = _entries.removeAt(0);
      _timers.remove(dropped.id)?.cancel();
    }
    final d = duration ?? (severity == ToastSeverity.error ? errorDuration : defaultDuration);
    if (d > Duration.zero) {
      _timers[id] = Timer(d, () => dismiss(id));
    }
    notifyListeners();
    return id;
  }

  /// Remove a toast (manual dismiss or auto-dismiss). No-op if already gone.
  void dismiss(int id) {
    _timers.remove(id)?.cancel();
    final before = _entries.length;
    _entries.removeWhere((e) => e.id == id);
    if (_entries.length != before) notifyListeners();
  }

  /// Drop every toast (e.g. on project close).
  void clear() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}
