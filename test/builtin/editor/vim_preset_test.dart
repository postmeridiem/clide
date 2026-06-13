/// T-65: the shipped Vim preset. Loads the real assets/keymaps/vim.yaml
/// and asserts representative bindings resolve in the right mode — motions,
/// the i→insert / Esc→normal / v→visual mode changes, a dd sequence, a
/// shifted capital (G), and that app shortcuts (palette) survive.
library;

import 'dart:io';

import 'package:clide/kernel/src/keymap/intents.dart';
import 'package:clide/kernel/src/keymap/key_chord.dart';
import 'package:clide/kernel/src/keymap/keymap.dart';
import 'package:clide/kernel/src/keymap/sequence_matcher.dart';
import 'package:flutter/widgets.dart' show Intent;
import 'package:flutter_test/flutter_test.dart';

String? _cmd(Intent? i) => i is InvokeCommandIntent ? i.commandId : null;

void main() {
  late Keymap km;
  setUp(() {
    final src = File('assets/keymaps/vim.yaml').readAsStringSync();
    km = Keymap([KeymapLayer.fromYaml(src)]);
  });

  // Editor-focused normal mode: j/k/h/l/gg/G/o are buffer motions here because
  // the `editor.focused` flag suppresses the pane-nav bindings (T-406).
  const normal = {'vim.normal': true, 'editor.focused': true};
  const insert = {'vim.insert': true};
  const visual = {'vim.visual': true};
  // A non-editor pane focused under vim normal mode: the same keys are nav.*.
  const paneNormal = {'vim.normal': true};

  Intent? resolve(String chord, Map<String, bool> scope) => km.resolve(KeyChord.parse(chord), scope);

  test('motions resolve in normal mode', () {
    expect(_cmd(resolve('j', normal)), 'editor.vim.down');
    expect(_cmd(resolve('h', normal)), 'editor.vim.left');
    expect(_cmd(resolve('w', normal)), 'editor.vim.wordForward');
    expect(_cmd(resolve('0', normal)), 'editor.vim.lineStart');
  });

  test('capitals (shifted) resolve', () {
    expect(_cmd(resolve('shift+g', normal)), 'editor.vim.docEnd');
    expect(_cmd(resolve('shift+d', normal)), 'editor.vim.deleteToEnd');
    expect(_cmd(resolve('shift+a', normal)), 'editor.vim.appendLineEnd');
  });

  test('motions also resolve in visual mode', () {
    expect(_cmd(resolve('l', visual)), 'editor.vim.right');
    expect(_cmd(resolve('w', visual)), 'editor.vim.wordForward');
  });

  test('mode changes', () {
    expect(_cmd(resolve('i', normal)), 'editor.vim.insert');
    expect(_cmd(resolve('v', normal)), 'vim.mode.visual');
    expect(_cmd(resolve('escape', insert)), 'vim.mode.normal');
    expect(_cmd(resolve('escape', visual)), 'vim.mode.normal');
  });

  test('normal-mode i does not fire in visual mode', () {
    expect(resolve('i', visual), isNull);
  });

  test('visual operators resolve only in visual mode', () {
    expect(_cmd(resolve('y', visual)), 'editor.vim.visualYank');
    expect(_cmd(resolve('d', visual)), 'editor.vim.visualDelete'); // single d in visual
  });

  test('app shortcuts survive under the vim preset', () {
    expect(resolve('ctrl+shift+p', normal), isA<PaletteOpenIntent>());
    expect(resolve('ctrl+shift+f', insert), isA<FindInFilesIntent>());
  });

  test('dd / dw sequences resolve through the matcher in normal mode', () {
    final m = SequenceMatcher(keymap: () => km, context: () => normal);
    expect(m.feed(KeyChord.parse('d')).outcome, SeqOutcome.pending);
    final r = m.feed(KeyChord.parse('d'));
    expect(_cmd(r.intent), 'editor.vim.deleteLine');

    m.reset();
    m.feed(KeyChord.parse('d'));
    expect(_cmd(m.feed(KeyChord.parse('w')).intent), 'editor.vim.deleteWord');
  });

  test('gg sequence resolves to docStart', () {
    final m = SequenceMatcher(keymap: () => km, context: () => normal);
    expect(m.feed(KeyChord.parse('g')).outcome, SeqOutcome.pending);
    expect(_cmd(m.feed(KeyChord.parse('g')).intent), 'editor.vim.docStart');
  });

  group('pane navigation (T-406)', () {
    test('motion keys resolve to nav.* when a non-editor pane is focused', () {
      expect(resolve('j', paneNormal), isA<NavDownIntent>());
      expect(resolve('k', paneNormal), isA<NavUpIntent>());
      expect(resolve('h', paneNormal), isA<NavCollapseOrLeftIntent>());
      expect(resolve('l', paneNormal), isA<NavExpandOrRightIntent>());
      expect(resolve('ctrl+d', paneNormal), isA<NavPageDownIntent>());
      expect(resolve('ctrl+u', paneNormal), isA<NavPageUpIntent>());
      expect(resolve('shift+g', paneNormal), isA<NavBottomIntent>());
      expect(resolve('o', paneNormal), isA<NavActivateIntent>());
      expect(resolve('enter', paneNormal), isA<NavActivateIntent>());
    });

    test('the editor.focused guard hands the same keys to the editor', () {
      // With the editor focused, nav.* is suppressed and the buffer motions win.
      expect(_cmd(resolve('j', normal)), 'editor.vim.down');
      expect(_cmd(resolve('h', normal)), 'editor.vim.left');
      expect(_cmd(resolve('l', normal)), 'editor.vim.right');
      expect(_cmd(resolve('shift+g', normal)), 'editor.vim.docEnd');
      expect(_cmd(resolve('o', normal)), 'editor.vim.openBelow');
    });

    test('gg resolves to nav.top in a pane, docStart in the editor', () {
      final pane = SequenceMatcher(keymap: () => km, context: () => paneNormal);
      pane.feed(KeyChord.parse('g'));
      expect(pane.feed(KeyChord.parse('g')).intent, isA<NavTopIntent>());

      final editor = SequenceMatcher(keymap: () => km, context: () => normal);
      editor.feed(KeyChord.parse('g'));
      expect(_cmd(editor.feed(KeyChord.parse('g')).intent), 'editor.vim.docStart');
    });

    test('pane nav is normal-mode only — visual mode keeps the editor motion', () {
      // nav.* is guarded `vim.normal && !editor.focused`; visual mode has no
      // vim.normal flag, so j stays the editor motion even without editor.focused.
      expect(_cmd(resolve('j', visual)), 'editor.vim.down');
    });
  });

  group('ctrl+w window family (T-404)', () {
    SequenceMatcher matcher([Keymap? k]) => SequenceMatcher(keymap: () => k ?? km, context: () => normal, captureCounts: false);

    Intent? seq(SequenceMatcher m, List<String> chords) {
      SeqResult? r;
      for (final c in chords) {
        r = m.feed(KeyChord.parse(c));
      }
      return r?.intent;
    }

    test('ctrl+w h/l/j/o resolve to the panel commands', () {
      expect(_cmd(seq(matcher(), ['ctrl+w', 'h'])), 'panel.focus.left');
      expect(_cmd(seq(matcher(), ['ctrl+w', 'l'])), 'panel.focus.right');
      expect(_cmd(seq(matcher(), ['ctrl+w', 'j'])), 'dock.toggle');
      expect(_cmd(seq(matcher(), ['ctrl+w', 'o'])), 'panel.focusMode');
    });

    test('ctrl+w w and ctrl+w ctrl+w cycle panels; shift+w cycles back', () {
      expect(seq(matcher(), ['ctrl+w', 'w']), isA<FocusNextPanelIntent>());
      expect(seq(matcher(), ['ctrl+w', 'ctrl+w']), isA<FocusNextPanelIntent>());
      expect(seq(matcher(), ['ctrl+w', 'shift+w']), isA<FocusPreviousPanelIntent>());
    });

    test('ctrl+w q and ctrl+w c close the editor', () {
      expect(_cmd(seq(matcher(), ['ctrl+w', 'q'])), 'editor.close');
      expect(_cmd(seq(matcher(), ['ctrl+w', 'c'])), 'editor.close');
    });

    test('bare ctrl+w is a live prefix; the timeout flush fires editor.close', () {
      // editor.close's bare ctrl+w binding comes from the default-layout
      // contributions layer, which sits under the preset in the real app.
      final layered = Keymap([
        KeymapLayer.fromYaml(File('assets/keymaps/vim.yaml').readAsStringSync()),
        KeymapLayer(
          name: 'contrib',
          bindings: [KeymapBinding.chord(KeyChord.parse('ctrl+w'), intent: const InvokeCommandIntent('editor.close'))],
        ),
      ]);
      final m = matcher(layered);
      expect(m.feed(KeyChord.parse('ctrl+w')).outcome, SeqOutcome.pending);
      expect(_cmd(m.flush().intent), 'editor.close'); // bare ctrl+w → close, after the wait
    });

    test('ctrl+w sequences need vim.normal/visual — inert under no vim scope', () {
      final m = SequenceMatcher(keymap: () => km, context: () => const {}, captureCounts: false);
      // With no vim scope, ctrl+w isn't a sequence prefix here, so the first
      // chord doesn't pend on the family.
      expect(m.feed(KeyChord.parse('ctrl+w')).outcome, isNot(SeqOutcome.fired));
      expect(seq(matcher(km), ['ctrl+w', 'h']), isNotNull); // but it does under vim.normal
    });
  });
}
