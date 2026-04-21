import { test, expect } from '@playwright/test';
import { ClideDriver } from '../driver';

/**
 * Browser smoke: boot the WASM bundle and verify the Welcome view +
 * statusbar indicator + daemon-disconnected label all render. This is
 * the "app actually works in a real browser" regression gate — the web
 * counterpart of `integration_test/app_starts_test.dart`.
 */
test('clide boots in the browser, welcome + statusbar visible', async ({ page }) => {
  const clide = new ClideDriver(page);
  await clide.goto('/');

  // Semantics nodes are attached even when their rendered canvas is
  // visually covered by the Flutter glass-pane; assert "attached" for
  // the automation contract — we're reading the tree, not asserting
  // rendering.
  const openProject = clide.byLabel('Open project');
  await expect(openProject).toHaveCount(1);

  const disconnected = clide.byLabel('disconnected');
  await expect(disconnected.first()).toBeAttached();
});
