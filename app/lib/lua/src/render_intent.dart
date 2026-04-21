/// Tier-0 stub for the declarative widget DSL Lua extensions return
/// from their `on_render` callbacks.
///
/// Lua can't construct Flutter widgets; instead it returns tables like
/// `{type="list", items={...}}` or `{type="stack", children={...}}`,
/// which the Dart renderer maps to widget primitives. The vocabulary
/// is closed and documented — extensions declare intent, the shell
/// renders it with consistent theming.
///
/// The concrete intent shapes (list, tree, stack, button, text, input,
/// editor-embed) land with the Lua adapter at Tier 6.
sealed class RenderIntent {
  const RenderIntent();
}
