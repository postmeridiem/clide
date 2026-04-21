# Manual a11y checklist — run at every tier cut

Automated a11y tests catch structural regressions (missing Semantics,
broken contrast, missing i18n keys). They don't catch "this label is
technically correct but reads like robot noise." A 15-minute manual
pass at every tier cut does.

## Linux — Orca

1. Start Orca: `orca -s` (settings), toggle on "Focus follows mouse".
2. Launch clide: `flutter run -d linux` or the built bundle.
3. Tab through every slot in order. Every stop should read
   - panel name, then
   - a one-line verb describing what the widget does.
4. Open the command palette (`ctrl+k` once it's wired). Read each
   command out loud. Flag commands whose name alone doesn't make
   it obvious what they do.
5. Open the theme picker. Orca should announce "Select theme", then
   read each row as "theme name, activate this theme". Selecting
   announces the new theme.
6. Disconnect the daemon mid-session. Orca should announce the
   statusbar change (it's a live region).

## macOS — VoiceOver

VoiceOver: `cmd+F5`. Same checklist as Orca. Extra pass:
- Rotor navigation (`ctrl+opt+u`) should list every Semantic
  landmark; no "unknown group" entries.
- Per-element hints read cleanly when pressing `ctrl+opt+shift+h`.

## Report a drift

Any label that feels off — noise, tech jargon, abbreviations screen
readers mispronounce — becomes a follow-up ticket. Do not "fix" in
the branch being cut; queue it so each tier stays focused. File
under `docs/todo-a11y.md` (create if absent) with:

```
- [ ] ext.<id>: <key-or-widget> — <what's wrong>, <suggested wording>
```

## Why this isn't automated

Automation catches structural violations. Automation can't judge prose.
A 15-minute human pass per tier stays cheap and catches the gap.
Revisit automation (axe-core via Playwright, Flutter a11y harnesses)
if we ship a public build.
