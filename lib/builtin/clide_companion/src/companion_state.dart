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
import 'package:clide/builtin/claude/src/session_reader.dart';
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
    this.moodChannel = kCompanionMoodChannelDefault,
  });

  /// Whether a mood Clide names for himself is honoured (T-532). Off, his
  /// expression comes from his session lifecycle alone. Applies live — the
  /// prefix format needs no tool, so both settings spawn identically.
  final bool moodChannel;

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
  StreamSubscription<bool>? _loadSub;
  SessionReader? _reader;
  MessageBus? _bus;

  bool _enabled = kCompanionEnabledDefault;
  bool _open = kCompanionOpenDefault;
  SessionLoad _load = SessionLoad.absent;
  DateTime? _busySince;
  bool _suspendWhenMinimised = kCompanionSuspendWhenMinimisedDefault;
  bool _moodChannel = kCompanionMoodChannelDefault;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    // Not in didChangeDependencies: the reader takes nothing from the tree, and
    // binding it there would tie its lifetime to the bus rebind below — which
    // is exactly the bug the collapse introduced once.
    _bindLoad();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_seeded) {
      final store = ClideSettings.values.storeOf(context);
      final prefs = ClideCompanionSettings((k) => store?.get<Object>(k));
      _enabled = prefs.enabled;
      _open = prefs.open;
      _suspendWhenMinimised = prefs.suspendWhenMinimised;
      _moodChannel = prefs.moodChannel;
      _seeded = true;
    }

    final bus = ClideKernel.maybeOf(context)?.messages;
    if (identical(bus, _bus)) return;
    _sub?.cancel();
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
  }

  /// The primary session's load, read directly (T-561).
  ///
  /// This used to arrive over a `companion.load` bus channel with an
  /// ask/answer handshake, because a widget this deep could not bind a session
  /// and an extension had to do it. The session reader removed that constraint,
  /// and with it a channel pair, an adapter, and the only request/response
  /// pattern in the codebase.
  ///
  /// `companion.set`/`companion.state` stay on the bus, and rightly: they span
  /// surfaces — a rail button in the status bar and this strip in the context
  /// column — which is what a bus is for. Load never spanned anything; it went
  /// out to the bus and came straight back to one widget.
  void _bindLoad() {
    _reader = SessionReader.primary()..start();
    _loadSub = _reader!.busy.listen((busy) {
      if (!mounted) return;
      // `absent` only while nothing is bound. A session that exists and is idle
      // is `calm` — a drip, so the surface reads as alive rather than dead.
      final load = !_reader!.attached
          ? SessionLoad.absent
          : busy
          ? SessionLoad.working
          : SessionLoad.calm;
      final since = _reader!.busySince;
      if (load == _load && since == _busySince) return;
      setState(() {
        _load = load;
        _busySince = since;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _loadSub?.cancel();
    _reader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    CompanionState(enabled: _enabled, open: _open, load: _load, busySince: _busySince, suspendWhenMinimised: _suspendWhenMinimised, moodChannel: _moodChannel),
  );
}
