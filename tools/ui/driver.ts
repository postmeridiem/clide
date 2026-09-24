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

  /** Uncaught page errors since this driver was created. */
  readonly pageErrors: string[] = [];

  /**
   * The page's console output, oldest first. An uncaught Dart exception
   * reaches [pageErrors] as a bare "Exception"; its message and stack are
   * printed here.
   */
  readonly consoleLines: string[] = [];

  constructor(page: Page) {
    this.page = page;
    // Attached before any navigation, so nothing thrown during boot is missed.
    page.on('pageerror', (e) => this.pageErrors.push(String(e)));
    page.on('console', (m) => this.consoleLines.push(`${m.type()}: ${m.text()}`));
  }

  /** The last [n] console lines, for a failure message. */
  consoleTail(n: number = 20): string {
    return this.consoleLines.slice(-n).join('\n');
  }

  /**
   * How many distinct colours a screenshot of the page holds, sampled. A page
   * Flutter never painted is one flat colour. The semantics tree comes from
   * the framework, not the renderer, so it can be complete on a blank screen
   * and can't stand in for this check (T-443). The browser's own image
   * decoder reads the PNG, so the harness needs no image library.
   */
  async paintedColors(): Promise<number> {
    const png = (await this.page.screenshot()).toString('base64');
    return this.page.evaluate(async (b64) => {
      const img = new Image();
      img.src = `data:image/png;base64,${b64}`;
      await img.decode();
      const canvas = document.createElement('canvas');
      canvas.width = img.width;
      canvas.height = img.height;
      const ctx = canvas.getContext('2d')!;
      ctx.drawImage(img, 0, 0);
      const px = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
      const seen = new Set<number>();
      // Every 97th pixel is plenty to tell a blank page from a painted one.
      for (let i = 0; i < px.length; i += 4 * 97) seen.add((px[i] << 16) | (px[i + 1] << 8) | px[i + 2]);
      return seen.size;
    }, png);
  }

  /** Navigate to the app root and wait until Flutter has finished first-frame. */
  async goto(path: string = '/'): Promise<void> {
    await this.page.goto(path);
    try {
      await this.waitUntilReady();
    } catch (e) {
      // A boot that throws never builds its semantics, so the wait times out.
      // Name what was thrown rather than only the timeout.
      if (this.pageErrors.length === 0 && this.consoleLines.length === 0) throw e;
      throw new Error(
        `${e}\nUncaught page errors: ${this.pageErrors.join(', ') || 'none'}\nConsole:\n${this.consoleTail()}`,
      );
    }
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
      // Flutter parks the placeholder just outside the viewport, and Playwright
      // refuses to click it there, even with `force`. A dispatched click
      // reaches the same listener without the viewport check.
      await placeholder.dispatchEvent('click');
    }
    await this.page.waitForSelector('flt-semantics[aria-label]', {
      timeout: 30_000,
      state: 'attached',
    });
  }

  /**
   * A button by its accessible name, which the browser computes. A button
   * built from plain text has no `aria-label`; its name is its text (Flutter
   * 3.44), so [byLabel] can't find it. The name matches as a substring.
   */
  button(name: string): Locator {
    return this.page.getByRole('button', { name });
  }

  /**
   * Returns a locator for a Semantics node whose `aria-label` contains
   * [label]. Only an explicit `Semantics(label:)` wrapper sets aria-label;
   * plain text surfaces as the element's text instead (see [button]).
   * Flutter web merges sibling labels into one aria-label
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
