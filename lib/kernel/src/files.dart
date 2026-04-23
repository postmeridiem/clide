import 'dart:async';

import 'package:clide/kernel/src/events/bus.dart';
import 'package:clide/kernel/src/events/types.dart';
import 'package:clide/kernel/src/panels/slot_id.dart';
import 'package:flutter/foundation.dart';

class FilesDropped extends ClideEvent {
  const FilesDropped({required this.paths, required this.slot});

  final List<String> paths;
  final SlotId slot;

  @override
  String get subsystem => 'files';
  @override
  String get kind => 'dropped';
  @override
  Map<String, Object?> payload() => {
        'paths': paths,
        'slot': slot.value,
      };
}

/// Tier-0 stub for file pickers and drop targets.
///
/// Flutter desktop has no native picker API without a dep; rather than
/// add one now, pickOpen/pickSave/pickDirectory throw UnimplementedError
/// and the drop target is a no-op until we wire it through the
/// platform channel. This lets the rest of the kernel compile and makes
/// the service surface real.
class FileServices {
  FileServices(this._events);
  final DaemonBus _events;

  Future<List<String>> pickOpen({
    List<String> extensions = const [],
    bool multiple = false,
  }) async {
    throw UnimplementedError('pickOpen — wired in a later tier');
  }

  Future<String?> pickSave({
    String? defaultName,
    List<String> extensions = const [],
  }) async {
    throw UnimplementedError('pickSave — wired in a later tier');
  }

  Future<String?> pickDirectory() async {
    throw UnimplementedError('pickDirectory — wired in a later tier');
  }

  /// Invoked by the platform drop-target wiring when files land on a
  /// slot. Emits a [FilesDropped] event; the slot-owning extension
  /// subscribes.
  @visibleForTesting
  void notifyDropped({required List<String> paths, required SlotId slot}) {
    _events.emit(FilesDropped(paths: paths, slot: slot));
  }
}
