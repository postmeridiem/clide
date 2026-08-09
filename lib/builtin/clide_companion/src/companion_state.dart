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
import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:clide/kernel/src/facade.dart' show ClideKernel;
import 'package:clide/widgets/src/clide_settings.dart';
import 'package:flutter/widgets.dart';

/// What a companion surface needs to know to draw itself.
class CompanionState {
  const CompanionState({required this.enabled, required this.open});

  /// The kill switch: whether Clide exists for this repo at all.
  final bool enabled;

  /// Whether the strip is showing, as opposed to minimised to its rail button.
  final bool open;

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
  MessageBus? _bus;

  bool _enabled = kCompanionEnabledDefault;
  bool _open = kCompanionOpenDefault;
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_seeded) {
      final store = ClideSettings.values.storeOf(context);
      final prefs = ClideCompanionSettings((k) => store?.get<Object>(k));
      _enabled = prefs.enabled;
      _open = prefs.open;
      _seeded = true;
    }

    final bus = ClideKernel.maybeOf(context)?.messages;
    if (identical(bus, _bus)) return;
    _sub?.cancel();
    _bus = bus;
    _sub = bus?.subscribe(publisher: clideCompanionPublisher, channel: companionStateChannel).listen((m) {
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

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, CompanionState(enabled: _enabled, open: _open));
}
