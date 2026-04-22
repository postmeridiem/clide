import 'package:flutter/foundation.dart';

@immutable
abstract class ClideEvent {
  const ClideEvent();

  String get subsystem;
  String get kind;

  Map<String, Object?> payload() => const {};
}

@immutable
class ClideEventEnvelope {
  const ClideEventEnvelope(this.event, this.timestamp);

  final ClideEvent event;
  final DateTime timestamp;

  Map<String, Object?> toJson() => {
        'v': 1,
        'subsystem': event.subsystem,
        'kind': event.kind,
        'ts': timestamp.toIso8601String(),
        'data': event.payload(),
      };
}

class DaemonConnectionChanged extends ClideEvent {
  const DaemonConnectionChanged({required this.connected});
  final bool connected;
  @override
  String get subsystem => 'ipc';
  @override
  String get kind => 'connection-changed';
  @override
  Map<String, Object?> payload() => {'connected': connected};
}

class ThemeChanged extends ClideEvent {
  const ThemeChanged({required this.themeName});
  final String themeName;
  @override
  String get subsystem => 'theme';
  @override
  String get kind => 'changed';
  @override
  Map<String, Object?> payload() => {'theme': themeName};
}

class ProjectOpened extends ClideEvent {
  const ProjectOpened({required this.path});
  final String path;
  @override
  String get subsystem => 'project';
  @override
  String get kind => 'opened';
  @override
  Map<String, Object?> payload() => {'path': path};
}

class ProjectClosed extends ClideEvent {
  const ProjectClosed();
  @override
  String get subsystem => 'project';
  @override
  String get kind => 'closed';
}

class ExtensionActivated extends ClideEvent {
  const ExtensionActivated({required this.id});
  final String id;
  @override
  String get subsystem => 'extensions';
  @override
  String get kind => 'activated';
  @override
  Map<String, Object?> payload() => {'id': id};
}

class ExtensionDeactivated extends ClideEvent {
  const ExtensionDeactivated({required this.id});
  final String id;
  @override
  String get subsystem => 'extensions';
  @override
  String get kind => 'deactivated';
  @override
  Map<String, Object?> payload() => {'id': id};
}

/// Forwarded from the daemon. Feature extensions subscribe to this and
/// narrow by subsystem+kind, or register a converter that emits a typed
/// `ClideEvent` subclass into the bus.
class DaemonEvent extends ClideEvent {
  const DaemonEvent({
    required this.subsystem,
    required this.kind,
    required this.data,
    required this.ts,
  });

  @override
  final String subsystem;
  @override
  final String kind;
  final Map<String, Object?> data;
  final DateTime ts;

  @override
  Map<String, Object?> payload() => {'ts': ts.toIso8601String(), ...data};
}
