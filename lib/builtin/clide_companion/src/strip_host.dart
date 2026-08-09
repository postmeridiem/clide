/// Mounts the Clide strip, or does not (T-527, D-107).
///
/// Exists so `slot_host.dart` stays ignorant of the companion beyond "put this
/// here": the shell should not know what a kill switch is, and the companion
/// should not need the shell edited every time its visibility rules change.
///
/// Disabled means **gone**, not hidden — the 112px goes back to the detail view
/// (D-107 commitment 1, and the shape the user asked for: "off is off for the
/// repo"). Minimising is a different control with a different key (T-528).
library;

import 'dart:async';

import 'package:clide/builtin/clide_companion/src/clide_strip.dart';
import 'package:clide/builtin/clide_companion/src/companion_channel.dart';
import 'package:clide/builtin/clide_companion/src/companion_settings.dart';
import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:clide/kernel/src/facade.dart' show ClideKernel;
import 'package:clide/widgets/src/clide_settings.dart';
import 'package:flutter/widgets.dart';

class ClideStripHost extends StatefulWidget {
  const ClideStripHost({super.key});

  @override
  State<ClideStripHost> createState() => _ClideStripHostState();
}

class _ClideStripHostState extends State<ClideStripHost> {
  StreamSubscription<Message>? _sub;
  MessageBus? _bus;

  /// Seeded from the stored preference, then driven by the bus. The bus does
  /// not retain, so a widget that only subscribed would render the default
  /// until something happened to change — which for a setting nobody touches
  /// this session is forever.
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
      setState(() {
        _enabled = m.data['enabled'] as bool? ?? _enabled;
        _open = m.data['open'] as bool? ?? _open;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Minimised still renders nothing *here* — T-528 adds the rail button that
    // brings it back, which lives in the status bar rather than in this column.
    if (!_enabled || !_open) return const SizedBox.shrink();
    return const ClideStrip();
  }
}
