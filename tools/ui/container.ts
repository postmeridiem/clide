import type { Page } from '@playwright/test';

/**
 * The sign-in link `make ui-container` prints (T-664). Whoever runs the
 * container specs passes it in as CLIDE_UI_SIGNIN, since the specs can't
 * reach into the container for one.
 */
export function signinLink(): string {
  const link = process.env.CLIDE_UI_SIGNIN;
  if (!link) throw new Error('CLIDE_UI_SIGNIN is not set: pass the sign-in link `make ui-container` printed.');
  return link;
}

/** Signs [page] in through the link, and waits until it has left /auth/. */
export async function signIn(page: Page): Promise<void> {
  await page.goto(signinLink());
  await page.waitForURL((url) => !url.pathname.startsWith('/auth/'));
}
