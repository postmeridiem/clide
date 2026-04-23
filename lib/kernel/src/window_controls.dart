import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum ChromeStyle { seam, prompt, inline }

class WindowControls extends ChangeNotifier {
  static const _channel = MethodChannel('clide/window');

  ChromeStyle _style = ChromeStyle.seam;
  ChromeStyle get style => _style;

  void setStyle(ChromeStyle s) {
    if (_style == s) return;
    _style = s;
    notifyListeners();
  }

  Future<void> startDrag() async {
    try {
      await _channel.invokeMethod('startDrag');
    } on MissingPluginException {
      // Web or unsupported platform — no-op.
    }
  }

  Future<void> minimize() async {
    try {
      await _channel.invokeMethod('minimize');
    } on MissingPluginException {
      // no-op
    }
  }

  Future<void> toggleMaximize() async {
    try {
      await _channel.invokeMethod('maximize');
    } on MissingPluginException {
      // no-op
    }
  }

  Future<void> close() async {
    try {
      await _channel.invokeMethod('close');
    } on MissingPluginException {
      // no-op
    }
  }

  Future<bool> isMaximized() async {
    try {
      final result = await _channel.invokeMethod<bool>('isMaximized');
      return result ?? false;
    } on MissingPluginException {
      return false;
    }
  }
}
