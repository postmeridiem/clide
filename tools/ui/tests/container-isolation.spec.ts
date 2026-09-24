// T-663's done-check. The web UI's edge container (`make ui-container`,
// docker/web/) serves a workspace URL cross-origin-isolated over TLS. Skwasm's
// threads need that, through SharedArrayBuffer, and so does the clipboard (D-117).
// Every request needs a session since T-664, so each test signs in first.
//
// Run it against the container, with the link `make ui-container` printed:
//   CLIDE_UI_URL=https://localhost:8443 CLIDE_UI_SIGNIN='<link>' \
//     npx playwright test --project=container
import { test, expect } from '@playwright/test';
import { signIn } from '../container';

// Caddy's internal CA is not trusted by this browser.
test.use({ ignoreHTTPSErrors: true });

test('a workspace URL is served cross-origin-isolated over TLS', async ({ page }) => {
  await signIn(page);
  const res = await page.goto('/u/0/w/clide/');
  expect(res?.status()).toBe(200);
  expect(await page.evaluate(() => window.isSecureContext)).toBe(true);
  expect(await page.evaluate(() => crossOriginIsolated)).toBe(true);
});

test('a missing asset is a 404, not the app shell', async ({ page }) => {
  await signIn(page);
  const res = await page.request.get('/assets/no-such-file.json');
  expect(res.status()).toBe(404);
});
