import 'dart:ui';

import 'package:flutter/foundation.dart';

@immutable
class SemanticRoles {
  const SemanticRoles(this._roles);
  final Map<String, Color> _roles;

  Color? lookup(String role) => _roles[role];
  Iterable<String> get roles => _roles.keys;
}

abstract class SemanticKeys {
  static const mainchrome = 'mainchrome';
  static const calltoaction = 'calltoaction';
  static const focus = 'focus';
  static const background = 'background';
  static const surface = 'surface';
  static const text = 'text';
  static const textMuted = 'text_muted';
  static const success = 'success';
  static const warning = 'warning';
  static const error = 'error';
  static const info = 'info';

  static const all = <String>[
    mainchrome,
    calltoaction,
    focus,
    background,
    surface,
    text,
    textMuted,
    success,
    warning,
    error,
    info,
  ];
}
