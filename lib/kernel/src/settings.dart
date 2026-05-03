import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:yaml/yaml.dart';

enum SettingsScope { app, project, ext }

class SettingsStore extends ChangeNotifier {
  SettingsStore({required this.appDir, this.projectDir});

  final Directory appDir;
  Directory? projectDir;

  final Map<String, Object?> _appValues = <String, Object?>{};
  final Map<String, Object?> _projectValues = <String, Object?>{};

  Future<void> load() async {
    _appValues
      ..clear()
      ..addAll(await _readFile(_appFile));
    _projectValues.clear();
    if (projectDir != null) {
      _projectValues.addAll(await _readFile(_projectFile));
    }
    notifyListeners();
  }

  Future<void> setProjectDir(Directory? dir) async {
    projectDir = dir;
    _projectValues.clear();
    if (dir != null) {
      _projectValues.addAll(await _readFile(_projectFile));
    }
    notifyListeners();
  }

  File get _appFile => File('${appDir.path}/settings.yaml');
  File get _projectFile => File('${projectDir!.path}/.clide/settings.yaml');

  T? get<T>(String key) {
    final v = _lookup(key);
    if (v is T) return v;
    if (T == int && v is num) return v.toInt() as T;
    if (T == double && v is num) return v.toDouble() as T;
    return null;
  }

  Object? _lookup(String key) {
    switch (_scopeOf(key)) {
      case SettingsScope.app:
        return _appValues[key];
      case SettingsScope.project:
        return _projectValues[key];
      case SettingsScope.ext:
        // project overrides app for the same ext.* key
        return _projectValues.containsKey(key) ? _projectValues[key] : _appValues[key];
    }
  }

  Future<void> set<T>(String key, T value) async {
    switch (_scopeOf(key)) {
      case SettingsScope.app:
        _appValues[key] = value;
        await _writeFile(_appFile, _appValues);
      case SettingsScope.project:
        if (projectDir == null) {
          throw StateError('Cannot set project-scoped key with no project open: $key');
        }
        _projectValues[key] = value;
        await _writeFile(_projectFile, _projectValues);
      case SettingsScope.ext:
        // default: store under app until an ext manifest requests project scope
        _appValues[key] = value;
        await _writeFile(_appFile, _appValues);
    }
    notifyListeners();
  }

  Future<Map<String, Object?>> _readFile(File f) async {
    try {
      if (!await f.exists()) return <String, Object?>{};
      final txt = await f.readAsString();
      if (txt.trim().isEmpty) return <String, Object?>{};
      final yaml = loadYaml(txt);
      final out = <String, Object?>{};
      if (yaml is Map) _flatten(yaml, '', out);
      return out;
    } catch (_) {
      // On web (or in sandboxes where the path isn't writable) silently
      // degrade to an empty in-memory catalog. `set` will no-op too.
      return <String, Object?>{};
    }
  }

  Future<void> _writeFile(File f, Map<String, Object?> flat) async {
    try {
      await f.parent.create(recursive: true);
      await f.writeAsString(_emitYaml(_unflatten(flat)));
    } catch (_) {
      // Web / read-only sandbox: in-memory update remains valid, we
      // just can't persist. Callers already called notifyListeners.
    }
  }

  static SettingsScope _scopeOf(String key) {
    if (key.startsWith('app.')) return SettingsScope.app;
    if (key.startsWith('project.')) return SettingsScope.project;
    if (key.startsWith('ext.')) return SettingsScope.ext;
    throw ArgumentError('Settings key must start with app.|project.|ext.: "$key"');
  }
}

void _flatten(Map src, String prefix, Map<String, Object?> into) {
  src.forEach((k, v) {
    final key = prefix.isEmpty ? '$k' : '$prefix.$k';
    if (v is Map) {
      _flatten(v, key, into);
    } else if (v is YamlList) {
      into[key] = v.toList();
    } else {
      into[key] = v;
    }
  });
}

Map<String, Object?> _unflatten(Map<String, Object?> flat) {
  final root = <String, Object?>{};
  flat.forEach((k, v) {
    final parts = k.split('.');
    var cursor = root;
    for (var i = 0; i < parts.length - 1; i++) {
      final next = cursor[parts[i]];
      if (next is Map<String, Object?>) {
        cursor = next;
      } else {
        final fresh = <String, Object?>{};
        cursor[parts[i]] = fresh;
        cursor = fresh;
      }
    }
    cursor[parts.last] = v;
  });
  return root;
}

String _emitYaml(Object? value, {int indent = 0}) {
  final buf = StringBuffer();
  _emit(buf, value, indent);
  return buf.toString();
}

void _emit(StringBuffer buf, Object? v, int indent) {
  final pad = '  ' * indent;
  if (v is Map) {
    if (v.isEmpty) {
      buf.writeln('{}');
      return;
    }
    v.forEach((k, vv) {
      buf.write('$pad$k:');
      if (vv is Map && vv.isNotEmpty) {
        buf.writeln();
        _emit(buf, vv, indent + 1);
      } else if (vv is List && vv.isNotEmpty) {
        buf.writeln();
        for (final item in vv) {
          buf.write('$pad- ');
          _emitScalar(buf, item);
          buf.writeln();
        }
      } else {
        buf.write(' ');
        _emitScalar(buf, vv);
        buf.writeln();
      }
    });
    return;
  }
  _emitScalar(buf, v);
  buf.writeln();
}

void _emitScalar(StringBuffer buf, Object? v) {
  if (v == null) {
    buf.write('null');
  } else if (v is bool || v is num) {
    buf.write(v);
  } else if (v is String) {
    if (_needsQuoting(v)) {
      buf.write('"${v.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"');
    } else {
      buf.write(v);
    }
  } else if (v is List) {
    buf.write('[');
    for (var i = 0; i < v.length; i++) {
      if (i > 0) buf.write(', ');
      _emitScalar(buf, v[i]);
    }
    buf.write(']');
  } else {
    buf.write('"${v.toString()}"');
  }
}

bool _needsQuoting(String s) {
  if (s.isEmpty) return true;
  if (RegExp(r'[:\#\n\r\t]').hasMatch(s)) return true;
  if (s != s.trim()) return true;
  const reserved = {'true', 'false', 'null', 'yes', 'no', 'on', 'off', '~'};
  if (reserved.contains(s.toLowerCase())) return true;
  if (num.tryParse(s) != null) return true;
  return false;
}
