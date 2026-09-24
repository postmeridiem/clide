import { defineConfig, devices } from '@playwright/test';

// A headless Chromium has no GPU. Flutter renders through WebGL when it gets
// it and drops to CPU-only rendering when it doesn't, so the page paints
// either way. These flags keep CI on the WebGL path users run: Chromium's own
// fallback to software WebGL is deprecated, and without it CI would be
// testing the CPU path (T-443).
const softwareWebGL = ['--enable-unsafe-swiftshader', '--use-angle=swiftshader', '--ignore-gpu-blocklist'];

export default defineConfig({
  testDir: './tests',
  // Single-worker: the web server is local and global; parallel tests
  // would race on the shared browser state.
  workers: 1,
  reporter: 'line',
  // A cold WASM boot takes tens of seconds under software rendering.
  timeout: 120_000,
  use: {
    baseURL: process.env.CLIDE_UI_URL ?? 'http://localhost:4280',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    {
      // The plain dev server: `make ui-dev`, and CI's `make test-e2e`.
      name: 'chromium',
      testIgnore: /container-.*\.spec\.ts/,
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1920, height: 1080 },
        launchOptions: { args: softwareWebGL },
      },
    },
    {
      // The edge container (`make ui-container`), whose TLS comes from
      // Caddy's internal CA.
      name: 'container',
      testMatch: /container-.*\.spec\.ts/,
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1920, height: 1080 },
        ignoreHTTPSErrors: true,
        launchOptions: { args: softwareWebGL },
      },
    },
  ],
  outputDir: 'out',
});
