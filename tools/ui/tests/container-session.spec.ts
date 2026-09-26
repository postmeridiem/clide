// T-664's container check for sessions: a signed-in page's WebSocket reaches
// its workspace's host through Caddy and the broker, byte for byte (D-117).
// Until the real host exists (C4) the image runs a stub that greets each
// session with the workspace's name and echoes what it receives.
//
// `make ui-container` mounts a projects folder with one workspace, demo. Run
// it with the link that target printed:
//   CLIDE_UI_URL=https://localhost:8443 CLIDE_UI_SIGNIN='<link>' \
//     npx playwright test --project=container
import { test, expect, type Page } from '@playwright/test';
import { signIn } from '../container';

// Caddy's internal CA is not trusted by this browser.
test.use({ ignoreHTTPSErrors: true });

/**
 * Opens `/u/0/w/<slug>/session` from [page], sends `ping\n`, and answers what
 * came back once the echo arrives, or how the socket closed if it did first.
 */
async function session(page: Page, slug: string): Promise<string> {
  return page.evaluate(
    (slug) =>
      new Promise<string>((resolve) => {
        const ws = new WebSocket(`wss://${location.host}/u/0/w/${slug}/session`);
        ws.binaryType = 'arraybuffer';
        let text = '';
        ws.onopen = () => ws.send(new TextEncoder().encode('ping\n'));
        ws.onmessage = (event) => {
          text += new TextDecoder().decode(event.data as ArrayBuffer);
          if (text.endsWith('ping\n')) {
            ws.close();
            resolve(text);
          }
        };
        ws.onclose = (event) => resolve(`closed ${event.code}`);
        setTimeout(() => resolve(`timed out after ${JSON.stringify(text)}`), 20_000);
      }),
    slug,
  );
}

test("a signed-in page's session reaches its workspace's host, both ways", async ({ page }) => {
  await signIn(page);
  expect(await session(page, 'demo')).toBe('clide stub host for demo\nping\n');
});

test('a session for a workspace that is not there does not open', async ({ page }) => {
  await signIn(page);
  expect(await session(page, 'no-such-workspace')).toBe('closed 1006');
});

// The sign-in page's CSP allows it no connections, so the refusals below are
// checked as the handshakes a browser would send.
const handshake = {
  Connection: 'Upgrade',
  Upgrade: 'websocket',
  'Sec-WebSocket-Version': '13',
  'Sec-WebSocket-Key': 'AAECAwQFBgcICQoLDA0ODw==',
};

test('a handshake that is not signed in is refused', async ({ request }) => {
  const response = await request.get('/u/0/w/demo/session', { headers: { ...handshake, Origin: 'https://localhost:8443' } });
  expect(response.status()).toBe(401);
});

test('a signed-in handshake from another origin is refused', async ({ page }) => {
  await signIn(page);
  const response = await page.context().request.get('/u/0/w/demo/session', { headers: { ...handshake, Origin: 'https://elsewhere.example' } });
  expect(response.status()).toBe(403);
});
