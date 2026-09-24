import { test, expect } from '@playwright/test';
import { ClideDriver } from '../driver';

/**
 * Browser smoke: the WASM bundle boots, paints and shows the Welcome view,
 * with no uncaught errors on the way. The web counterpart of
 * `integration_test/app_starts_test.dart`, and CI's check that the web build
 * works rather than merely compiles (T-443, T-577).
 */
test('clide boots in the browser and paints the Welcome view', async ({ page }) => {
  const clide = new ClideDriver(page);
  await clide.goto('/');

  // The Welcome view's actions, found by accessible name in the semantics tree.
  // "Open folder" also names a File-menu entry, so this checks presence rather
  // than a count.
  await expect(clide.button('Open folder').first()).toBeAttached();
  await expect(clide.button('New project').first()).toBeAttached();
  // The status bar names the app. On web it has no host behind it yet (Epic C).
  await expect(clide.byLabel('clide ').first()).toBeAttached();

  // The semantics tree fills in even when nothing is drawn, so it can't prove
  // the page painted. Pixels can: a blank page is one flat colour.
  await expect.poll(() => clide.paintedColors(), { timeout: 60_000 }).toBeGreaterThan(16);

  // A Dart exception arrives as a bare "Exception"; the console says what it was.
  expect(clide.pageErrors, clide.consoleTail()).toEqual([]);
});
