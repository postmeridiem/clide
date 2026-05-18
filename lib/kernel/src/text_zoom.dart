import 'package:flutter/foundation.dart';

/// Workspace-wide text zoom factor.
///
/// Owned by the kernel rather than the root widget so command-palette
/// entries, the keymap layer, and any future menu/CLI surface can mutate
/// the same number. The root `MediaQuery` listens via [ChangeNotifier].
class TextZoom extends ChangeNotifier {
  TextZoom();

  static const double minScale = 0.6;
  static const double maxScale = 2.0;
  static const double stepScale = 0.05;

  double _scale = 1.0;
  double get scale => _scale;

  void increase() => _setScale(_scale + stepScale);
  void decrease() => _setScale(_scale - stepScale);
  void reset() => _setScale(1.0);

  void _setScale(double next) {
    final clamped = next.clamp(minScale, maxScale);
    if (clamped == _scale) return;
    _scale = clamped;
    notifyListeners();
  }
}
