import 'dart:io';

import 'package:clide/clide.dart';
import 'package:clide/src/editor/registry.dart';
import 'package:test/test.dart';

void main() {
  late Directory sandbox;
  late RecordingEventSink sink;
  late EditorRegistry reg;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('clide-editor-test-');
    await File('${sandbox.path}/README.md').writeAsString('# Hello\n\nbody\n');
    sink = RecordingEventSink();
    reg = EditorRegistry(events: sink, workspaceRoot: sandbox);
  });

  tearDown(() async {
    await reg.shutdown();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  test('open loads file content + emits editor.opened + active-changed', () async {
    final buf = await reg.open('README.md');
    expect(buf.content, contains('Hello'));
    expect(buf.dirty, isFalse);
    expect(reg.active, same(buf));
    expect(sink.ofKind('editor.opened'), hasLength(1));
    expect(sink.ofKind('editor.active-changed'), hasLength(1));
  });

  test('opening the same path returns the existing buffer', () async {
    final a = await reg.open('README.md');
    final b = await reg.open('README.md');
    expect(b.id, a.id);
    // Still only one open event — re-open is an activate, not a reload.
    expect(sink.ofKind('editor.opened'), hasLength(1));
  });

  test('insert at caret appends + advances cursor', () async {
    final buf = await reg.open('README.md');
    // caret at 0
    reg.insert(buf.id, 'PREFIX ');
    expect(buf.content.startsWith('PREFIX '), isTrue);
    expect(buf.selection.isCollapsed, isTrue);
    expect(buf.selection.start, 'PREFIX '.length);
    expect(buf.dirty, isTrue);
    expect(sink.ofKind('editor.edited'), hasLength(1));
  });

  test('replace-selection swaps selected text + resets cursor', () async {
    final buf = await reg.open('README.md');
    reg.setSelection(buf.id, const Selection(start: 2, end: 7)); // 'Hello'
    reg.replaceSelection(buf.id, 'WORLD');
    expect(buf.content.substring(2, 7), 'WORLD');
    expect(buf.selection, const Selection(start: 7, end: 7));
  });

  test('set-selection clamps out-of-range offsets', () async {
    final buf = await reg.open('README.md');
    reg.setSelection(buf.id, const Selection(start: -5, end: 99999));
    expect(buf.selection.start, 0);
    expect(buf.selection.end, buf.content.length);
  });

  test('save writes the content back + clears dirty', () async {
    final buf = await reg.open('README.md');
    reg.insert(buf.id, 'X');
    expect(buf.dirty, isTrue);
    final ok = await reg.save(buf.id);
    expect(ok, isTrue);
    expect(buf.dirty, isFalse);
    final onDisk = await File('${sandbox.path}/README.md').readAsString();
    expect(onDisk.startsWith('X'), isTrue);
    expect(sink.ofKind('editor.saved'), hasLength(1));
  });

  test('close picks a new active buffer when the active one closes', () async {
    final a = await reg.open('README.md');
    await File('${sandbox.path}/b.txt').writeAsString('two');
    final b = await reg.open('b.txt');
    expect(reg.active, same(b));
    reg.close(b.id);
    expect(reg.active, same(a));
    expect(sink.ofKind('editor.closed'), hasLength(1));
    // Active changed at least twice: a→b (on open), b→a (after close)
    expect(sink.ofKind('editor.active-changed').length, greaterThanOrEqualTo(2));
  });

  test('opening a non-existent path creates an empty buffer', () async {
    final buf = await reg.open('NEW.md');
    expect(buf.content, isEmpty);
    expect(buf.dirty, isFalse);
  });

  test('activate(unknown id) is a no-op; activate(known) flips the active buffer', () async {
    final a = await reg.open('README.md');
    final b = await reg.open('NEW.md');
    // b is currently active.
    expect(reg.active, same(b));
    sink.events.clear();
    reg.activate('does-not-exist'); // no-op, no emit
    expect(sink.ofKind('editor.active-changed'), isEmpty);
    reg.activate(a.id);
    expect(reg.active, same(a));
    expect(sink.ofKind('editor.active-changed'), hasLength(1));
  });

  test('setContent with explicit selection clamps + emits editor.edited replace', () async {
    final buf = await reg.open('README.md');
    sink.events.clear();
    reg.setContent(buf.id, 'short', selection: const Selection(start: 1, end: 99));
    expect(buf.content, 'short');
    // 99 clamped to content.length (5).
    expect(buf.selection.end, 5);
    expect(buf.dirty, isTrue);
    final emitted = sink.ofKind('editor.edited').single;
    expect(emitted.data['kind'], 'replace');
    expect(emitted.data['length'], 5);
  });

  test('setContent without selection clamps the existing selection to the new content', () async {
    final buf = await reg.open('README.md');
    reg.setSelection(buf.id, const Selection(start: 6, end: 8));
    expect(buf.selection.start, 6);
    reg.setContent(buf.id, 'XY'); // shorter than the selection's offsets
    expect(buf.content, 'XY');
    expect(buf.selection.start, 2);
    expect(buf.selection.end, 2);
  });

  test('setContent on a missing id is a silent no-op', () {
    sink.events.clear();
    reg.setContent('no-such-id', 'whatever');
    expect(sink.events, isEmpty);
  });

  test('contentFromArgs decodes content_b64 when text is absent', () {
    expect(EditorRegistry.contentFromArgs({'text': 'plain'}), 'plain');
    expect(
      EditorRegistry.contentFromArgs({'content_b64': 'aGVsbG8='}),
      'hello',
    );
    expect(EditorRegistry.contentFromArgs(const {}), '');
  });

  test('Selection hashCode + toString round-trip and serialise', () {
    const s = Selection(start: 3, end: 7);
    expect(s.hashCode, const Selection(start: 3, end: 7).hashCode);
    expect(s.hashCode, isNot(equals(const Selection(start: 3, end: 8).hashCode)));
    expect(s.toString(), 'Selection(3-7)');
  });

  group('.editorconfig (T-29)', () {
    test('open resolves the editorconfig for the file', () async {
      await File('${sandbox.path}/.editorconfig').writeAsString('root = true\n[*]\nindent_style = space\nindent_size = 2\n');
      final buf = await reg.open('README.md');
      expect(buf.editorConfig.indentStyle, 'space');
      expect(buf.editorConfig.indentSize, 2);
      // Exposed over IPC for the UI.
      expect(buf.toJson()['editorConfig'], {'indent_style': 'space', 'indent_size': 2, 'tab_width': 2});
    });

    test('save trims trailing whitespace + adds a final newline on disk', () async {
      await File('${sandbox.path}/.editorconfig').writeAsString('root = true\n[*]\ntrim_trailing_whitespace = true\ninsert_final_newline = true\n');
      final buf = await reg.open('README.md');
      reg.setContent(buf.id, 'line one   \nline two');
      sink.events.clear();

      await reg.save(buf.id);

      final onDisk = await File('${sandbox.path}/README.md').readAsString();
      expect(onDisk, 'line one\nline two\n');
      // The in-memory buffer reconciles to the normalized text...
      expect(buf.content, 'line one\nline two\n');
      expect(buf.dirty, isFalse);
      // ...and the UI is told to reload it.
      expect(sink.ofKind('editor.edited'), hasLength(1));
      expect(sink.ofKind('editor.saved'), hasLength(1));
    });

    test('save normalizes EOL to the configured style', () async {
      await File('${sandbox.path}/.editorconfig').writeAsString('root = true\n[*]\nend_of_line = crlf\n');
      final buf = await reg.open('README.md');
      reg.setContent(buf.id, 'a\nb\n');
      await reg.save(buf.id);
      expect(await File('${sandbox.path}/README.md').readAsString(), 'a\r\nb\r\n');
    });

    test('save without an editorconfig writes content verbatim (no extra edit event)', () async {
      final buf = await reg.open('README.md');
      reg.setContent(buf.id, 'kept   \nas-is');
      sink.events.clear();
      await reg.save(buf.id);
      expect(await File('${sandbox.path}/README.md').readAsString(), 'kept   \nas-is');
      expect(sink.ofKind('editor.edited'), isEmpty); // nothing to reconcile
      expect(sink.ofKind('editor.saved'), hasLength(1));
    });
  });
}
