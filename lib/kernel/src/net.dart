import 'package:flutter/foundation.dart';

enum Reachability { online, offline, metered }

/// Tier-0 stub reachability observable. Hardcoded to `online`; real
/// detection via a platform channel lands in a later tier.
class NetworkStatus extends ChangeNotifier {
  Reachability _state = Reachability.online;
  Reachability get state => _state;
  bool get isOnline => _state != Reachability.offline;

  @visibleForTesting
  void setState(Reachability r) {
    if (_state == r) return;
    _state = r;
    notifyListeners();
  }
}
