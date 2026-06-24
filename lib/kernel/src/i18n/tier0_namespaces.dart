/// Canonical list of Tier-0 i18n namespaces preloaded at boot — the single
/// source of truth (T-371).
///
/// `lib/main.dart` preloads exactly these (framework chrome under `core`, plus
/// the catalogs of the built-ins that activate at Tier 0); the i18n coverage
/// gate validates every one of them. The other ~17 catalogs that ship belong
/// to built-ins that activate lazily in later tiers — their catalogs load on
/// activation, and the gate validates them through the assets-dir sweep rather
/// than this preload list.
library;

/// Namespaces whose catalogs are loaded at boot, before any extension that
/// owns them has activated. `core` holds framework chrome that lives outside
/// any extension (lib/widgets, lib/kernel, shared reader chrome — T-469).
const List<String> kTier0Namespaces = [
  'core',
  'builtin.default-layout',
  'builtin.welcome',
  'builtin.ipc-status',
  'builtin.theme-picker',
  'builtin.terminal',
  'builtin.files',
  'builtin.claude',
  'builtin.editor',
];
