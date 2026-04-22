import 'package:clide/kernel/src/theme/loader.dart';
import 'package:clide/kernel/src/theme/resolver.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:flutter/widgets.dart';

@immutable
class ClideThemeData {
  const ClideThemeData({
    required this.name,
    required this.displayName,
    required this.dark,
    required this.surface,
  });

  final String name;
  final String displayName;
  final bool dark;
  final SurfaceTokens surface;
}

class ThemeController extends ChangeNotifier {
  ThemeController({
    required List<ThemeDefinition> bundled,
    ThemeResolver resolver = const ThemeResolver(),
    String? initialName,
  })  : _resolver = resolver,
        _defs = Map.fromEntries(bundled.map((d) => MapEntry(d.name, d))) {
    final first = initialName != null && _defs.containsKey(initialName)
        ? initialName
        : bundled.first.name;
    _currentName = first;
    _current = _build(first);
  }

  final ThemeResolver _resolver;
  final Map<String, ThemeDefinition> _defs;

  late String _currentName;
  late ClideThemeData _current;

  ClideThemeData get current => _current;
  String get currentName => _currentName;
  List<ThemeDefinition> get available => _defs.values.toList(growable: false);

  void select(String name) {
    if (!_defs.containsKey(name)) {
      throw ArgumentError('Unknown theme: $name');
    }
    if (name == _currentName) return;
    _currentName = name;
    _current = _build(name);
    notifyListeners();
  }

  void registerTheme(ThemeDefinition def) {
    _defs[def.name] = def;
    // If the user re-imported the current theme, rebuild so overrides
    // take effect without a select().
    if (def.name == _currentName) {
      _current = _build(def.name);
      notifyListeners();
    }
  }

  ClideThemeData _build(String name) {
    final def = _defs[name]!;
    final tokens = _resolver.resolve(
      palette: def.palette,
      semanticOverride: def.semanticOverride,
      surfaceOverride: def.surfaceOverride,
      extensionOverride: def.extensionOverride,
    );
    return ClideThemeData(
      name: def.name,
      displayName: def.displayName,
      dark: def.dark,
      surface: tokens,
    );
  }
}

class ClideTheme extends InheritedNotifier<ThemeController> {
  const ClideTheme({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ClideThemeData of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<ClideTheme>();
    if (w == null) {
      throw FlutterError(
          'ClideTheme.of() called with a context that is not a descendant of a ClideTheme.');
    }
    return w.notifier!.current;
  }

  static ThemeController controllerOf(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<ClideTheme>();
    if (w == null) {
      throw FlutterError(
          'ClideTheme.controllerOf() called with a context that is not a descendant of a ClideTheme.');
    }
    return w.notifier!;
  }
}
