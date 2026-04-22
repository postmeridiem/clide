# clide · design handoff

Bundle for importing into the clide repo and driving further work with Claude Code.

---

## What's in here

```
bundle/
├─ README.md                      ← this file
├─ Wireframe.html                 ← architectural snapshot of current code
├─ Wireframe - Flows.html         ← 8 interaction storyboards
├─ Clide Hi-Fi.html               ← 3 hi-fi scenes · 4 swappable themes
├─ Clide Design System.html       ← tokens · type · components · syntax
│
├─ themes/                        ← DROP-IN Dart files
│  ├─ clide_theme.dart            (default · cool near-black + periwinkle)
│  ├─ midnight_theme.dart         (VS Code-adjacent muted dark)
│  ├─ paper_theme.dart            (drafting-sheet light)
│  └─ terminal_theme.dart         (near-black + amber)
│
└─ png/                           ← flat renders for tickets / PRs
   ├─ wireframe-layout.png
   ├─ wireframe-flows.png
   ├─ design-system.png
   ├─ hifi-clide-main.png
   ├─ hifi-clide-editor.png
   ├─ hifi-clide-welcome.png
   ├─ hifi-midnight-main.png
   ├─ hifi-paper-main.png
   └─ hifi-terminal-main.png
```

All four HTML files are **fully self-contained** — fonts, JS, CSS inlined. Open them with any browser, commit them to the repo, or hand their paths to `claude` directly.

---

## Using this with Claude Code

Drop the bundle into the repo (e.g. `docs/design/`) and point Claude at it:

```bash
claude "read docs/design/README.md and docs/design/Clide\ Design\ System.html,
         then implement the Clide theme from docs/design/themes/clide_theme.dart
         so it's wired through kernel/theme.dart"
```

Claude Code can parse the HTML natively and see every token value, component, and layout annotation. It can also read the Dart theme files without conversion.

---

## Design intent, in one pass

### 1 · Typography

- **Display** — `Josefin Sans 300` for titles, section heads, and the wordmark. Light weight is load-bearing; using 400+ changes the feel entirely.
- **UI + code** — `JetBrains Mono 400/500` for everything else. Tab labels, file paths, status bar, editor. Monospace is a deliberate choice — clide is an IDE for people who like their grids.

### 2 · Layout (classicPreset)

Three columns + statusbar. Every box in the frame is a `SlotHost` slot populated by `TabContribution`s sorted by priority (lower = leftmost tab).

```
┌────────────┬──────────────────────┬──────────────┐
│ sidebar    │ workspace            │ context      │
│ 240 px     │ flex                 │ 300 px       │
│ 180–400    │                      │ 220–420      │
├────────────┴──────────────────────┴──────────────┤
│ statusbar · 24 px                                │
└──────────────────────────────────────────────────┘
```

See `Wireframe.html` for the full architectural breakdown — every red-pencil annotation cites the source file it came from.

### 3 · Themes

Four presets ship by default. `clide` is the reference — the other three are variations on the same component vocabulary, differing only in token values.

| name       | bg        | accent    | feel                          |
|------------|-----------|-----------|-------------------------------|
| `clide`    | `#20202C` | `#78A0F8` | cool near-black + periwinkle  |
| `midnight` | `#1E1E1E` | `#569CD6` | VS Code-adjacent              |
| `paper`    | `#F4F1EA` | `#C14B2A` | drafting sheet · light        |
| `terminal` | `#0A0A0A` | `#E0B050` | near-black + amber            |

All four share the same semantic token names (`bg`, `surface`, `border`, `text`, `accent`, `ok/warn/err/info`, syntax roles). A widget written against the tokens will render correctly in all four.

### 4 · Drop-in usage

```dart
import 'themes/clide_theme.dart';

MaterialApp(
  theme: ClideTheme.data,
  home: const ClideApp(),
);
```

The `ClideTheme.tokens` object exposes semantic colors for cases where a Material widget can't carry the meaning — e.g. syntax highlighting, git status markers, Claude message kinds.

---

## Screens in the hi-fi

| # | screen                         | purpose                                                  |
|---|--------------------------------|----------------------------------------------------------|
| 1 | **Main IDE · at rest**         | cold-start settled · all slots populated · Claude primary |
| 2 | **Editor · with Claude panel** | file editor in workspace · Claude as context-column tab   |
| 3 | **Welcome · no project**       | first-run landing · start actions + recent projects       |

Open `Clide Hi-Fi.html` and use the floating Tweaks panel (bottom-right, toggle from the toolbar) to swap between themes live.

---

## Flows not yet realized

From `Wireframe - Flows.html` — things with commands/contracts wired but no UI yet:

- **Project picker** (cold start with no `lastProject`)
- **Multi-buffer editor tabs** (editor is single-buffer today)
- **Toolbar slot** (`Slots.toolbar` reserved, no preset renders it)
- **Command palette keybinding** (`⌘⇧P` not bound by default)
- **Secondary Claude panes** (command exists; UI wiring pending)

These are the highest-leverage next design targets.

---

## File integrity

All HTMLs render offline, no network required after first open. Fonts are bundled as CSS and fall back to system monospace if Josefin Sans or JetBrains Mono are blocked.

Generated by the design pass · refreshed 2026-04
