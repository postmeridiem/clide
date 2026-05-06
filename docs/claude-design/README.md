# clide · design handoff (superseded reference)

> **Status (2026-05-06):** Reference-only. The implementation has
> moved past these mockups. The canonical wireframe set now lives at
> [`docs/wireframes/`](../wireframes/), generated from the actual
> implementation via the `frame0-wireframe` skill.
>
> Update wireframes there, not here.
>
> **Why kept:** the design tokens under `tokens/` and `themes/` still
> feed the runtime themes (per [D-43](../../decisions/architecture.md#d-43-design-handoff-adopt-token-palettes-reject-material-wrapper)
> / [D-44](../../decisions/architecture.md#d-44-four-bundled-themes-clide-midnight-paper-terminal)).
> The HTMLs and PNGs are kept for historical context.
>
> **What changed since:** welcome screen has logo-with-wordmark and a
> Tips card spanning both columns; status line with theme switcher
> lives at the bottom right; Claude pane runs in fullscreen mode
> (`CLAUDE_CODE_NO_FLICKER=1`) so the input box is pinned by Claude
> Code itself; tmux uses an isolated `-L clide` socket with bundled
> config; sidebar layout follows D-47's "Claude is home" model.

---

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
├─ tokens/                        ← framework-free token exports
│  ├─ clide.yaml                  (default · cool near-black + periwinkle)
│  ├─ midnight.yaml               (VS Code-adjacent muted dark)
│  ├─ paper.yaml                  (drafting-sheet light)
│  ├─ terminal.yaml               (near-black + amber)
│  └─ clide_tokens.dart           (all four themes · pure `dart:ui`, no Material)
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
         then adopt the clide palette from docs/design/tokens/clide.yaml
         into our theme pipeline"
```

Claude Code can parse the HTML natively and see every token value, component, and layout annotation. The YAML files match the clide theme pipeline format; the Dart file is there as a convenience for literal-paste.

---

## Design intent, in one pass

### 1 · Typography

- **Display** — `Josefin Sans 300` for titles, section heads, and the wordmark. Light weight is load-bearing; using 400+ changes the feel entirely.
- **UI + code** — `JetBrains Mono 400/500` for everything else. Tab labels, file paths, status bar, editor. Monospace is a deliberate choice — clide is an IDE for people who like their grids.

> **Open question** — whether UI chrome text should be mono too, or reserved for code surfaces only. The hi-fi currently runs mono across the board; swapping to a prop sans in chrome is a ~5-file edit.

### 2 · Layout (classicPreset)

Three columns + statusbar. Every box in the frame is a `SlotHost` slot populated by `TabContribution`s sorted by priority (lower = leftmost tab).

```
┌────────────┬──────────────────────┬──────────────┐
│ sidebar    │ workspace            │ context      │
│ 180 px     │ flex                 │ 300 px       │
│ 160–360    │                      │ 220–420      │
├────────────┴──────────────────────┴──────────────┤
│ statusbar · 24 px                                │
└──────────────────────────────────────────────────┘
```

Sidebar navigates via a bottom **icon rail** (Files / Git / pql / Problems), not tabs at the top.

See `Wireframe.html` for the full architectural breakdown — every red-pencil annotation cites the source file it came from.

### 3 · Themes

Four presets ship by default. `clide` is the reference — the other three are variations on the same component vocabulary, differing only in palette values.

| name       | bg        | accent    | feel                          |
|------------|-----------|-----------|-------------------------------|
| `clide`    | `#20202C` | `#78A0F8` | cool near-black + periwinkle  |
| `midnight` | `#1E1E1E` | `#569CD6` | VS Code-adjacent              |
| `paper`    | `#F4F1EA` | `#C14B2A` | drafting sheet · light        |
| `terminal` | `#0A0A0A` | `#E0B050` | near-black + amber            |

All four share the same palette keys (`bg`, `surface`, `border`, `text*`, `accent`, `ok/warn/err/info`) and syntax roles. A widget written against a semantic role will render correctly in all four.

### 4 · Token shape

No Material wrapper. Tokens ship in two flavors — pick whichever your pipeline already handles.

**YAML** (preferred — matches the clide theme pipeline):

```yaml
name: clide
dark: true
palette:
  bg:          "#20202C"
  bgSunken:    "#1A1A24"
  surface:     "#242838"
  surfaceHi:   "#2C3046"
  border:      "#343850"
  borderHi:    "#3C445C"
  textHi:      "#E6E8F2"
  text:        "#B1BBE3"
  textDim:     "#78809C"
  textMute:    "#545C84"
  accent:      "#78A0F8"
  accentPress: "#6C90DC"
  accentSoft:  "rgba(120,160,248,0.13)"
  onAccent:    "#0D1020"
  ok:          "#7DD3A8"
  warn:        "#E6C370"
  err:         "#E87D7D"
  info:        "#78A0F8"
syntax:
  keyword:  "#C792EA"
  type:     "#78A0F8"
  string:   "#A8D99B"
  number:   "#E6C370"
  comment:  "#545C84"
  method:   "#82B1FF"
  punct:    "#78809C"
```

**Dart** (pure `dart:ui` — no Flutter material/cupertino imports):

```dart
import 'tokens/clide_tokens.dart';

final theme = ClideThemes.clide;
paintWith(theme.palette.accent);
highlightWith(theme.syntax.keyword);
```

`clide_tokens.dart` declares all four themes in one file — `ClideThemes.clide`, `.midnight`, `.paper`, `.terminal`, plus `.all` and `.defaultTheme`.

### 5 · Palette key reference

| key           | role                                                  |
|---------------|-------------------------------------------------------|
| `bg`          | page / editor canvas                                  |
| `bgSunken`    | sidebar, gutters, anything below the main surface     |
| `surface`     | cards, table header, pill backgrounds                 |
| `surfaceHi`   | hover / selected row                                  |
| `border`      | hairlines, dividers                                   |
| `borderHi`    | outlined controls, focus rings                        |
| `textHi`      | primary text                                          |
| `text`        | secondary labels                                      |
| `textDim`     | metadata                                              |
| `textMute`    | all-caps section labels, disabled                     |
| `accent`      | brand / primary                                       |
| `accentPress` | pressed state                                         |
| `accentSoft`  | tinted fills (13% alpha accent)                       |
| `onAccent`    | text on accent bg                                     |
| `ok/warn/err` | status                                                |
| `info`        | neutral info; often === `accent`                      |

---

## Screens in the hi-fi

| # | screen                         | purpose                                                  |
|---|--------------------------------|----------------------------------------------------------|
| 1 | **Main IDE · at rest**         | cold-start settled · all slots populated · Claude primary |
| 2 | **Claude + editor reference**  | Claude as workspace center · pinned editor in right pane  |
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

Generated by the design pass · refreshed 2026-04 · v2 (tokens-only, no Material)
