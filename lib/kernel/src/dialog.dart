import 'dart:async';

import 'package:flutter/widgets.dart';

typedef DialogBuilder<T> = Widget Function(
  BuildContext context,
  void Function([T? result]) dismiss,
);

/// Single-at-a-time modal router.
///
/// Extensions call [show] with a builder; the root widget (installed by
/// [DialogHost]) listens and renders the current dialog over a dimmed
/// backdrop. Only one dialog is active at a time — a second [show] call
/// while one is open awaits until the first dismisses.
class DialogRouter extends ChangeNotifier {
  DialogBuilder<Object?>? _current;
  Completer<Object?>? _completer;
  final List<_Queued> _queue = [];

  DialogBuilder<Object?>? get current => _current;
  bool get isOpen => _current != null;

  Future<T?> show<T extends Object>(DialogBuilder<T> builder) {
    final completer = Completer<T?>();
    final wrapped = _wrap<T>(builder);
    if (_current == null) {
      _current = wrapped;
      _completer = Completer<Object?>();
      // forward our generic completer to the typed one
      _completer!.future.then((v) {
        if (!completer.isCompleted) completer.complete(v as T?);
      });
      notifyListeners();
    } else {
      _queue.add(_Queued(wrapped, completer));
    }
    return completer.future;
  }

  void dismiss([Object? result]) {
    if (_current == null) return;
    final c = _completer;
    _current = null;
    _completer = null;
    if (c != null && !c.isCompleted) c.complete(result);
    if (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      _current = next.builder;
      _completer = Completer<Object?>();
      _completer!.future.then((v) {
        if (!next.completer.isCompleted) next.completer.complete(v);
      });
    }
    notifyListeners();
  }

  DialogBuilder<Object?> _wrap<T>(DialogBuilder<T> builder) {
    return (ctx, dismiss) => builder(ctx, ([T? v]) => dismiss(v));
  }
}

class _Queued {
  _Queued(this.builder, this.completer);
  final DialogBuilder<Object?> builder;
  // ignore: strict_raw_type
  final Completer completer;
}

/// Hosts the current dialog from [DialogRouter]. Place high in the tree
/// (inside the WidgetsApp) so dialogs overlay every other surface.
class DialogHost extends StatelessWidget {
  const DialogHost({
    super.key,
    required this.router,
    required this.child,
    this.backdropColor = const Color(0xC0000000),
  });

  final DialogRouter router;
  final Widget child;
  final Color backdropColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        ListenableBuilder(
          listenable: router,
          builder: (ctx, _) {
            final b = router.current;
            if (b == null) return const SizedBox.shrink();
            return Positioned.fill(
              child: ColoredBox(
                color: backdropColor,
                child: Center(
                  child: b(ctx, router.dismiss),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
