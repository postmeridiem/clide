import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' as flutter_services;

/// Typed, per-content-kind clipboard with a plaintext fallback.
///
/// Extensions write typed values (`write<GitHunk>(hunk)`) and read in
/// the same type (`readAs<GitHunk>()`). Anything with a `toPlain`
/// callback also syncs to the OS clipboard so external apps see
/// reasonable text. The history ring keeps the last [historyLimit]
/// entries per type for quick recall.
class ClideClipboard {
  ClideClipboard({this.historyLimit = 16});

  final int historyLimit;
  final Map<Type, List<Object>> _history = {};

  Future<void> write<T extends Object>(
    T value, {
    String Function(T)? toPlain,
  }) async {
    final bucket = _history.putIfAbsent(T, () => <Object>[]);
    bucket.insert(0, value);
    if (bucket.length > historyLimit) bucket.removeLast();
    if (toPlain != null) {
      await flutter_services.Clipboard.setData(flutter_services.ClipboardData(text: toPlain(value)));
    }
  }

  T? readAs<T extends Object>() {
    final bucket = _history[T];
    if (bucket == null || bucket.isEmpty) return null;
    return bucket.first as T;
  }

  List<T> historyOf<T extends Object>() {
    final bucket = _history[T];
    if (bucket == null) return const [];
    return bucket.cast<T>().toList(growable: false);
  }

  Future<String?> readPlain() async {
    final d = await flutter_services.Clipboard.getData('text/plain');
    return d?.text;
  }

  Future<void> writePlain(String text) async {
    await flutter_services.Clipboard.setData(flutter_services.ClipboardData(text: text));
    final bucket = _history.putIfAbsent(String, () => <Object>[]);
    bucket.insert(0, text);
    if (bucket.length > historyLimit) bucket.removeLast();
  }

  @visibleForTesting
  void clear() => _history.clear();
}
