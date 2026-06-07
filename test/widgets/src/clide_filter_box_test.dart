/// Tests for [ClideFilterBox], focused on the CLI-addressable behaviour
/// added in T-270: an addressed box reacts to `filter.set` messages and
/// republishes its value on `filter.state`, while a plain (unaddressed)
/// box stays a kernel-free UI widget.
///
/// The box has an internal `Expanded`, so it needs a bounded-width
/// ancestor — we build a tight tree rather than the shared `harness()`
/// (whose canSizeOverlay hands unbounded width).
library;

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart' show pumpAsync;

void main() {
  late KernelFixture fixture;

  setUp(() async => fixture = await KernelFixture.create());
  tearDown(() async => fixture.dispose());

  // Tight, bounded tree with a live ClideKernel so an addressed box can
  // resolve the MessageBus.
  Future<void> mountAddressed(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: ClideKernel(
            services: fixture.services,
            child: ClideTheme(
              controller: fixture.services.theme,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: 300, height: 60, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String editableText(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText)).controller.text;

  testWidgets('filter.set drives the box: updates field, fires onChanged, reports state', (tester) async {
    String? captured;
    await mountAddressed(tester, ClideFilterBox(address: 'test.box', onChanged: (v) => captured = v));
    await pumpAsync(tester);

    fixture.services.messages.publish('test.box', 'filter.set', {'query': 'git'});
    await pumpAsync(tester);

    expect(captured, 'git', reason: 'onChanged fires for a programmatic set');
    expect(editableText(tester), 'git', reason: 'the field shows the pushed value');
    expect(fixture.services.filterStates.get('test.box'), 'git', reason: 'state is reported back for observe');
  });

  testWidgets('typing reports the value on filter.state (for observe)', (tester) async {
    await mountAddressed(tester, ClideFilterBox(address: 'test.box', onChanged: (_) {}));
    await pumpAsync(tester);
    // Initial mount reports the empty value.
    expect(fixture.services.filterStates.get('test.box'), '');

    await tester.enterText(find.byType(EditableText), 'lib');
    await tester.pump(const Duration(milliseconds: 250)); // past the 200ms debounce
    expect(fixture.services.filterStates.get('test.box'), 'lib');
  });

  testWidgets('only the addressed box reacts (addresses are isolated)', (tester) async {
    String? captured;
    await mountAddressed(tester, ClideFilterBox(address: 'test.box', onChanged: (v) => captured = v));
    await pumpAsync(tester);

    fixture.services.messages.publish('other.box', 'filter.set', {'query': 'nope'});
    await pumpAsync(tester);
    expect(captured, isNull);
    expect(editableText(tester), isEmpty);
  });

  testWidgets('the clear affordance empties the field and reports an empty value', (tester) async {
    String? captured;
    await mountAddressed(tester, ClideFilterBox(address: 'test.box', onChanged: (v) => captured = v));
    await pumpAsync(tester);

    await tester.enterText(find.byType(EditableText), 'git');
    await tester.pump(const Duration(milliseconds: 250));
    expect(captured, 'git');

    await tester.tap(find.byType(GestureDetector));
    await tester.pump();
    expect(captured, '');
    expect(editableText(tester), isEmpty);
    expect(fixture.services.filterStates.get('test.box'), '');
  });

  testWidgets('an unaddressed box needs no ClideKernel and still fires onChanged', (tester) async {
    String? captured;
    // ClideTheme is required by every box's build; ClideKernel is NOT — an
    // unaddressed box must never reach for the MessageBus. No kernel here.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: ClideTheme(
            controller: fixture.services.theme,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 300, height: 60, child: ClideFilterBox(onChanged: (v) => captured = v)),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(EditableText), 'x');
    await tester.pump(const Duration(milliseconds: 250));
    expect(captured, 'x');
  });
}
