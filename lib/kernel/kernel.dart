/// clide kernel — registries, stores, and shared singleton services
/// consumed by every extension.
///
/// Admission rule: the kernel owns anything whose second concurrent user
/// would create incoherent state or divergent UX. External-interfacing
/// work generally belongs to extensions (git, pql, Linear);
/// external-interfacing *singletons* (OS clipboard, tray, keychain)
/// belong here.
///
/// Exports are added as each subsystem lands. See plan:
/// /home/jeroenschweitzer/.claude/plans/i-want-to-discuss-cozy-zebra.md
library;

export 'src/events/bus.dart';
export 'src/events/filter_state.dart';
export 'src/events/message_bus.dart';
export 'src/events/types.dart';
export 'src/ipc/client.dart';
export 'src/log.dart';
export 'src/file_log_sink.dart';
export 'src/watchdog.dart';
export 'src/settings.dart';
export 'src/facade.dart';
export 'src/clipboard.dart';
export 'src/commands/keybindings.dart';
export 'src/commands/palette.dart';
export 'src/commands/registry.dart';
export 'src/keymap/intents.dart';
export 'src/keymap/key_chord.dart';
export 'src/keymap/keymap.dart';
export 'src/keymap/keymap_service.dart';
export 'src/keymap/modifier_tap.dart';
export 'src/keymap/pane_key_nav.dart';
export 'src/keymap/sequence_matcher.dart';
export 'src/keymap/when_clause.dart';
export 'src/dialog.dart';
export 'src/ex_line.dart';
export 'src/extensions_manager.dart';
export 'src/file_open.dart';
export 'src/files.dart';
export 'src/focus.dart';
export 'src/i18n/catalog_loader.dart';
export 'src/i18n/fallback_chain.dart';
export 'src/i18n/i18n.dart';
export 'src/net.dart';
export 'src/notify.dart';
export 'src/os.dart';
export 'src/panels/arrangement.dart';
export 'src/project.dart';
export 'src/quick_open.dart';
export 'src/reader_nav.dart';
export 'src/recent_files.dart';
export 'src/scheduler.dart';
export 'src/text_zoom.dart';
export 'src/toast.dart';
export 'src/secrets.dart';
export 'src/tray.dart';
export 'src/panels/drag_resize.dart';
export 'src/panels/layout_preset.dart';
export 'src/panels/registry.dart';
export 'src/panels/slot_id.dart';
export 'src/panels/view_pane_snapshot.dart';
export 'src/theme/contrast.dart';
export 'src/theme/controller.dart';
export 'src/theme/loader.dart';
export 'src/theme/palette.dart';
export 'src/theme/resolver.dart';
export 'src/theme/semantic.dart';
export 'src/theme/tokens.dart';
export 'src/toolchain.dart';
export 'src/window_controls.dart';
export 'src/workspace_ref.dart';
