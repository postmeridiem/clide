// Based on xterm.dart v4.0.0 by xuty (MIT). See LICENSE in this directory.

mixin Observable {
  final listeners = <void Function()>{};

  void addListener(void Function() listener) {
    listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    listeners.remove(listener);
  }

  void notifyListeners() {
    for (var listener in listeners) {
      listener();
    }
  }
}
