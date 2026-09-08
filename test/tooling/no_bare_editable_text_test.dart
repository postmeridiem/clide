/// Guard the "no bare `EditableText` under `lib/`" rule from D-109.
///
/// A bare `EditableText` fails inert, which is what let clide ship 17 of them:
/// with no `selectionColor` it paints selection invisibly (there is no
/// `DefaultSelectionStyle` fallback), with no gesture detector it cannot be
/// drag-selected, and with no `contextMenuBuilder` it has no right-click menu.
/// Nothing throws, nothing warns, and the field looks fine until you try to
/// select text in it.
///
/// [ClideEditable] supplies all three, so the rule is that every text input
/// goes through it — and the only `EditableText` in the tree is the one inside
/// it. Structural, because a reviewer cannot see the absence of a property.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// The single file allowed to construct an `EditableText` directly.
const _wrapper = 'lib/widgets/src/clide_editable.dart';

void main() {
  test('no bare EditableText outside ClideEditable (D-109)', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path;
      if (path == _wrapper) continue;
      // Match construction only. A doc comment naming the class, or a type
      // annotation like `GlobalKey<EditableTextState>`, is not a call site.
      if (RegExp(r'(^|[^\w])EditableText\(').hasMatch(entity.readAsStringSync())) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These construct EditableText directly and so ship without a visible '
          'selection, drag-select, or a context menu. Use ClideEditable:\n'
          '${offenders.join('\n')}',
    );
  });

  test('the wrapper itself still wraps an EditableText', () {
    // Guards the guard: if ClideEditable stopped using EditableText, the rule
    // above would pass vacuously across a tree with no text input at all.
    expect(File(_wrapper).readAsStringSync(), contains('EditableText('));
  });
}
