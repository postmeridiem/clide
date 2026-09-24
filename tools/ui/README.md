# clide UI harness

A Playwright-based driver that drives the Flutter WASM build of clide
through its semantic DOM tree (the same tree screen readers use).
Used by Claude Code to "actually use the app" without screenshot
round-trips, and by CI to catch web-regression bugs.

## One-time setup

```bash
cd tools/ui
npm install
npx playwright install chromium
```

## Dev loop

```bash
# From repo root:
make ui-dev                       # build web + start local server :4280
cd tools/ui && npx playwright test --project=chromium

# When done:
make ui-stop                       # kill the local server
```

Or the one-shot smoke:

```bash
make ui-smoke                      # build + serve + run smoke + stop
```

## Driver surface

```ts
import { ClideDriver } from '../driver';

test('...', async ({ page }) => {
  const clide = new ClideDriver(page);
  await clide.goto('/');

  await clide.button('New project').click();
  await clide.type('Name', 'My project');
  const text = await clide.readText('clide ');

  await clide.screenshot('out/my-state.png');
  const tree = await clide.dumpSemanticsTree();
  const colors = await clide.paintedColors(); // 1 = nothing was drawn
  expect(clide.pageErrors, clide.consoleTail()).toEqual([]);
});
```

All lookups go through Flutter's semantics tree (`flt-semantics[aria-label]`).
This only works because every interactive widget in clide emits a
`Semantics(label:, hint:, button:)` wrapper — a requirement that's baked
in for screen-reader support and gets enforced by
`test/a11y/semantic_coverage_test.dart`.

## CI

`make test-e2e` runs as the `web-e2e` job in `.github/workflows/test.yml`. It
builds the WASM bundle, serves it, runs every spec in the `chromium` project,
and cleans up. The bundle has to boot, paint and show the Welcome view with no
uncaught page errors.

What the harness relies on:
- Headless Chromium has no GPU. `playwright.config.ts` turns on software
  WebGL so CI renders through WebGL, as users do. Without WebGL, Flutter still
  paints, but through its CPU-only fallback.
- Semantics come from the framework, not the renderer. With Flutter's surface
  hidden, every semantics assertion still passes, so the smoke also checks
  pixels (`paintedColors()`).
- A Dart exception reaches the page as a bare `Exception`, and its message
  goes to the console. Failures print the recent console lines
  (`consoleTail()`).

Specs named `container-*.spec.ts` run against the edge container instead.
Start it with `make ui-container`, which prints a sign-in link. Then run the
`container` project with `CLIDE_UI_URL=https://localhost:8443` and that link
in `CLIDE_UI_SIGNIN`. Every request to the container needs a session, so each
spec signs in first (`container.ts`).
