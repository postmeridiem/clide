/// Unit tests for the `ClideEvent` subclasses and `ClideEventEnvelope`
/// in `lib/kernel/src/events/types.dart`.
library;

import 'package:clide/kernel/src/events/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClideEvent subclasses — subsystem / kind / payload', () {
    test('DaemonConnectionChanged', () {
      const e = DaemonConnectionChanged(connected: true);
      expect(e.subsystem, 'ipc');
      expect(e.kind, 'connection-changed');
      expect(e.payload(), {'connected': true});
    });

    test('ThemeChanged', () {
      const e = ThemeChanged(themeName: 'midnight');
      expect(e.subsystem, 'theme');
      expect(e.kind, 'changed');
      expect(e.payload(), {'theme': 'midnight'});
    });

    test('ProjectOpened', () {
      const e = ProjectOpened(path: '/tmp/x');
      expect(e.subsystem, 'project');
      expect(e.kind, 'opened');
      expect(e.payload(), {'path': '/tmp/x'});
    });

    test('ProjectClosed — empty payload default applies', () {
      const e = ProjectClosed();
      expect(e.subsystem, 'project');
      expect(e.kind, 'closed');
      expect(e.payload(), isEmpty);
    });

    test('ExtensionActivated / ExtensionDeactivated', () {
      const a = ExtensionActivated(id: 'builtin.git');
      expect(a.subsystem, 'extensions');
      expect(a.kind, 'activated');
      expect(a.payload(), {'id': 'builtin.git'});
      const d = ExtensionDeactivated(id: 'builtin.git');
      expect(d.subsystem, 'extensions');
      expect(d.kind, 'deactivated');
      expect(d.payload(), {'id': 'builtin.git'});
    });

    test('DaemonEvent merges ts into payload', () {
      final ts = DateTime.utc(2026, 5, 11, 12, 0, 0);
      final e = DaemonEvent(
        subsystem: 'pty',
        kind: 'output',
        data: {'bytes': 'aGVsbG8='},
        ts: ts,
      );
      expect(e.subsystem, 'pty');
      expect(e.kind, 'output');
      expect(e.payload()['ts'], ts.toIso8601String());
      expect(e.payload()['bytes'], 'aGVsbG8=');
    });
  });

  group('ClideEventEnvelope', () {
    test('toJson builds a v1 envelope around the event', () {
      final ts = DateTime.utc(2026, 5, 11, 9, 30);
      const event = ThemeChanged(themeName: 'paper');
      final envelope = ClideEventEnvelope(event, ts);
      final json = envelope.toJson();
      expect(json['v'], 1);
      expect(json['subsystem'], 'theme');
      expect(json['kind'], 'changed');
      expect(json['ts'], ts.toIso8601String());
      expect(json['data'], {'theme': 'paper'});
    });
  });
}
