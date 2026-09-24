// T-664's container check: the edge sends every request outside /auth/ past
// the broker, and the broker signs browsers in (D-117, D-118).
//
// Run it against the container, with the link `make ui-container` printed:
//   CLIDE_UI_URL=https://localhost:8443 CLIDE_UI_SIGNIN='<link>' \
//     npx playwright test --project=container
import { test, expect } from '@playwright/test';
import { ClideDriver } from '../driver';
import { signIn } from '../container';

// Caddy's internal CA is not trusted by this browser.
test.use({ ignoreHTTPSErrors: true });

test('a browser that is not signed in is sent to the sign-in page', async ({ page }) => {
  await page.goto('/u/0/w/clide/');
  await expect(page).toHaveURL(/\/auth\/login\?next=%2Fu%2F0%2Fw%2Fclide%2F$/);
  await expect(page.getByRole('heading', { name: 'Sign in to clide' })).toBeVisible();
});

test('the sign-in link signs the browser in, and the app paints', async ({ page }) => {
  await signIn(page);
  const clide = new ClideDriver(page);
  await clide.goto('/u/0/w/clide/');
  await expect(clide.button('Open folder').first()).toBeAttached();
  await expect.poll(() => clide.paintedColors(), { timeout: 60_000 }).toBeGreaterThan(16);
  expect(clide.pageErrors, clide.consoleTail()).toEqual([]);
});

test('a wrong token goes back to the sign-in page with a notice', async ({ page }) => {
  await page.goto('/auth/login');
  await page.getByLabel('Access token').fill('W'.repeat(43));
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page).toHaveURL(/\/auth\/login\?error=1/);
  await expect(page.getByRole('alert')).toHaveText('That token or link was not accepted.');
});

test("the broker's check answers Caddy alone", async ({ request }) => {
  expect((await request.get('/auth/verify')).status()).toBe(404);
});

test('signing out ends the session', async ({ page, baseURL }) => {
  await signIn(page);
  const out = await page.request.post('/auth/logout', { headers: { origin: new URL(baseURL!).origin }, maxRedirects: 0 });
  expect(out.status()).toBe(303);
  await page.goto('/u/0/w/clide/');
  await expect(page).toHaveURL(/\/auth\/login/);
});
