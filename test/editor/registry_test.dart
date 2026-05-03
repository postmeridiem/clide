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
}
