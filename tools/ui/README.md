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
cd tools/ui && npx playwright test

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

  await clide.click('Open project');
  await clide.type('Name', 'My project');
  const text = await clide.readText('disconnected');

  await clide.screenshot('out/my-state.png');
  const tree = await clide.dumpSemanticsTree();
});
```

All lookups go through Flutter's semantics tree (`flt-semantics[aria-label]`).
This only works because every interactive widget in clide emits a
`Semantics(label:, hint:, button:)` wrapper — a requirement that's baked
in for screen-reader support and gets enforced by
`test/a11y/semantic_coverage_test.dart`.

## CI

`make ui-smoke` is the CI entry — builds the WASM bundle, runs the
harness, cleans up. Enabling Gitea Actions will start running this on
every push.
