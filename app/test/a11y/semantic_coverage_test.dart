import 'package:clide_app/builtin/default_layout/default_layout.dart';
import 'package:clide_app/builtin/ipc_status/ipc_status.dart';
import 'package:clide_app/builtin/theme_picker/theme_picker.dart';
import 'package:clide_app/builtin/welcome/welcome.dart';
import 'package:clide_app/extension/extension.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cross-extension contract check: every built-in extension declares a
/// non-empty title + version (so screen readers and the extensions-ui
/// surface can announce them) and every interactive contribution
/// carries enough data to build a Semantics node.
///
/// Per-widget Semantics-label checks live in each built-in's own
/// widget_test.dart (`test/builtin/**/widget_test.dart`) — they run
/// against a real pumped tree and assert the exact `label` + `hint`
/// reach the user. This file is the "nothing is missing from the
/// catalog" gate.
void main() {
  group('Tier-0 built-in extensions — contract-level coverage', () {
    final extensions = <ClideExtension>[
      DefaultLayoutExtension(),
      WelcomeExtension(),
      IpcStatusExtension(),
      ThemePickerExtension(),
    ];

    for (final ext in extensions) {
      group(ext.id, () {
        test('has non-empty title + version', () {
          expect(ext.title, isNotEmpty);
          expect(ext.version, isNotEmpty);
        });

        test('tab contributions carry title + i18n key + namespace', () {
          final tabs = ext.contributions.whereType<TabContribution>().toList();
          for (final t in tabs) {
            expect(t.title, isNotEmpty,
                reason: '${ext.id} tab ${t.id} missing English title');
            if (t.titleKey != null) {
              expect(t.i18nNamespace, isNotNull,
                  reason:
                      '${ext.id} tab ${t.id} has titleKey but no namespace');
            }
          }
        });

        test('command contributions carry stable ids', () {
          final cmds =
              ext.contributions.whereType<CommandContribution>().toList();
          for (final c in cmds) {
            expect(c.command, isNotEmpty);
            expect(c.id, isNotEmpty);
          }
        });
      });
    }

    test('every registered tab hits a real slot', () {
      for (final ext in extensions) {
        for (final t in ext.contributions.whereType<TabContribution>()) {
          expect(t.slot.value, isNotEmpty);
        }
      }
    });
  });
}
