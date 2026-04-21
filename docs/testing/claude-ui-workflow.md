# How Claude Code uses clide

Claude Code needs to *actually use* the app while building features.
The pipeline:

1. **Flutter builds the app to WASM.** `flutter build web --wasm` ships
   a CanvasKit/Skwasm bundle under `app/build/web/`.
2. **A local server serves it.** `tools/ui/serve.sh` starts
   `http://localhost:4280` in the background with a pidfile.
3. **Playwright drives a headless Chromium.** Instead of click-by-pixel
   — which is brittle on a CanvasKit `<canvas>` — the driver queries
   Flutter's semantic tree (`flt-semantics[aria-label=…]`), the same
   tree screen readers use. This is only reliable because every
   interactive widget in clide already ships `Semantics(label:, hint:)`
   wrappers for a11y — the automation surface is a free side-benefit.

## Claude's one-liners

```bash
# Bring the app up (builds wasm, starts server)
make ui-dev

# Run an ad-hoc probe
cd tools/ui && npx playwright test ...

# Everything in one shot (build + serve + smoke + stop)
make ui-smoke

# Bring it down
make ui-stop
```

## Writing a driver script

```ts
import { test, expect } from '@playwright/test';
import { ClideDriver } from '../driver';

test('opens the theme picker and selects summer-night', async ({ page }) => {
  const clide = new ClideDriver(page);
  await clide.goto('/');

  // Keyboard shortcut that invokes `theme.pick`:
  await page.keyboard.press('Control+K');

  // Pick via semantic label.
  await clide.click('summer-night');

  // Dump the whole tree to inspect state after an interaction.
  const tree = await clide.dumpSemanticsTree();
  console.log(JSON.stringify(tree, null, 2));

  // Screenshot into out/ (Claude reads the PNG via the Read tool).
  await clide.screenshot('out/theme-picker.png');
});
```

## Prerequisites (one-time per machine)

```bash
cd tools/ui
npm install
npx playwright install chromium
```

## Known quirks

- **Labels are merged.** Flutter web concatenates sibling Semantics
  labels into a single `aria-label` separated by newlines. `byLabel`
  uses substring match for that reason. When two Semantics nodes share
  a substring, narrow with `.filter()` on the returned locator.
- **The placeholder button.** Flutter web ships semantics disabled by
  default, behind an invisible `<flt-semantics-placeholder>` button.
  `ClideDriver.waitUntilReady()` clicks it automatically.
- **No daemon on web.** The WASM build has no unix socket; the status
  indicator always says `disconnected`. That's honest — a web-hosted
  clide has no local daemon to talk to. The Playwright flow is for
  UI-only verification.

## When Playwright is overkill

If all I need is "does the extension register its contributions," a
widget test (`test/builtin/*/widget_test.dart`) is faster and cheaper.
Reach for Playwright when the question is about the real rendering
pipeline, keyboard behavior, or multi-widget interactions that mirror
a user workflow.
