/// Live companion state for widgets (T-527, T-528).
///
/// Seeds from the stored preference, then follows `companion.state` on the bus.
/// Both halves are needed and neither is optional: the bus has no retention, so
/// a subscriber alone renders the default until something happens to change —
/// which for a preference nobody touches this session is never. The store holds
/// the initial truth; the bus carries the changes.
///
/// Shared because there are now two consumers on opposite sides of the window —
/// the strip in the context column and its toggle in the status bar — and they
/// must never disagree about whether Clide is open.
library;

import 'dart:async';

import 'package:clide/builtin/clide_companion/src/companion_channel.dart';
import 'package:clide/builtin/clide_companion/src/companion_settings.dart';
import 'package:clide/builtin/clide_companion/src/session_load.dart';
import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:clide/kernel/src/facade.dart' show ClideKernel;
import 'package:clide/widgets/src/clide_settings.dart';
import 'package:flutter/widgets.dart';

/// What a companion surface needs to know to draw itself.
class CompanionState {
  const CompanionState({
    required this.enabled,
    required this.open,
    this.load = SessionLoad.absent,
    this.busySince,
    this.suspendWhenMinimised = kCompanionSuspendWhenMinimisedDefault,
  });

  /// Whether to stop animating while the window is minimised (T-541).
  ///
  /// App-scoped rather than per-repo, because it is about not heating the
  /// machine. Off is a legitimate choice on a desktop that does not care.
  final bool suspendWhenMinimised;

  /// The kill switch: whether Clide exists for this repo at all.
  final bool enabled;

  /// Whether the strip is showing, as opposed to minimised to its rail button.
  final bool open;

  /// What the **primary** session is doing — the weather (D-107 commitment 5).
  ///
  /// Defaults to [SessionLoad.absent] rather than something livelier: until the
  /// ask is answered we do not know, and parking the render loop is the safer
  /// bias for a surface whose power behaviour is a contract. The answer arrives
  /// within a microtask of mount.
  final SessionLoad load;

  /// When the current turn started, or null when idle. Stamped by the adapter,
  /// not by anything that renders.
  final DateTime? busySince;

  /// Whether the strip should be in the tree.
  bool get stripVisible => enabled && open;
}

typedef CompanionStateWidgetBuilder = Widget Function(BuildContext context, CompanionState state);

class CompanionStateBuilder extends StatefulWidget {
  const CompanionStateBuilder({super.key, required this.builder});

  final CompanionStateWidgetBuilder builder;

  @override
  State<CompanionStateBuilder> createState() => _CompanionStateBuilderState();
}

class _CompanionStateBuilderState extends State<CompanionStateBuilder> {
  StreamSubscription<Message>? _sub;
  StreamSubscription<Message>? _loadSub;
  MessageBus? _bus;

  bool _enabled = kCompanionEnabledDefault;
  bool _open = kCompanionOpenDefault;
  SessionLoad _load = SessionLoad.absent;
  DateTime? _busySince;
  bool _suspendWhenMinimised = kCompanionSuspendWhenMinimisedDefault;
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_seeded) {
      final store = ClideSettings.values.storeOf(context);
      final prefs = ClideCompanionSettings((k) => store?.get<Object>(k));
      _enabled = prefs.enabled;
      _open = prefs.open;
      _suspendWhenMinimised = prefs.suspendWhenMinimised;
      _seeded = true;
    }

    final bus = ClideKernel.maybeOf(context)?.messages;
    if (identical(bus, _bus)) return;
    _sub?.cancel();
    _loadSub?.cancel();
    _bus = bus;
    if (bus == null) return;

    _sub = bus.subscribe(publisher: clideCompanionPublisher, channel: companionStateChannel).listen((m) {
      if (!mounted) return;
      // Fields absent from an announcement are left alone — a message about
      // `open` says nothing about `enabled`.
      final enabled = m.data['enabled'] as bool? ?? _enabled;
      final open = m.data['open'] as bool? ?? _open;
      if (enabled == _enabled && open == _open) return;
      setState(() {
        _enabled = enabled;
        _open = open;
      });
    });

    _loadSub = bus.subscribe(publisher: clideCompanionPublisher, channel: companionLoadChannel).listen((m) {
      if (!mounted) return;
      final busy = m.data['busy'] as bool? ?? false;
      final sinceMs = m.data['busySinceMs'] as int?;
      // `calm` rather than `absent` when idle: the adapter only publishes at all
      // when it is watching, so an announcement is itself evidence a session
      // exists. `absent` is the pre-answer default, not an announced value.
      final load = busy ? SessionLoad.working : SessionLoad.calm;
      final since = sinceMs == null ? null : DateTime.fromMillisecondsSinceEpoch(sinceMs);
      if (load == _load && since == _busySince) return;
      setState(() {
        _load = load;
        _busySince = since;
      });
    });

    askCompanionLoad(bus);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _loadSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, CompanionState(enabled: _enabled, open: _open, load: _load, busySince: _busySince, suspendWhenMinimised: _suspendWhenMinimised));
}
