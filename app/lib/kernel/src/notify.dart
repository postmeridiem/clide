import 'dart:async';

import 'package:flutter/foundation.dart';

enum NotificationLevel { info, warning, error, success }

@immutable
class ClideNotification {
  ClideNotification({
    required this.id,
    required this.level,
    required this.message,
    this.title,
    this.duration = const Duration(seconds: 4),
  }) : createdAt = DateTime.now().toUtc();

  final String id;
  final NotificationLevel level;
  final String? title;
  final String message;
  final DateTime createdAt;
  final Duration duration;
}

class Notifications extends ChangeNotifier {
  final List<ClideNotification> _active = [];
  final Map<String, Timer> _timers = {};
  int _seq = 0;

  List<ClideNotification> get active => List.unmodifiable(_active);

  void info(String message, {String? title, Duration? duration}) =>
      _push(NotificationLevel.info, message, title: title, duration: duration);
  void warn(String message, {String? title, Duration? duration}) =>
      _push(NotificationLevel.warning, message,
          title: title, duration: duration);
  void error(String message, {String? title, Duration? duration}) =>
      _push(NotificationLevel.error, message, title: title, duration: duration);
  void success(String message, {String? title, Duration? duration}) =>
      _push(NotificationLevel.success, message,
          title: title, duration: duration);

  void dismiss(String id) {
    _timers.remove(id)?.cancel();
    final before = _active.length;
    _active.removeWhere((n) => n.id == id);
    if (_active.length != before) notifyListeners();
  }

  void _push(
    NotificationLevel level,
    String message, {
    String? title,
    Duration? duration,
  }) {
    final id = 'n${_seq++}';
    final n = ClideNotification(
      id: id,
      level: level,
      message: message,
      title: title,
      duration: duration ?? const Duration(seconds: 4),
    );
    _active.add(n);
    _timers[id] = Timer(n.duration, () => dismiss(id));
    notifyListeners();
  }

  @override
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}
