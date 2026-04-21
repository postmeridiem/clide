import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  // Single-worker: the web server is local and global; parallel tests
  // would race on the shared browser state.
  workers: 1,
  reporter: 'line',
  use: {
    baseURL: process.env.CLIDE_UI_URL ?? 'http://localhost:4280',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        // WASM + CanvasKit + semantics tree runs headless fine; no extra
        // launch args needed for our driver surface.
      },
    },
  ],
  outputDir: 'out',
});
