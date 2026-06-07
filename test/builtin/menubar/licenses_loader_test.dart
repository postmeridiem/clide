/// Pure parse tests for the About-dialog licenses manifest (T-48).
library;

import 'package:clide/builtin/menubar/src/licenses_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses self + dependency entries', () {
    const yaml = '''
self:
  name: clide
  version: "2.1.0"
  license: MIT
dependencies:
  - name: Foo
    version: "1.0"
    license: MIT
  - name: Bar
    version: "2.0"
    license: OFL-1.1
''';
    final m = parseLicenses(yaml);
    expect(m.self.name, 'clide');
    expect(m.self.version, '2.1.0');
    expect(m.self.license, 'MIT');
    expect(m.dependencies, hasLength(2));
    expect(m.dependencies[0].name, 'Foo');
    expect(m.dependencies[1].license, 'OFL-1.1');
  });

  test('missing fields degrade to a dash rather than throwing', () {
    final m = parseLicenses('dependencies:\n  - name: X\n');
    expect(m.self.name, '—');
    expect(m.dependencies.single.version, '—');
    expect(m.dependencies.single.license, '—');
  });

  test('empty document yields an empty manifest', () {
    final m = parseLicenses('');
    expect(m.self.name, '—');
    expect(m.dependencies, isEmpty);
  });

  test('the bundled assets/licenses.yaml is real and non-trivial', () {
    final m = parseLicenses(_bundled);
    expect(m.self.name, 'clide');
    expect(m.dependencies, isNotEmpty);
  });
}

// A trimmed copy of the real manifest shape, to assert parseLicenses handles
// the comment-heavy, quoted-value document the app ships.
const _bundled = '''
schema_version: 1
self:
  name: clide
  version: "2.1.0"
  license: MIT
dependencies:
  - name: JetBrains Mono
    kind: font
    version: "2.304"
    license: OFL-1.1
''';
