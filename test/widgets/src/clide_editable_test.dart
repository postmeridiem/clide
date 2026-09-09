/// Tests for [ClideEditable] — the clide text input (D-109, T-580).
///
/// These are regression guards for the three things a bare `EditableText`
/// silently does not do, and which left every clide text input feeling broken:
/// paint a selection, select by mouse drag, and offer a right-click menu.
library;

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

/// Intercepts the clipboard channel so copy is observable without a platform.
class _MockClipboard {
  Map<String, dynamic> _data = {'text': null};

  Future<Object?> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'Clipboard.setData':
        _data = Map<String, dynamic>.from(call.arguments as Map);
      case 'Clipboard.getData':
        return _data;
      case 'Clipboard.hasStrings':
        final text = _data['text'] as String?;
        return {'value': text != null && text.isNotEmpty};
    }
    return null;
  }

  String? get text => _data['text'] as String?;
}

void main() {
  late KernelFixture f;
  late _MockClipboard clipboard;
  late TextEditingController controller;
  late FocusNode focus;

  setUp(() async {
    f = await KernelFixture.create();
    clipboard = _MockClipboard();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, clipboard.handleMethodCall);
    controller = TextEditingController(text: 'hello world');
    focus = FocusNode();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    controller.dispose();
    focus.dispose();
    await f.dispose();
  });

  /// Mounts the field at a known size. The test font is monospaced at exactly
  /// `fontSize` per glyph, so `n * 14` pixels from the left edge is character
  /// `n` — which is what makes the drag assertions below exact.
  Future<Color> mount(WidgetTester tester) async {
    setSurfaceSize(tester, 800, height: 600);
    late Color token;
    await tester.pumpWidget(
      anchoredHarness(
        f,
        Builder(
          builder: (ctx) {
            token = ClideSettings.theme.of(ctx).surface.selectionBackground;
            return SizedBox(
              width: 400,
              child: ClideEditable(
                controller: controller,
                focusNode: focus,
                style: const TextStyle(fontSize: 14, height: 1),
                cursorColor: const Color(0xFFFFFFFF),
                backgroundCursorColor: const Color(0xFF888888),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    return token;
  }

  testWidgets('paints selection with the theme token instead of nothing', (tester) async {
    final token = await mount(tester);

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.selectionColor, token, reason: 'EditableText has no DefaultSelectionStyle fallback — a null here renders selection invisible');
  });

  testWidgets('a mouse drag selects text', (tester) async {
    await mount(tester);
    final origin = tester.getTopLeft(find.byType(EditableText));

    final gesture = await tester.startGesture(origin + const Offset(1, 7), kind: PointerDeviceKind.mouse);
    await tester.pump();
    await gesture.moveTo(origin + const Offset(5 * 14, 7));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(controller.selection.isCollapsed, isFalse, reason: 'a bare EditableText has no drag-select gesture at all');
    expect(controller.selection.textInside(controller.text), 'hello');
  });

  testWidgets('a double-tap selects the word under the pointer', (tester) async {
    await mount(tester);
    final origin = tester.getTopLeft(find.byType(EditableText));
    final atWorld = origin + const Offset(8 * 14, 7);

    await tester.tapAt(atWorld, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(atWorld, kind: PointerDeviceKind.mouse);
    await tester.pump();

    expect(controller.selection.textInside(controller.text), 'world');
  });

  testWidgets('right-click opens the menu under a WidgetsApp root, as the app mounts it', (tester) async {
    // The passing test below mounts a bare Overlay. The app's root is
    // ClideKernel > ClideTheme > WidgetsApp, whose Navigator owns the overlay
    // the context menu is inserted into — a different tree, and the one that
    // actually ships.
    setSurfaceSize(tester, 800, height: 600);
    await tester.pumpWidget(
      ClideKernel(
        services: f.services,
        child: ClideTheme(
          controller: f.services.theme,
          child: WidgetsApp(
            color: const Color(0xFF000000),
            pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
                PageRouteBuilder<T>(settings: settings, pageBuilder: (ctx, _, _) => builder(ctx)),
            home: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 400,
                child: ClideEditable(
                  controller: controller,
                  focusNode: focus,
                  style: const TextStyle(fontSize: 14, height: 1),
                  cursorColor: const Color(0xFFFFFFFF),
                  backgroundCursorColor: const Color(0xFF888888),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final origin = tester.getTopLeft(find.byType(EditableText));
    final drag = await tester.startGesture(origin + const Offset(1, 7), kind: PointerDeviceKind.mouse);
    await tester.pump();
    await drag.moveTo(origin + const Offset(5 * 14, 7));
    await tester.pump();
    await drag.up();
    await tester.pump();

    final rightClick = await tester.startGesture(origin + const Offset(3 * 14, 7), kind: PointerDeviceKind.mouse, buttons: kSecondaryButton);
    await rightClick.up();
    await tester.pump();

    expect(find.byType(ClideMenu), findsOneWidget);

    // Being in the tree for one frame is not being on screen. Flutter hosts the
    // menu inside the field's selection overlay and fades it in over 150ms, and
    // that overlay is torn down if the field loses focus — so a menu that took
    // focus survived exactly this assertion and nothing more, which is how it
    // shipped invisible. Pump past the fade and require it opaque and placed.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ClideMenu), findsOneWidget, reason: 'the menu dismissed itself before it finished fading in');

    final fade = tester.widget<FadeTransition>(find.ancestor(of: find.byType(ClideMenu), matching: find.byType(FadeTransition)).first);
    expect(fade.opacity.value, 1.0, reason: 'the menu never became opaque');

    final rect = tester.getRect(find.byType(ClideMenu));
    expect(rect.width, greaterThan(0));
    expect(rect.height, greaterThan(0));
    expect(const Rect.fromLTWH(0, 0, 800, 600).overlaps(rect), isTrue, reason: 'menu rendered outside the viewport at $rect');

    // The caret must still be where the user left it — that is the whole
    // reason the menu reads keys off HardwareKeyboard instead of taking focus.
    expect(focus.hasFocus, isTrue, reason: 'the context menu stole focus from the field it belongs to');
  });

  testWidgets('right-click over a selection offers Copy, which copies it', (tester) async {
    await mount(tester);
    final origin = tester.getTopLeft(find.byType(EditableText));

    // Select "hello" by dragging, then right-click inside that selection.
    final drag = await tester.startGesture(origin + const Offset(1, 7), kind: PointerDeviceKind.mouse);
    await tester.pump();
    await drag.moveTo(origin + const Offset(5 * 14, 7));
    await tester.pump();
    await drag.up();
    await tester.pump();

    final rightClick = await tester.startGesture(origin + const Offset(3 * 14, 7), kind: PointerDeviceKind.mouse, buttons: kSecondaryButton);
    await rightClick.up();
    await tester.pump();

    expect(find.byType(ClideMenu), findsOneWidget, reason: 'right-click must open clide-owned menu chrome');
    expect(find.text('Copy'), findsOneWidget);

    await tester.tap(find.text('Copy'));
    await tester.pump();

    expect(clipboard.text, 'hello');
    expect(find.byType(ClideMenu), findsNothing, reason: 'the menu dismisses after acting');
  });
}
