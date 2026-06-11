/// T-257: `panel.focusMode.exit` is bound to Escape in the contributions
/// layer, which outranks the active preset. Without a guard it swallowed Esc
/// in Vim insert mode and closed the editor instead of letting the vim preset's
/// `vim.mode.normal` (escape when vim.insert||vim.visual) return to normal mode.
/// The contribution now carries `bindingWhen: '!vim.insert && !vim.visual'`.
library;

import 'dart:io';

import 'package:clide/builtin/default_layout/default_layout.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/src/keymap/intents.dart';
import 'package:clide/kernel/src/keymap/key_chord.dart';
import 'package:clide/kernel/src/keymap/keymap.dart';
import 'package:clide/kernel/src/keymap/when_clause.dart';
import 'package:flutter/widgets.dart' show Intent;
import 'package:flutter_test/flutter_test.dart';

String? _cmd(Intent? i) => i is InvokeCommandIntent ? i.commandId : null;

void main() {
  late CommandContribution exitCmd;

  setUp(() {
    exitCmd = DefaultLayoutExtension().contributions.whereType<CommandContribution>().firstWhere((c) => c.command == 'panel.focusMode.exit');
  });

  test('focusMode.exit escape binding is guarded against vim insert/visual', () {
    expect(exitCmd.defaultBinding, 'escape');
    expect(exitCmd.bindingWhen, '!vim.insert && !vim.visual');
  });

  group('Esc resolution with the guarded binding over the vim preset', () {
    late Keymap km;

    setUp(() {
      // Real layering: vim.yaml preset (low) under a contributions layer
      // carrying the extension's actual focusMode.exit escape binding.
      final preset = KeymapLayer.fromYaml(File('assets/keymaps/vim.yaml').readAsStringSync());
      final contributions = KeymapLayer(
        name: 'contributions',
        bindings: [
          KeymapBinding.chord(
            KeyChord.parse(exitCmd.defaultBinding!),
            intent: InvokeCommandIntent(exitCmd.command),
            when: WhenExpr.tryParse(exitCmd.bindingWhen),
          ),
        ],
      );
      // Keymap flattens layers in reverse, so contributions outrank preset —
      // matching KeymapService._rebuildActive's ordering.
      km = Keymap([preset, contributions]);
    });

    Intent? esc(Map<String, bool> scope) => km.resolve(KeyChord.parse('escape'), scope);

    test('insert mode → vim.mode.normal (not panel.focusMode.exit)', () {
      expect(_cmd(esc(const {'vim.insert': true})), 'vim.mode.normal');
    });

    test('visual mode → vim.mode.normal', () {
      expect(_cmd(esc(const {'vim.visual': true})), 'vim.mode.normal');
    });

    test('normal mode → panel.focusMode.exit (Esc still exits there)', () {
      expect(_cmd(esc(const {'vim.normal': true})), 'panel.focusMode.exit');
    });

    test('non-vim preset (no vim scope) → panel.focusMode.exit', () {
      expect(_cmd(esc(const {})), 'panel.focusMode.exit');
    });
  });
}
