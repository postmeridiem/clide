import 'package:clide_app/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EventBus', () {
    late EventBus bus;

    setUp(() => bus = EventBus());
    tearDown(() => bus.dispose());

    test('emit delivers to stream subscribers', () async {
      final events = <ClideEventEnvelope>[];
      final sub = bus.stream.listen(events.add);
      bus.emit(const ThemeChanged(themeName: 'summer-night'));
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      expect(events.first.event, isA<ThemeChanged>());
      await sub.cancel();
    });

    test('on<T>() filters by runtime type', () async {
      final themes = <ThemeChanged>[];
      final extensions = <ExtensionActivated>[];
      final s1 = bus.on<ThemeChanged>().listen(themes.add);
      final s2 = bus.on<ExtensionActivated>().listen(extensions.add);
      bus.emit(const ThemeChanged(themeName: 'a'));
      bus.emit(const ExtensionActivated(id: 'builtin.git'));
      bus.emit(const ThemeChanged(themeName: 'b'));
      await Future<void>.delayed(Duration.zero);
      expect(themes.map((e) => e.themeName), ['a', 'b']);
      expect(extensions.map((e) => e.id), ['builtin.git']);
      await s1.cancel();
      await s2.cancel();
    });

    test('broadcasts to multiple listeners independently', () async {
      final a = <ClideEvent>[];
      final b = <ClideEvent>[];
      final s1 = bus.stream.listen((e) => a.add(e.event));
      final s2 = bus.stream.listen((e) => b.add(e.event));
      bus.emit(const ThemeChanged(themeName: 'x'));
      await Future<void>.delayed(Duration.zero);
      expect(a, hasLength(1));
      expect(b, hasLength(1));
      await s1.cancel();
      await s2.cancel();
    });

    test('emit after dispose is a silent no-op', () async {
      await bus.dispose();
      // must not throw
      bus.emit(const ThemeChanged(themeName: 'nope'));
    });

    test('envelope stamps a timestamp', () async {
      final capture = <ClideEventEnvelope>[];
      final sub = bus.stream.listen(capture.add);
      final before = DateTime.now().toUtc();
      bus.emit(const ThemeChanged(themeName: 'n'));
      await Future<void>.delayed(Duration.zero);
      final after = DateTime.now().toUtc();
      expect(capture, hasLength(1));
      final ts = capture.first.timestamp;
      expect(ts.isAfter(before) || ts.isAtSameMomentAs(before), isTrue);
      expect(ts.isBefore(after) || ts.isAtSameMomentAs(after), isTrue);
      await sub.cancel();
    });
  });
}
