import { expect } from '@playwright/test';
import type { Page, Locator } from '@playwright/test';

/**
 * Playwright helpers that drive the Flutter WASM build by querying
 * `flt-semantics` DOM elements instead of pixel coordinates.
 *
 * Requires the app to have `SemanticsBinding.ensureSemantics()` on
 * boot (main.dart already does this). Every interactive widget in
 * clide emits a `Semantics(label:, hint:, button:)` wrapper, which
 * surfaces as a `flt-semantics[aria-label="…"]` element.
 */
export class ClideDriver {
  readonly page: Page;

  constructor(page: Page) {
    this.page = page;
  }

  /** Navigate to the app root and wait until Flutter has finished first-frame. */
  async goto(path: string = '/'): Promise<void> {
    await this.page.goto(path);
    await this.waitUntilReady();
  }

  /**
   * Wait until the Flutter app is past first frame and click the
   * accessibility placeholder so the semantics tree is populated.
   * Flutter web ships semantics disabled by default; the placeholder
   * at the very top-left of the page is the official way to turn them
   * on from outside the app.
   */
  async waitUntilReady(): Promise<void> {
    await this.page.waitForSelector('flt-glass-pane', {
      timeout: 30_000,
      state: 'attached',
    });
    const placeholder = this.page.locator('flt-semantics-placeholder');
    if ((await placeholder.count()) > 0) {
      await placeholder.click({ force: true });
    }
    await this.page.waitForSelector('flt-semantics[aria-label]', {
      timeout: 30_000,
      state: 'attached',
    });
  }

  /**
   * Returns a locator for a Semantics node whose `aria-label` contains
   * [label]. Flutter web merges sibling labels into one aria-label
   * (newline-separated), so exact match wouldn't work. Substring match
   * is usually unique — narrow with `.filter()` if not.
   */
  byLabel(label: string): Locator {
    const safe = label.replace(/"/g, '\\"');
    return this.page.locator(`flt-semantics[aria-label*="${safe}"]`);
  }

  /** Click an element by its semantic label. Asserts it exists + is enabled. */
  async click(label: string): Promise<void> {
    const el = this.byLabel(label);
    await el.waitFor({ state: 'attached', timeout: 5_000 });
    await el.click();
  }

  /** Type into the element with the given label. */
  async type(label: string, text: string): Promise<void> {
    const el = this.byLabel(label);
    await el.waitFor({ state: 'attached', timeout: 5_000 });
    await el.fill(text);
  }

  /** Read the visible label of an element (useful for state transitions). */
  async readText(label: string): Promise<string> {
    const el = this.byLabel(label);
    await el.waitFor({ state: 'attached', timeout: 5_000 });
    return (await el.textContent()) ?? '';
  }

  /** Save a full-page PNG to `path`. */
  async screenshot(path: string): Promise<void> {
    await this.page.screenshot({ path, fullPage: true });
  }

  /**
   * Dump the entire Flutter semantic tree as structured JSON. Useful
   * for test-failure diagnosis ("why didn't my label match?") and for
   * Claude's own debugging flow.
   */
  async dumpSemanticsTree(): Promise<unknown> {
    return this.page.evaluate(() => {
      function walk(el: Element): unknown {
        const children = Array.from(el.children)
          .filter((c) => c.tagName.toLowerCase().startsWith('flt-semantics'))
          .map(walk);
        return {
          tag: el.tagName.toLowerCase(),
          label: el.getAttribute('aria-label'),
          role: el.getAttribute('role'),
          hint: el.getAttribute('aria-describedby'),
          selected: el.getAttribute('aria-selected'),
          children,
        };
      }
      const hosts = Array.from(document.querySelectorAll('flt-semantics-host'));
      return hosts.map(walk);
    });
  }
}
